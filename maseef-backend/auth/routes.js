const { createPasswordHasher } = require("./passwords");
const { AuthError, sendAuthError } = require("./errors");
const { requireAuth } = require("./middleware");
const { createAuthService } = require("./service");
const { createRateLimiter } = require("./rateLimit");
const { readBearer } = require("./tokens");

function mountAuthRoutes(app, { store, passwords, now, passwordReset } = {}) {
  let pendingHasher;
  async function passwordHasher() {
    if (passwords) return passwords;
    pendingHasher ??= createPasswordHasher();
    return pendingHasher;
  }

  function service() {
    return passwordHasher().then((hasher) => createAuthService({
      store,
      passwords: hasher,
      now,
      passwordReset,
    }));
  }

  const authenticate = requireAuth(store, now);

  // Per-address and per-client limits. The counters run before any account
  // lookup, so they behave the same for registered and unknown addresses.
  const resetWindowMs = 15 * 60 * 1000;
  const forgotByEmail = createRateLimiter({ windowMs: resetWindowMs, max: 5, now });
  const forgotByIp = createRateLimiter({ windowMs: resetWindowMs, max: 20, now });
  const resetByIp = createRateLimiter({ windowMs: resetWindowMs, max: 20, now });

  function limited(res, results) {
    const blocked = results.find((result) => !result.allowed);
    if (!blocked) return false;
    res.set("Retry-After", String(blocked.retryAfterSeconds));
    sendAuthError(
      res,
      new AuthError("rate_limited", "Too many attempts. Try again later.", 429),
    );
    return true;
  }

  app.post("/api/auth/forgot-password", async (req, res) => {
    try {
      const rawEmail =
        typeof req.body?.email === "string"
          ? req.body.email.trim().toLowerCase().slice(0, 255)
          : "";
      if (
        limited(res, [
          forgotByIp.take(`ip:${req.ip}`),
          forgotByEmail.take(`email:${rawEmail}`),
        ])
      ) {
        return;
      }
      const auth = await service();
      await auth.requestPasswordReset(req.body ?? {});
      // Identical for every valid address, registered or not.
      res.status(200).json({ status: "success" });
    } catch (error) {
      sendAuthError(res, error);
    }
  });

  app.post("/api/auth/reset-password", async (req, res) => {
    try {
      if (limited(res, [resetByIp.take(`ip:${req.ip}`)])) return;
      const auth = await service();
      await auth.resetPassword(req.body ?? {});
      res.status(200).json({ status: "success" });
    } catch (error) {
      sendAuthError(res, error);
    }
  });

  app.post("/api/auth/register", async (req, res) => {
    try {
      const auth = await service();
      const data = await auth.register(req.body ?? {});
      res.status(201).json({ status: "success", data });
    } catch (error) {
      sendAuthError(res, error);
    }
  });

  app.post("/api/auth/login", async (req, res) => {
    try {
      const auth = await service();
      const data = await auth.login(req.body ?? {});
      res.status(200).json({ status: "success", data });
    } catch (error) {
      sendAuthError(res, error);
    }
  });

  app.post("/api/auth/logout", authenticate, async (req, res) => {
    try {
      const token = readBearer(req.get("authorization"));
      const auth = await service();
      await auth.logout(token);
      res.json({ status: "success" });
    } catch (error) {
      sendAuthError(res, error);
    }
  });

  app.get("/api/auth/me", authenticate, async (req, res) => {
    try {
      const auth = await service();
      const user = await auth.currentUser(req.user.id);
      res.json({ status: "success", data: { user } });
    } catch (error) {
      sendAuthError(res, error);
    }
  });
}

module.exports = { mountAuthRoutes };
