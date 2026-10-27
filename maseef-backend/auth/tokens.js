const crypto = require("crypto");

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/;

function newSessionToken() {
  return crypto.randomBytes(32).toString("base64url");
}

function hashSessionToken(token) {
  return crypto.createHash("sha256").update(token, "utf8").digest("hex");
}

function readBearer(header) {
  if (typeof header !== "string") return null;
  const match = /^Bearer ([A-Za-z0-9_-]{43})$/.exec(header);
  return match ? match[1] : null;
}

module.exports = {
  TOKEN_PATTERN,
  newSessionToken,
  hashSessionToken,
  readBearer,
};
