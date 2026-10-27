const assert = require("node:assert/strict");
const net = require("node:net");
const test = require("node:test");
const { MemoryAuthStore } = require("../auth/memoryStore");
const { createPasswordHasher } = require("../auth/passwords");
const { createPgAuthStore } = require("../auth/pgStore");
const { createMailer, createSmtpMailerFromEnv } = require("../auth/mailer");
const { parseBaseUrl, passwordResetFromEnv } = require("../auth/resetConfig");
const { createResetTokens } = require("../auth/resetTokens");
const { MemoryBookingStore } = require("../booking/memoryStore");
const { createApp } = require("../server");

const SECRET = "test-secret-test-secret-test-secret-0123";
const BASE = "https://maseef.example.com";
const oldPassword = "correct-horse";
const newPassword = "brand-new-secret";
const passwordsPromise = createPasswordHasher();

async function setup({ configured = true, mailFails = false, now } = {}) {
  const passwords = await passwordsPromise;
  const store = new MemoryAuthStore();
  const sent = [];
  const logs = [];
  const mailer = {
    async send(message) {
      if (mailFails) {
        const error = new Error(`boom for ${message.to}`);
        error.code = "ECONNECTION";
        throw error;
      }
      sent.push(message);
    },
  };
  const passwordReset = configured
    ? {
        tokens: createResetTokens({ secret: SECRET }),
        mailer,
        appBaseUrl: BASE,
        log: (line) => logs.push(line),
      }
    : { tokens: null, mailer: null, appBaseUrl: null, missing: ["x"] };
  const app = createApp({
    bookingStore: new MemoryBookingStore(),
    authStore: store,
    passwords,
    passwordReset,
    now,
  });
  const server = await new Promise((resolve) => {
    const s = app.listen(0, "127.0.0.1", () => resolve(s));
  });
  const base = `http://127.0.0.1:${server.address().port}`;

  async function call(method, path, { body, token } = {}) {
    const response = await fetch(base + path, {
      method,
      headers: {
        "content-type": "application/json",
        ...(token ? { authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const raw = await response.text();
    return {
      status: response.status,
      raw,
      body: raw ? JSON.parse(raw) : null,
      headers: response.headers,
    };
  }

  async function register(email = "lina@example.com") {
    const response = await call("POST", "/api/auth/register", {
      body: { fullName: "Lina Guest", email, password: oldPassword, role: "customer" },
    });
    assert.equal(response.status, 201);
    return response.body.data;
  }

  async function waitForMail(count = 1) {
    for (let i = 0; i < 100 && sent.length < count; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
  }

  function tokenFrom(message) {
    const match = /\/#\/reset-password\?token=([A-Za-z0-9._-]+)/.exec(message.text);
    assert.ok(match, "the email text carries the reset link");
    return match[1];
  }

  return {
    call,
    register,
    sent,
    logs,
    store,
    waitForMail,
    tokenFrom,
    close: () => new Promise((resolve) => server.close(resolve)),
  };
}

test("a reset link works once: new password signs in, old one and old sessions do not", async () => {
  const t = await setup();
  try {
    const session = await t.register();
    const forgot = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "Lina@Example.com" },
    });
    assert.equal(forgot.status, 200);
    assert.deepEqual(forgot.body, { status: "success" });

    await t.waitForMail();
    assert.equal(t.sent.length, 1);
    const message = t.sent[0];
    assert.equal(message.to, "lina@example.com");
    assert.match(message.text, new RegExp(`^${BASE}/#/reset-password\\?token=`, "m"));
    assert.ok(message.html.includes(`${BASE}/#/reset-password?token=`));
    const token = t.tokenFrom(message);

    const reset = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: newPassword },
    });
    assert.equal(reset.status, 200);
    assert.deepEqual(reset.body, { status: "success" });
    assert.equal(reset.raw.includes(newPassword), false);

    // The new password works; the old one does not.
    const bad = await t.call("POST", "/api/auth/login", {
      body: { email: "lina@example.com", password: oldPassword },
    });
    assert.equal(bad.status, 401);
    const good = await t.call("POST", "/api/auth/login", {
      body: { email: "lina@example.com", password: newPassword },
    });
    assert.equal(good.status, 200);

    // Sign-ins from before the reset were ended.
    const me = await t.call("GET", "/api/auth/me", { token: session.token });
    assert.equal(me.status, 401);

    // The same link cannot be used a second time.
    const again = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: "yet-another-secret" },
    });
    assert.equal(again.status, 400);
    assert.equal(again.body.code, "invalid_token");
    const stillNew = await t.call("POST", "/api/auth/login", {
      body: { email: "lina@example.com", password: newPassword },
    });
    assert.equal(stillNew.status, 200);
  } finally {
    await t.close();
  }
});

