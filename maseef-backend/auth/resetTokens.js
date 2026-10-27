const crypto = require("crypto");

// Password-reset tokens are signed, not stored, so no table is needed.
//
//   token = <userId>.<expiresAtEpochSeconds>.<signature>
//   signature = HMAC-SHA256(secret, purpose | userId | expiresAt | passwordHash)
//
// Because the *current password hash* is part of the signed data:
//   - the token stops working the moment the password changes (single use);
//   - it stops working after expiresAt (time limit);
//   - it cannot be forged or extended without the server secret;
//   - nothing is written to the database when a link is requested.
// The token is never logged or stored; only the user's own email receives it.

const PURPOSE = "maseef:password-reset:v1";
const DEFAULT_TTL_MS = 60 * 60 * 1000;
const MIN_SECRET_LENGTH = 32;
const TOKEN_FORMAT = /^(\d{1,19})\.(\d{1,12})\.([A-Za-z0-9_-]{43})$/;

function createResetTokens({ secret, ttlMs = DEFAULT_TTL_MS }) {
  if (typeof secret !== "string" || secret.length < MIN_SECRET_LENGTH) {
    throw new Error(
      `PASSWORD_RESET_SECRET must be at least ${MIN_SECRET_LENGTH} characters.`,
    );
  }

  function sign(userId, expiresAt, passwordHash) {
    return crypto
      .createHmac("sha256", secret)
      .update(`${PURPOSE}\n${userId}\n${expiresAt}\n${passwordHash}`)
      .digest("base64url");
  }

  return {
    ttlMs,

    create({ userId, passwordHash, now }) {
      const expiresAt = Math.floor((now.getTime() + ttlMs) / 1000);
      const id = String(userId);
      return `${id}.${expiresAt}.${sign(id, expiresAt, passwordHash)}`;
    },

    /** Reads the user id out of a well-formed token. Proves nothing yet. */
    parse(token) {
      if (typeof token !== "string") return null;
      const match = TOKEN_FORMAT.exec(token);
      if (!match) return null;
      return {
        userId: match[1],
        expiresAt: Number(match[2]),
        signature: match[3],
      };
    },

    /** True only for an unexpired token signed for this user's current hash. */
    verify(parsed, { userId, passwordHash, now }) {
      if (!parsed || String(userId) !== parsed.userId) return false;
      if (parsed.expiresAt * 1000 <= now.getTime()) return false;
      const expected = Buffer.from(sign(parsed.userId, parsed.expiresAt, passwordHash));
      const given = Buffer.from(parsed.signature);
      return expected.length === given.length && crypto.timingSafeEqual(expected, given);
    },
  };
}

module.exports = { DEFAULT_TTL_MS, MIN_SECRET_LENGTH, createResetTokens };
