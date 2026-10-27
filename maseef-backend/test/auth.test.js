const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const test = require("node:test");
const express = require("express");
const { MemoryAuthStore } = require("../auth/memoryStore");
const { createAuthService } = require("../auth/service");
const { createPgAuthStore } = require("../auth/pgStore");
const { createPasswordHasher } = require("../auth/passwords");
const { hashSessionToken } = require("../auth/tokens");
const { requireAuth } = require("../auth/middleware");
const { MemoryBookingStore } = require("../booking/memoryStore");
const { createProtectedBookingRouter } = require("../booking/routes");
const { createApp } = require("../server");

const passwordsPromise = createPasswordHasher();
const password = "correct-horse";
const otherPassword = "another-secret";

function listen(app) {
  return new Promise((resolve) => {
    const server = app.listen(0, "127.0.0.1", () => resolve(server));
  });
}

function request(server, method, requestPath, { token, body, headers = {} } = {}) {
  const payload = body == null ? null : JSON.stringify(body);
  const { port } = server.address();
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port,
        path: requestPath,
        method,
        headers: {
          accept: "application/json",
          ...(payload ? { "content-type": "application/json" } : {}),
          ...(token ? { authorization: `Bearer ${token}` } : {}),
          ...(payload ? { "content-length": Buffer.byteLength(payload) } : {}),
          ...headers,
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const raw = Buffer.concat(chunks).toString("utf8");
          let parsed = null;
          if (raw) {
            try {
              parsed = JSON.parse(raw);
            } catch {
              parsed = raw;
            }
          }
          resolve({ status: res.statusCode, body: parsed, raw });
        });
      },
    );
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

function close(server) {
  return new Promise((resolve) => server.close(resolve));
}

function appFor(store, passwords) {
  return createApp({
    bookingStore: new MemoryBookingStore(),
    authStore: store,
    passwords,
  });
}

function watched(passwords, counts) {
  return {
    async hash(value) {
      counts.hash += 1;
      return passwords.hash(value);
    },
    async verify(passwordHash, value) {
      counts.verify += 1;
      return passwords.verify(passwordHash, value);
    },
    async verifyDummy(value) {
      counts.dummy += 1;
      return passwords.verifyDummy(value);
    },
  };
}

test("invalid credentials share one error and unknown emails still run a hash check", async () => {
  const passwords = await passwordsPromise;
  const counts = { hash: 0, verify: 0, dummy: 0 };
  const store = new MemoryAuthStore();
  const server = await listen(appFor(store, watched(passwords, counts)));
  try {
    const created = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Lina Guest",
        email: "Lina@Example.com",
        password,
        role: "customer",
      },
    });
    assert.equal(created.status, 201);
    assert.equal(created.body.data.user.email, "lina@example.com");
    assert.equal(created.raw.includes(password), false);
    assert.equal(created.raw.includes("passwordHash"), false);
    assert.match(store.users[0].passwordHash, /^\$argon2id\$/);
    assert.match(store.users[0].passwordHash, /m=19456,t=2,p=1/);
    assert.equal(store.sessions.has(created.body.data.token), false);
    assert.equal(
      store.sessions.has(hashSessionToken(created.body.data.token)),
      true,
    );

    const wrong = await request(server, "POST", "/api/auth/login", {
      body: { email: "lina@example.com", password: otherPassword, role: "admin" },
    });
    const unknown = await request(server, "POST", "/api/auth/login", {
      body: { email: "missing@example.com", password: otherPassword },
    });
    assert.equal(wrong.status, 401);
    assert.equal(unknown.status, 401);
    assert.equal(wrong.body.code, "invalid_credentials");
    assert.deepEqual(wrong.body, unknown.body);
    assert.equal(store.users[0].role, "customer");
    assert.equal(counts.hash, 1);
    assert.equal(counts.verify, 1);
    assert.equal(counts.dummy, 1);

    const signedIn = await request(server, "POST", "/api/auth/login", {
      body: { email: "lina@example.com", password },
    });
    assert.equal(signedIn.status, 200);
    assert.equal(signedIn.body.data.user.role, "customer");
    assert.notEqual(signedIn.body.data.token, created.body.data.token);
  } finally {
    await close(server);
  }
});

test("duplicate email is rejected and the first password stays stored", async () => {
  const passwords = await passwordsPromise;
  const store = new MemoryAuthStore();
  const server = await listen(appFor(store, passwords));
  try {
    const first = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Lina Guest",
        email: "lina@example.com",
        password,
      },
    });
    assert.equal(first.status, 201);
    assert.equal(first.body.data.user.role, "customer");
    const originalHash = store.users[0].passwordHash;

    const duplicate = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Someone Else",
        email: "LINA@example.com",
        password: otherPassword,
        role: "owner",
      },
    });
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.code, "email_taken");
    assert.equal(store.users.length, 1);
    assert.equal(store.users[0].passwordHash, originalHash);
    assert.equal(store.users[0].role, "customer");
    assert.equal(store.users[0].fullName, "Lina Guest");
  } finally {
    await close(server);
  }
});