test("an unknown address gets the identical response and no email", async () => {
  const t = await setup();
  try {
    await t.register();
    const known = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    const unknown = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "nobody@example.com" },
    });
    assert.equal(unknown.status, known.status);
    assert.equal(unknown.raw, known.raw);
    await t.waitForMail();
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.equal(t.sent.length, 1);
    assert.equal(t.sent[0].to, "lina@example.com");
  } finally {
    await t.close();
  }
});

test("a failing mail server is logged without the address or link and the reply stays the same", async () => {
  const t = await setup({ mailFails: true });
  try {
    await t.register();
    const response = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    assert.equal(response.status, 200);
    for (let i = 0; i < 100 && !t.logs.length; i += 1) {
      await new Promise((resolve) => setTimeout(resolve, 5));
    }
    assert.equal(t.logs.length, 1);
    assert.match(t.logs[0], /ECONNECTION/);
    assert.equal(t.logs[0].includes("lina@example.com"), false);
    assert.equal(t.logs[0].includes("reset-password"), false);
  } finally {
    await t.close();
  }
});

test("without secret or email settings the API says unavailable instead of pretending", async () => {
  const t = await setup({ configured: false });
  try {
    await t.register();
    const forgot = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    assert.equal(forgot.status, 503);
    assert.equal(forgot.body.code, "unavailable");
    const forgotUnknown = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "nobody@example.com" },
    });
    assert.equal(forgotUnknown.raw, forgot.raw);
    const reset = await t.call("POST", "/api/auth/reset-password", {
      body: { token: "1.2.3", password: newPassword },
    });
    assert.equal(reset.status, 503);
    assert.equal(t.sent.length, 0);
  } finally {
    await t.close();
  }
});

test("an expired link is rejected", async () => {
  let clock = new Date("2026-10-27T10:00:00Z");
  const t = await setup({ now: () => clock });
  try {
    await t.register();
    await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    await t.waitForMail();
    const token = t.tokenFrom(t.sent[0]);

    clock = new Date(clock.getTime() + 61 * 60 * 1000);
    const late = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: newPassword },
    });
    assert.equal(late.status, 400);
    assert.equal(late.body.code, "invalid_token");

    // Just inside the hour it still worked.
    clock = new Date("2026-10-27T10:59:00Z");
    const ok = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: newPassword },
    });
    assert.equal(ok.status, 200);
  } finally {
    await t.close();
  }
});

