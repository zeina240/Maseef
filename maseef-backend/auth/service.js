const { AuthError } = require("./errors");
const { buildResetEmail } = require("./resetEmail");
const { hashSessionToken, newSessionToken } = require("./tokens");

const SESSION_LIFETIME_MS = 30 * 24 * 60 * 60 * 1000;
const PUBLIC_ROLES = new Set(["customer", "owner"]);

function createAuthService({
  store,
  passwords,
  now = () => new Date(),
  lifetimeMs = SESSION_LIFETIME_MS,
  // { tokens, mailer, appBaseUrl, ttlMs, log } from resetConfig.js, or omitted.
  passwordReset = null,
}) {
  const logError = passwordReset?.log ?? ((message) => console.error(message));

  return {
    /**
     * Emails a reset link to the address if (and only if) it has an account.
     * The caller gets the same result either way. Mail is sent in the
     * background so a registered address does not respond more slowly than an
     * unknown one. Throws "unavailable" when reset or email is not set up, which
     * says nothing about any particular address.
     */
    async requestPasswordReset(input) {
      if (!passwordReset?.tokens || !passwordReset?.mailer || !passwordReset?.appBaseUrl) {
        throw new AuthError(
          "unavailable",
          "Password reset is not available right now.",
          503,
        );
      }
      const email = assertEmail(input?.email);
      const locale = input?.locale === "ar" ? "ar" : "en";

      const user = await store.findUserByEmail(email);
      if (!user) return { delivery: Promise.resolve() };

      const token = passwordReset.tokens.create({
        userId: user.id,
        passwordHash: user.passwordHash,
        now: now(),
      });
      const link = `${passwordReset.appBaseUrl}/#/reset-password?token=${token}`;
      const message = buildResetEmail({
        link,
        locale,
        ttlMs: passwordReset.tokens.ttlMs,
      });
      const delivery = passwordReset.mailer
        .send({ to: user.email, ...message })
        .catch((error) => {
          // Never log the address or the link; the error code is enough.
          logError(
            `Password reset email failed: ${error?.code ?? error?.responseCode ?? "unknown error"}`,
          );
        });
      return { delivery };
    },

    /**
     * Sets a new password from a reset link. The token is valid only while it is
     * unexpired and the password has not changed since it was issued, so a used
     * link cannot be used again. All existing sign-ins are ended.
     */
    async resetPassword(input) {
      if (!passwordReset?.tokens) {
        throw new AuthError(
          "unavailable",
          "Password reset is not available right now.",
          503,
        );
      }
      const invalid = () =>
        new AuthError(
          "invalid_token",
          "This reset link is invalid or has expired.",
          400,
        );
      const password = assertPassword(input?.password);
      const parsed = passwordReset.tokens.parse(input?.token);
      if (!parsed) throw invalid();

      const user = await store.findUserWithHashById(parsed.userId);
      const stamp = now();
      if (
        !user ||
        !passwordReset.tokens.verify(parsed, {
          userId: user.id,
          passwordHash: user.passwordHash,
          now: stamp,
        })
      ) {
        throw invalid();
      }

      const newHash = await passwords.hash(password);
      await store.transaction(async (tx) => {
        // Compare-and-swap on the old hash: two requests racing with the same
        // link cannot both succeed.
        const changed = await tx.replacePasswordHash(
          user.id,
          user.passwordHash,
          newHash,
        );
        if (!changed) throw invalid();
        await tx.revokeUserSessions(user.id, stamp);
      });
    },

    async register(input) {
      const fullName = assertName(input?.fullName);
      const email = assertEmail(input?.email);
      const password = assertPassword(input?.password);
      const phone = assertPhone(input?.phone);
      const role = assertPublicRole(input?.role);
      const existing = await store.findUserByEmail(email);
      if (existing) {
        throw new AuthError(
          "email_taken",
          "An account with this email already exists.",
          409,
        );
      }
      const passwordHash = await passwords.hash(password);

      return store.transaction(async (tx) => {
        let user;
        try {
          user = await tx.insertUser({
            fullName,
            email,
            passwordHash,
            phone,
            role,
          });
        } catch (error) {
          if (error && (error.code === "23505" || error.code === "email_taken")) {
            throw new AuthError(
              "email_taken",
              "An account with this email already exists.",
              409,
            );
          }
          throw error;
        }

        const session = await issueSession(tx, user.id, now(), lifetimeMs);
        return {
          token: session.token,
          expiresAt: session.expiresAt,
          user: publicUser(user),
        };
      });
    },

    async login(input) {
      const email = assertEmail(input?.email);
      const password = assertPassword(input?.password);
      const user = await store.findUserByEmail(email);
      const passwordOk = user
        ? await passwords.verify(user.passwordHash, password)
        : await passwords.verifyDummy(password);

      if (!user || !passwordOk) {
        throw new AuthError(
          "invalid_credentials",
          "Invalid email or password.",
          401,
        );
      }

      const session = await issueSession(store, user.id, now(), lifetimeMs);
      return {
        token: session.token,
        expiresAt: session.expiresAt,
        user: publicUser(user),
      };
    },

    async currentUser(userId) {
      const user = await store.findUserById(userId);
      if (!user) {
        throw new AuthError("unauthenticated", "Sign in required.", 401);
      }
      return publicUser(user);
    },

    async logout(token) {
      const revoked = await store.revokeSession(hashSessionToken(token), now());
      if (!revoked) {
        throw new AuthError("unauthenticated", "Sign in required.", 401);
      }
    },
  };
}

