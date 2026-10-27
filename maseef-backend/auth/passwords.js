const { hash, verify } = require("@node-rs/argon2");

// Argon2id is algorithm 2 in @node-rs/argon2. That package publishes Algorithm
// as a TypeScript const enum, so the name is not present at runtime.
// OWASP password guidance: 19 MiB, 2 iterations, parallelism 1.
const ARGON2ID = 2;
const ARGON2ID_OPTIONS = Object.freeze({
  algorithm: ARGON2ID,
  memoryCost: 19456,
  timeCost: 2,
  parallelism: 1,
});

const DUMMY_PASSWORD = "maseef-auth-timing-placeholder-not-a-user-secret";

async function createPasswordHasher() {
  const dummyHash = await hash(DUMMY_PASSWORD, ARGON2ID_OPTIONS);

  return {
    options: ARGON2ID_OPTIONS,

    async hash(password) {
      return hash(password, ARGON2ID_OPTIONS);
    },

    async verify(passwordHash, password) {
      try {
        return await verify(passwordHash, password);
      } catch {
        return false;
      }
    },

    async verifyDummy(password) {
      try {
        return await verify(dummyHash, password);
      } catch {
        return false;
      }
    },
  };
}

module.exports = { ARGON2ID_OPTIONS, createPasswordHasher };