test("forged, altered and malformed tokens are rejected", async () => {
  const t = await setup();
  try {
    await t.register();
    await t.register("other@example.com");
    await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    await t.waitForMail();
    const token = t.tokenFrom(t.sent[0]);
    const [id, exp, signature] = token.split(".");

    const forged = createResetTokens({ secret: "x".repeat(40) }).create({
      userId: id,
      passwordHash: "whatever",
      now: new Date(),
    });
    const flipped = `${signature.slice(0, -1)}${signature.endsWith("A") ? "B" : "A"}`;
    const candidates = [
      forged,
      `${id}.${exp}.${flipped}`,
      `2.${exp}.${signature}`, // someone else's id with this signature
      `${id}.${Number(exp) + 3600}.${signature}`, // extended expiry
      "garbage",
      "",
      `${id}.${exp}`,
      "1.1.1",
    ];
    for (const candidate of candidates) {
      const response = await t.call("POST", "/api/auth/reset-password", {
        body: { token: candidate, password: newPassword },
      });
      assert.equal(response.status, 400, candidate);
      assert.equal(response.body.code, "invalid_token", candidate);
    }
    const missing = await t.call("POST", "/api/auth/reset-password", {
      body: { password: newPassword },
    });
    assert.equal(missing.body.code, "invalid_token");

    // None of that changed the password.
    const login = await t.call("POST", "/api/auth/login", {
      body: { email: "lina@example.com", password: oldPassword },
    });
    assert.equal(login.status, 200);
  } finally {
    await t.close();
  }
});

test("a weak new password is refused and the link stays usable", async () => {
  const t = await setup();
  try {
    await t.register();
    await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com" },
    });
    await t.waitForMail();
    const token = t.tokenFrom(t.sent[0]);
    const weak = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: "short" },
    });
    assert.equal(weak.status, 400);
    assert.equal(weak.body.code, "invalid_password");
    const ok = await t.call("POST", "/api/auth/reset-password", {
      body: { token, password: newPassword },
    });
    assert.equal(ok.status, 200);
  } finally {
    await t.close();
  }
});

test("requesting twice is fine, and the other link dies once one of them is used", async () => {
  const t = await setup();
  try {
    await t.register();
    for (let i = 0; i < 2; i += 1) {
      await t.call("POST", "/api/auth/forgot-password", {
        body: { email: "lina@example.com" },
      });
    }
    await t.waitForMail(2);
    const [first, second] = t.sent.map((m) => t.tokenFrom(m));
    const ok = await t.call("POST", "/api/auth/reset-password", {
      body: { token: second, password: newPassword },
    });
    assert.equal(ok.status, 200);
    const stale = await t.call("POST", "/api/auth/reset-password", {
      body: { token: first, password: "yet-another-secret" },
    });
    assert.equal(stale.body.code, "invalid_token");
  } finally {
    await t.close();
  }
});

test("Arabic requests get an Arabic right-to-left email", async () => {
  const t = await setup();
  try {
    await t.register();
    await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "lina@example.com", locale: "ar" },
    });
    await t.waitForMail();
    assert.match(t.sent[0].subject, /MASEEF/);
    assert.ok(/[\u0600-\u06FF]/.test(t.sent[0].subject));
    assert.ok(t.sent[0].html.includes('dir="rtl"'));
    assert.ok(t.sent[0].html.includes('lang="ar"'));
  } finally {
    await t.close();
  }
});

test("repeated requests are limited per address and per client", async () => {
  const t = await setup();
  try {
    await t.register();
    const statuses = [];
    for (let i = 0; i < 7; i += 1) {
      const response = await t.call("POST", "/api/auth/forgot-password", {
        body: { email: "lina@example.com" },
      });
      statuses.push(response.status);
      if (response.status === 429) {
        assert.equal(response.body.code, "rate_limited");
        assert.ok(Number(response.headers.get("retry-after")) >= 1);
      }
    }
    assert.deepEqual(statuses, [200, 200, 200, 200, 200, 429, 429]);
    await new Promise((resolve) => setTimeout(resolve, 30));
    assert.equal(t.sent.length, 5);
  } finally {
    await t.close();
  }
});

test("a malformed email is refused with the usual validation error", async () => {
  const t = await setup();
  try {
    const response = await t.call("POST", "/api/auth/forgot-password", {
      body: { email: "not-an-email" },
    });
    assert.equal(response.status, 400);
    assert.equal(response.body.code, "invalid_email");
    assert.equal(t.sent.length, 0);
  } finally {
    await t.close();
  }
});

