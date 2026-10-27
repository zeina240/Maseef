const { createSmtpMailerFromEnv, readMailSettings } = require("./mailer");
const { DEFAULT_TTL_MS, MIN_SECRET_LENGTH, createResetTokens } = require("./resetTokens");

// Builds the password-reset settings from environment variables.
//
//   PASSWORD_RESET_SECRET        required  32+ random characters (signs the links)
//   APP_BASE_URL                 required  where the Flutter web app is served,
//                                          e.g. https://maseef.example.com
//   SMTP_* and MAIL_FROM         required  see mailer.js
//   PASSWORD_RESET_TTL_MINUTES   optional  default 60 (1 to 1440)
//
// Anything missing is listed in `missing` (names only, never values) and the
// matching part stays null, so the API reports "unavailable" instead of
// pretending to send an email.
function passwordResetFromEnv(env = process.env) {
  const missing = [];
  let tokens = null;
  let mailer = null;
  let appBaseUrl = null;

  const minutes = Number(env.PASSWORD_RESET_TTL_MINUTES || DEFAULT_TTL_MS / 60000);
  const ttlMs =
    Number.isFinite(minutes) && minutes >= 1 && minutes <= 1440
      ? Math.round(minutes * 60000)
      : DEFAULT_TTL_MS;

  const secret = typeof env.PASSWORD_RESET_SECRET === "string" ? env.PASSWORD_RESET_SECRET : "";
  if (secret.length >= MIN_SECRET_LENGTH) {
    tokens = createResetTokens({ secret, ttlMs });
  } else {
    missing.push(
      secret ? `PASSWORD_RESET_SECRET (needs ${MIN_SECRET_LENGTH}+ characters)` : "PASSWORD_RESET_SECRET",
    );
  }

  appBaseUrl = parseBaseUrl(env.APP_BASE_URL);
  if (!appBaseUrl) missing.push("APP_BASE_URL");

  const mail = readMailSettings(env);
  if (mail.missing.length) {
    missing.push(...mail.missing);
  } else {
    mailer = createSmtpMailerFromEnv(env);
  }

  return { tokens, mailer, appBaseUrl, ttlMs, missing };
}

function parseBaseUrl(value) {
  if (typeof value !== "string" || !value.trim()) return null;
  try {
    const url = new URL(value.trim());
    if (url.protocol !== "https:" && url.protocol !== "http:") return null;
    if (url.username || url.password || url.search || url.hash) return null;
    return `${url.origin}${url.pathname}`.replace(/\/+$/, "");
  } catch {
    return null;
  }
}

module.exports = { parseBaseUrl, passwordResetFromEnv };