test("public registration cannot create an admin or claim a chalet", async () => {
  const passwords = await passwordsPromise;
  const counts = { hash: 0, verify: 0, dummy: 0 };
  const store = new MemoryAuthStore();
  const bookings = new MemoryBookingStore();
  const server = await listen(createApp({
    bookingStore: bookings,
    authStore: store,
    passwords: watched(passwords, counts),
  }));
  try {
    const admin = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Not An Admin",
        email: "admin@example.com",
        password,
        role: "admin",
        listingKey: "hareem-sultan",
        ownerUserId: 1,
        chaletId: 1,
      },
    });
    assert.equal(admin.status, 400);
    assert.equal(admin.body.code, "invalid_role");
    assert.equal(store.users.length, 0);
    assert.equal(store.sessions.size, 0);
    assert.equal(bookings.profiles.size, 0);
    assert.equal(counts.hash, 0);

    const owner = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Host Person",
        email: "host@example.com",
        password,
        phone: "+970599000000",
        role: "owner",
        listingKey: "hareem-sultan",
        ownerUserId: 1,
        chaletId: 5,
      },
    });
    assert.equal(owner.status, 201);
    assert.equal(owner.body.data.user.role, "owner");
    assert.equal(owner.body.data.user.listingKey, undefined);
    assert.equal(owner.raw.includes("hareem-sultan"), false);
    assert.equal(owner.raw.includes(password), false);
    assert.equal(store.users.length, 1);
    assert.equal(store.users[0].role, "owner");
    assert.equal(Object.hasOwn(store.users[0], "listingKey"), false);
    assert.equal(Object.hasOwn(store.users[0], "ownerUserId"), false);
    assert.equal(bookings.profiles.size, 0);

    const me = await request(server, "GET", "/api/auth/me?role=admin&userId=1", {
      token: owner.body.data.token,
      headers: {
        "x-user-id": "1",
        "x-user-role": "admin",
      },
    });
    assert.equal(me.status, 200);
    assert.equal(me.body.data.user.id, owner.body.data.user.id);
    assert.equal(me.body.data.user.role, "owner");
    assert.equal(me.raw.includes("passwordHash"), false);
  } finally {
    await close(server);
  }
});

test("expired and revoked sessions are rejected", async () => {
  const passwords = await passwordsPromise;
  const store = new MemoryAuthStore();
  const server = await listen(appFor(store, passwords));
  try {
    const created = await request(server, "POST", "/api/auth/register", {
      body: {
        fullName: "Lina Guest",
        email: "lina@example.com",
        password,
        role: "customer",
      },
    });
    const token = created.body.data.token;
    const session = store.sessions.get(hashSessionToken(token));
    session.expiresAt = new Date(Date.now() - 1000);

    const expired = await request(server, "GET", "/api/auth/me", { token });
    assert.equal(expired.status, 401);
    assert.equal(expired.body.code, "unauthenticated");
    assert.equal(session.revokedAt, null);

    session.expiresAt = new Date(Date.now() + 60 * 60 * 1000);
    const current = await request(server, "GET", "/api/auth/me", { token });
    assert.equal(current.status, 200);
    assert.equal(current.body.data.user.email, "lina@example.com");

    const loggedOut = await request(server, "POST", "/api/auth/logout", { token });
    assert.equal(loggedOut.status, 200);
    assert.ok(session.revokedAt instanceof Date);

    const revoked = await request(server, "GET", "/api/auth/me", { token });
    assert.equal(revoked.status, 401);
    assert.equal(revoked.body.code, "unauthenticated");

    const again = await request(server, "POST", "/api/auth/logout", { token });
    assert.equal(again.status, 401);
  } finally {
    await close(server);
  }
});

