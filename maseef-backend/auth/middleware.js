const { sendAuthError, sendUnauthenticated } = require("./errors");
const { hashSessionToken, readBearer } = require("./tokens");

function requireAuth(store, now = () => new Date()) {
  return async function authenticate(req, res, next) {
    try {
      const token = readBearer(req.get("authorization"));
      if (!token) {
        sendUnauthenticated(res);
        return;
      }

      const session = await store.findActiveSession(hashSessionToken(token), now());
      if (!session) {
        sendUnauthenticated(res);
        return;
      }

      // Identity comes from the stored user row. Client body and headers are ignored.
      req.user = {
        id: session.user.id,
        role: session.user.role,
      };
      next();
    } catch (error) {
      sendAuthError(res, error);
    }
  };
}

module.exports = { requireAuth };