test("reset tokens bind to the password hash, expire, and need a long secret", () => {
  assert.throws(() => createResetTokens({ secret: "short" }), /at least 32/);
  const tokens = createResetTokens({ secret: SECRET, ttlMs: 60_000 });
  const now = new Date("2026-10-27T10:00:00Z");
  const token = tokens.create({ userId: 7, passwordHash: "hash-a", now });
  const parsed = tokens.parse(token);
  assert.equal(parsed.userId, "7");
  assert.equal(tokens.verify(parsed, { userId: 7, passwordHash: "hash-a", now }), true);
  assert.equal(tokens.verify(parsed, { userId: 7, passwordHash: "hash-b", now }), false);
  assert.equal(tokens.verify(parsed, { userId: 8, passwordHash: "hash-a", now }), false);
  const later = new Date(now.getTime() + 61_000);
  assert.equal(tokens.verify(parsed, { userId: 7, passwordHash: "hash-a", now: later }), false);
  assert.equal(tokens.parse("a.b.c"), null);
  assert.equal(tokens.parse(null), null);
  assert.equal(token.includes("hash-a"), false);
});

test("configuration reports what is missing by name and never echoes values", () => {
  const empty = passwordResetFromEnv({});
  assert.equal(empty.tokens, null);
  assert.equal(empty.mailer, null);
  assert.deepEqual(empty.missing, [
    "PASSWORD_RESET_SECRET",
    "APP_BASE_URL",
    "SMTP_HOST",
    "MAIL_FROM",
  ]);

  const partial = passwordResetFromEnv({
    PASSWORD_RESET_SECRET: "too-short-secret-value",
    APP_BASE_URL: BASE,
    SMTP_HOST: "smtp.example.com",
    MAIL_FROM: "MASEEF <no-reply@example.com>",
    SMTP_USER: "me",
  });
  assert.ok(partial.missing.some((m) => m.startsWith("PASSWORD_RESET_SECRET")));
  assert.ok(partial.missing.includes("SMTP_PASSWORD"));
  assert.equal(partial.missing.join(" ").includes("too-short-secret-value"), false);

  const full = passwordResetFromEnv({
    PASSWORD_RESET_SECRET: SECRET,
    APP_BASE_URL: `${BASE}/`,
    SMTP_HOST: "smtp.example.com",
    MAIL_FROM: "MASEEF <no-reply@example.com>",
  });
  assert.deepEqual(full.missing, []);
  assert.ok(full.tokens && full.mailer);
  assert.equal(full.appBaseUrl, BASE);

  assert.equal(parseBaseUrl("ftp://x.com"), null);
  assert.equal(parseBaseUrl("https://user:pw@x.com"), null);
  assert.equal(parseBaseUrl("not a url"), null);
  assert.equal(parseBaseUrl("http://localhost:5000/app/"), "http://localhost:5000/app");
});

