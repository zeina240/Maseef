class AuthError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.name = "AuthError";
    this.code = code;
    this.status = status;
  }
}

function sendAuthError(res, error) {
  if (error instanceof AuthError) {
    res.status(error.status).json({
      status: "error",
      code: error.code,
      message: error.message,
    });
    return;
  }

  res.status(500).json({
    status: "error",
    code: "internal_error",
    message: "The request could not be completed.",
  });
}

function sendUnauthenticated(res) {
  sendAuthError(
    res,
    new AuthError("unauthenticated", "Sign in required.", 401),
  );
}

module.exports = { AuthError, sendAuthError, sendUnauthenticated };
