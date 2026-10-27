// The password-reset email, in English or Arabic. The link is built from our
// own token alphabet (letters, digits, "-", "_", "."), so it needs no escaping,
// but it is still escaped before going into HTML.

const COPY = {
  en: {
    subject: "Reset your MASEEF password",
    heading: "Reset your password",
    intro:
      "We received a request to reset the password for your MASEEF account. Use the button below to choose a new one.",
    button: "Reset password",
    fallback: "If the button does not work, copy this link into your browser:",
    expiry: (minutes) =>
      `This link works once and expires in ${minutes} minutes.`,
    ignore:
      "If you did not ask for this, you can ignore this email. Your password will not change.",
    dir: "ltr",
    lang: "en",
  },
  ar: {
    subject: "إعادة تعيين كلمة المرور في MASEEF",
    heading: "إعادة تعيين كلمة المرور",
    intro:
      "وصلنا طلب لإعادة تعيين كلمة المرور لحسابك في MASEEF. استخدم الزر أدناه لاختيار كلمة مرور جديدة.",
    button: "إعادة تعيين كلمة المرور",
    fallback: "إذا لم يعمل الزر، انسخ هذا الرابط إلى المتصفح:",
    expiry: (minutes) =>
      `يعمل هذا الرابط مرة واحدة فقط وتنتهي صلاحيته بعد ${minutes} دقيقة.`,
    ignore:
      "إذا لم تطلب ذلك، يمكنك تجاهل هذه الرسالة. لن تتغير كلمة مرورك.",
    dir: "rtl",
    lang: "ar",
  },
};

function buildResetEmail({ link, locale = "en", ttlMs }) {
  const copy = COPY[locale === "ar" ? "ar" : "en"];
  const minutes = Math.max(1, Math.round(ttlMs / 60000));
  const align = copy.dir === "rtl" ? "right" : "left";
  const safeLink = escapeHtml(link);

  const text = [
    copy.heading,
    "",
    copy.intro,
    "",
    link,
    "",
    copy.expiry(minutes),
    copy.ignore,
    "",
    "MASEEF",
  ].join("\n");

  const html = `<!doctype html>
<html lang="${copy.lang}" dir="${copy.dir}">
<body style="margin:0;padding:24px;background:#EEF6FA;font-family:Tahoma,Arial,sans-serif;color:#1B2433;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border-radius:16px;padding:32px;text-align:${align};">
      <tr><td>
        <div style="font-size:14px;letter-spacing:2px;font-weight:bold;color:#123A68;">MASEEF</div>
        <h1 style="font-size:22px;color:#123A68;margin:18px 0 12px;">${escapeHtml(copy.heading)}</h1>
        <p style="font-size:15px;line-height:1.6;margin:0 0 22px;">${escapeHtml(copy.intro)}</p>
        <p style="margin:0 0 22px;"><a href="${safeLink}" style="display:inline-block;background:#123A68;color:#ffffff;text-decoration:none;font-weight:bold;padding:13px 26px;border-radius:12px;">${escapeHtml(copy.button)}</a></p>
        <p style="font-size:13px;line-height:1.6;color:#5A6575;margin:0 0 6px;">${escapeHtml(copy.fallback)}</p>
        <p style="font-size:12px;line-height:1.5;color:#2A62A6;word-break:break-all;margin:0 0 22px;" dir="ltr">${safeLink}</p>
        <p style="font-size:13px;line-height:1.6;color:#5A6575;margin:0 0 6px;">${escapeHtml(copy.expiry(minutes))}</p>
        <p style="font-size:13px;line-height:1.6;color:#5A6575;margin:0;">${escapeHtml(copy.ignore)}</p>
      </td></tr>
    </table>
  </td></tr></table>
</body>
</html>`;

  return { subject: copy.subject, text, html };
}

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

module.exports = { buildResetEmail };