test("the SMTP mailer delivers the reset email to a real (local) SMTP server", async () => {
  const received = { rcpt: [], data: "" };
  const sink = net.createServer((socket) => {
    let buffer = "";
    let inData = false;
    socket.write("220 sink ESMTP\r\n");
    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      for (;;) {
        if (inData) {
          const end = buffer.indexOf("\r\n.\r\n");
          if (end === -1) return;
          received.data = buffer.slice(0, end);
          buffer = buffer.slice(end + 5);
          inData = false;
          socket.write("250 queued\r\n");
          continue;
        }
        const eol = buffer.indexOf("\r\n");
        if (eol === -1) return;
        const line = buffer.slice(0, eol);
        buffer = buffer.slice(eol + 2);
        const command = line.slice(0, 4).toUpperCase();
        if (command === "EHLO" || command === "HELO") socket.write("250 sink\r\n");
        else if (command === "MAIL") socket.write("250 ok\r\n");
        else if (command === "RCPT") {
          received.rcpt.push(line);
          socket.write("250 ok\r\n");
        } else if (command === "DATA") {
          inData = true;
          socket.write("354 go\r\n");
        } else if (command === "QUIT") {
          socket.write("221 bye\r\n");
          socket.end();
        } else socket.write("250 ok\r\n");
      }
    });
  });
  await new Promise((resolve) => sink.listen(0, "127.0.0.1", resolve));
  try {
    const mailer = createSmtpMailerFromEnv({
      SMTP_HOST: "127.0.0.1",
      SMTP_PORT: String(sink.address().port),
      SMTP_REQUIRE_TLS: "false",
      MAIL_FROM: "MASEEF <no-reply@maseef.example.com>",
    });
    assert.ok(mailer);

    const t = await setup();
    try {
      await t.register();
      // Reuse the real service wiring with the SMTP mailer instead of the capture one.
      const { createAuthService } = require("../auth/service");
      const store = t.store;
      const service = createAuthService({
        store,
        passwords: await passwordsPromise,
        passwordReset: {
          tokens: createResetTokens({ secret: SECRET }),
          mailer,
          appBaseUrl: BASE,
        },
      });
      const { delivery } = await service.requestPasswordReset({
        email: "lina@example.com",
      });
      await delivery;
    } finally {
      await t.close();
    }

    assert.equal(received.rcpt.length, 1);
    assert.match(received.rcpt[0], /<lina@example\.com>/i);
    const decoded = received.data
      .replace(/=\r\n/g, "")
      .replace(/=([0-9A-F]{2})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
    assert.match(decoded, /Subject: Reset your MASEEF password/);
    assert.match(decoded, /From: MASEEF <no-reply@maseef\.example\.com>/);
    assert.match(decoded, /https:\/\/maseef\.example\.com\/#\/reset-password\?token=[A-Za-z0-9._-]+/);
  } finally {
    await new Promise((resolve) => sink.close(resolve));
  }
});

test("the Postgres store only swaps the hash it was issued for and ends sessions", async () => {
  const queries = [];
  const pool = {
    async query(sql, params) {
      queries.push({ sql: sql.replace(/\s+/g, " ").trim(), params });
      if (/UPDATE users/.test(sql)) return { rowCount: params[1] === "old" ? 1 : 0 };
      if (/FROM users/.test(sql)) {
        return {
          rowCount: 1,
          rows: [
            { id: "7", full_name: "L", email: "l@x.com", password_hash: "old", phone: null, role: "customer" },
          ],
        };
      }
      return { rowCount: 2, rows: [] };
    },
  };
  const store = createPgAuthStore(pool);
  assert.equal(await store.findUserWithHashById("1; DROP TABLE users"), null);
  assert.equal(queries.length, 0, "a non-numeric id never reaches SQL");
  assert.equal((await store.findUserWithHashById("7")).passwordHash, "old");
  assert.equal(await store.replacePasswordHash("7", "old", "new"), true);
  assert.equal(await store.replacePasswordHash("7", "stale", "new"), false);
  await store.revokeUserSessions("7", new Date());
  const update = queries.find((q) => /UPDATE users/.test(q.sql));
  assert.match(update.sql, /WHERE id = \$1 AND password_hash = \$2/);
  assert.match(queries.at(-1).sql, /UPDATE auth_sessions SET revoked_at = \$2 WHERE user_id = \$1 AND revoked_at IS NULL/);
});

test("createMailer passes the configured sender through", async () => {
  const calls = [];
  const mailer = createMailer({
    from: "MASEEF <a@b.c>",
    transport: { sendMail: async (m) => calls.push(m) },
  });
  await mailer.send({ to: "x@y.z", subject: "s", text: "t", html: "<p>t</p>" });
  assert.deepEqual(calls[0], {
    from: "MASEEF <a@b.c>",
    to: "x@y.z",
    subject: "s",
    text: "t",
    html: "<p>t</p>",
  });
});
