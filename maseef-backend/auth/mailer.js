const nodemailer = require("nodemailer");

// Sends mail over SMTP. It is only "configured" when the real settings exist;
// there is deliberately no console or fake fallback, so the API can never claim
// a reset email went out when nothing could deliver it.
//
// Environment variables:
//   SMTP_HOST      required   e.g. smtp.gmail.com
//   SMTP_PORT      optional   default 587 (STARTTLS); use 465 with SMTP_SECURE=true
//   SMTP_SECURE    optional   "true" for implicit TLS (port 465)
//   SMTP_USER      optional   login; must be given together with SMTP_PASSWORD
//   SMTP_PASSWORD  optional   login secret (an app password for Gmail)
//   SMTP_REQUIRE_TLS optional "false" only for a local test server
//   MAIL_FROM      required   e.g. "MASEEF <no-reply@your-domain.com>"

function readMailSettings(env = process.env) {
  const host = clean(env.SMTP_HOST);
  const from = clean(env.MAIL_FROM);
  const user = clean(env.SMTP_USER);
  const pass = env.SMTP_PASSWORD ? String(env.SMTP_PASSWORD) : "";
  const secure = String(env.SMTP_SECURE ?? "").toLowerCase() === "true";
  const port = Number(env.SMTP_PORT || (secure ? 465 : 587));

  const missing = [];
  if (!host) missing.push("SMTP_HOST");
  if (!from) missing.push("MAIL_FROM");
  if (Boolean(user) !== Boolean(pass)) {
    missing.push(user ? "SMTP_PASSWORD" : "SMTP_USER");
  }
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    missing.push("SMTP_PORT (invalid)");
  }

  return {
    missing,
    host,
    from,
    user,
    pass,
    secure,
    port,
    requireTLS:
      !secure && String(env.SMTP_REQUIRE_TLS ?? "true").toLowerCase() !== "false",
  };
}

/** Returns a mailer, or null when the SMTP settings are missing or incomplete. */
function createSmtpMailerFromEnv(env = process.env) {
  const settings = readMailSettings(env);
  if (settings.missing.length) return null;
  const transport = nodemailer.createTransport({
    host: settings.host,
    port: settings.port,
    secure: settings.secure,
    requireTLS: settings.requireTLS,
    auth: settings.user ? { user: settings.user, pass: settings.pass } : undefined,
    connectionTimeout: 10_000,
    greetingTimeout: 10_000,
    socketTimeout: 20_000,
  });
  return createMailer({ transport, from: settings.from });
}

function createMailer({ transport, from }) {
  return {
    async send({ to, subject, text, html }) {
      await transport.sendMail({ from, to, subject, text, html });
    },
  };
}

function clean(value) {
  return typeof value === "string" ? value.trim() : "";
}

module.exports = { createMailer, createSmtpMailerFromEnv, readMailSettings };