async function issueSession(store, userId, now, lifetimeMs) {
  const token = newSessionToken();
  const expiresAt = new Date(now.getTime() + lifetimeMs);
  await store.insertSession({
    userId,
    tokenHash: hashSessionToken(token),
    expiresAt,
  });
  return { token, expiresAt: expiresAt.toISOString() };
}

function publicUser(user) {
  return {
    id: String(user.id),
    fullName: user.fullName,
    email: user.email,
    phone: user.phone ?? null,
    role: user.role,
  };
}

function assertName(value) {
  if (typeof value !== "string") {
    throw new AuthError("invalid_name", "Enter your full name.");
  }
  const name = value.trim();
  if (name.length < 1 || name.length > 150 || /[\u0000-\u001F]/.test(name)) {
    throw new AuthError("invalid_name", "Enter your full name.");
  }
  return name;
}

function assertEmail(value) {
  if (typeof value !== "string") {
    throw new AuthError("invalid_email", "Enter a valid email address.");
  }
  const email = value.trim().toLowerCase();
  if (
    email.length < 3 ||
    email.length > 255 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ) {
    throw new AuthError("invalid_email", "Enter a valid email address.");
  }
  return email;
}

function assertPassword(value) {
  if (typeof value !== "string" || value.length < 10 || value.length > 128) {
    throw new AuthError(
      "invalid_password",
      "Use a password of at least 10 characters and at most 128.",
    );
  }
  return value;
}

function assertPhone(value) {
  if (value == null || value === "") return null;
  if (typeof value !== "string") {
    throw new AuthError("invalid_phone", "Enter a valid phone number.");
  }
  const phone = value.trim();
  if (phone.length < 1 || phone.length > 30 || !/^[0-9+().\-\s]+$/.test(phone)) {
    throw new AuthError("invalid_phone", "Enter a valid phone number.");
  }
  return phone;
}

function assertPublicRole(value) {
  if (value == null || value === "") return "customer";
  if (typeof value !== "string") {
    throw new AuthError("invalid_role", "You can register only as a customer or an owner.");
  }
  const role = value.trim().toLowerCase();
  if (!PUBLIC_ROLES.has(role)) {
    throw new AuthError("invalid_role", "You can register only as a customer or an owner.");
  }
  return role;
}

module.exports = {
  SESSION_LIFETIME_MS,
  createAuthService,
  publicUser,
};