test("role checks use the database user and protected booking routes stay unmounted", async () => {
  const passwords = await passwordsPromise;
  const store = new MemoryAuthStore();
  const bookings = new MemoryBookingStore();
  await bookings.putProfile({
    listingKey: "hareem-sultan",
    ownerUserId: null,
    chaletId: null,
    offersFullDay: true,
    offersSessions: false,
    fullDay: { start: "08:00", end: "22:00" },
    morning: null,
    evening: null,
    prices: { fullDay: null, morning: null, evening: null },
  });

  const publicApp = createApp({
    bookingStore: bookings,
    authStore: store,
    passwords,
  });
  const publicServer = await listen(publicApp);
  let customerToken;
  let ownerToken;
  try {
    const customer = await request(publicServer, "POST", "/api/auth/register", {
      body: {
        fullName: "Lina Guest",
        email: "guest@example.com",
        password,
        role: "customer",
        userId: 5,
      },
    });
    const owner = await request(publicServer, "POST", "/api/auth/register", {
      body: {
        fullName: "Host Person",
        email: "host@example.com",
        password,
        role: "owner",
      },
    });
    assert.equal(customer.body.data.user.id, "1");
    assert.notEqual(customer.body.data.user.id, "5");
    customerToken = customer.body.data.token;
    ownerToken = owner.body.data.token;

    const hiddenOwnerRoute = await request(
      publicServer,
      "GET",
      "/api/owner/listings/hareem-sultan/booking-requests",
      { token: ownerToken },
    );
    const hiddenCustomerRoute = await request(
      publicServer,
      "POST",
      "/api/listings/hareem-sultan/booking-requests",
      { token: customerToken, body: { stayDate: "2026-11-02", mode: "morning" } },
    );
    assert.equal(hiddenOwnerRoute.status, 404);
    assert.equal(hiddenCustomerRoute.status, 404);
    assert.equal(bookings.requests.size, 0);
  } finally {
    await close(publicServer);
  }

  const guarded = express();
  guarded.use(express.json());
  guarded.use(createProtectedBookingRouter({
    store: bookings,
    authenticate: requireAuth(store),
  }));
  const guardedServer = await listen(guarded);
  try {
    const customerOnOwnerRoute = await request(
      guardedServer,
      "GET",
      "/api/owner/listings/hareem-sultan/booking-requests",
      {
        token: customerToken,
        headers: {
          "x-user-id": "2",
          "x-user-role": "owner",
          "x-test-user": JSON.stringify({ id: 2, role: "owner" }),
        },
      },
    );
    assert.equal(customerOnOwnerRoute.status, 403);
    assert.equal(customerOnOwnerRoute.body.code, "forbidden");

    const ownerOnCustomerRoute = await request(
      guardedServer,
      "GET",
      "/api/me/booking-requests",
      { token: ownerToken },
    );
    assert.equal(ownerOnCustomerRoute.status, 403);
    assert.equal(ownerOnCustomerRoute.body.code, "forbidden");

    const unlinked = await request(
      guardedServer,
      "GET",
      "/api/owner/listings/hareem-sultan/booking-requests",
      { token: ownerToken },
    );
    assert.equal(unlinked.status, 403);
    assert.equal(unlinked.body.code, "owner_not_linked");

    bookings.profiles.get("hareem-sultan").ownerUserId = 999;
    const stranger = await request(
      guardedServer,
      "GET",
      "/api/owner/listings/hareem-sultan/booking-requests",
      { token: ownerToken },
    );
    assert.equal(stranger.status, 403);
    assert.equal(stranger.body.code, "forbidden");
    assert.equal(bookings.requests.size, 0);
  } finally {
    await close(guardedServer);
  }
});

test("auth migration is only a proposal and the postgres store is not queried for real", async () => {
  const sql = fs.readFileSync(
    path.join(__dirname, "..", "migrations", "002_auth_sessions.sql"),
    "utf8",
  );
  const executable = sql
    .split(/\r?\n/)
    .filter((line) => !line.trim().startsWith("--"))
    .join("\n");
  assert.match(sql, /DO NOT RUN/);
  assert.match(executable, /CREATE TABLE IF NOT EXISTS auth_sessions/);
  assert.doesNotMatch(executable, /\bINSERT\b/i);
  assert.doesNotMatch(executable, /\bDROP\b/i);
  assert.doesNotMatch(executable, /\bTRUNCATE\b/i);
  assert.doesNotMatch(executable, /\bALTER\b/i);

  const queries = [];
  const pool = {
    async query(text, values) {
      queries.push({ text, values });
      if (text.includes("INSERT INTO users")) {
        return {
          rowCount: 1,
          rows: [{
            id: "8",
            full_name: values[0],
            email: values[1],
            phone: values[3],
            role: values[4],
          }],
        };
      }
      throw new Error(`unexpected query in mock pool: ${text}`);
    },
  };
  const store = createPgAuthStore(pool);
  await assert.rejects(
    store.insertUser({
      fullName: "Not An Admin",
      email: "admin@example.com",
      passwordHash: "hash",
      phone: null,
      role: "admin",
    }),
    (error) => error.code === "invalid_role",
  );
  assert.equal(queries.length, 0);

  const user = await store.insertUser({
    fullName: "Guest",
    email: "guest@example.com",
    passwordHash: "stored-hash",
    phone: null,
    role: "customer",
  });
  assert.equal(user.role, "customer");
  assert.equal(user.passwordHash, undefined);
  assert.equal(queries[0].values[2], "stored-hash");
  assert.equal(queries[0].values[4], "customer");
  assert.equal(queries[0].text.includes("guest@example.com"), false);
  assert.equal(queries[0].text.includes("stored-hash"), false);
  assert.match(queries[0].text, /\$1/);
});

test("a failed session insert does not keep the new account", async () => {
  const passwords = await passwordsPromise;
  const store = new MemoryAuthStore();
  store.insertSession = async () => {
    throw new Error("auth_sessions is not available");
  };
  const auth = createAuthService({ store, passwords });
  await assert.rejects(
    auth.register({
      fullName: "Lina Guest",
      email: "lina@example.com",
      password,
      role: "customer",
    }),
    /not available/,
  );
  assert.equal(store.users.length, 0);
  assert.equal(store.sessions.size, 0);
});
