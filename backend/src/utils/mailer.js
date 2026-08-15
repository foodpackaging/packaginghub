const nodemailer = require('nodemailer');
const env = require('../config/env');

let transporter = null;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: env.smtp.host,
      port: env.smtp.port,
      secure: env.smtp.secure,
      auth: env.smtp.user ? { user: env.smtp.user, pass: env.smtp.pass } : undefined,
    });
  }
  return transporter;
}

async function sendPasswordResetEmail(toEmail, code) {
  await getTransporter().sendMail({
    from: env.smtp.from,
    to: toEmail,
    subject: `${code} is your password reset code`,
    text: [
      'We received a request to reset your B2B Store password.',
      '',
      `Your reset code is: ${code}`,
      '',
      "Enter this code in the app to choose a new password. It expires in 15 minutes and isn't case-sensitive.",
      "If you didn't request this, you can safely ignore this email — your password stays unchanged.",
    ].join('\n'),
    html: `
      <div style="font-family:Arial,Helvetica,sans-serif;max-width:480px;margin:0 auto;padding:24px;color:#1f2937;">
        <h2 style="margin:0 0 8px;font-size:20px;">Reset your password</h2>
        <p style="margin:0 0 24px;color:#6b7280;font-size:14px;">
          We received a request to reset your B2B Store password. Enter the code below in the app.
        </p>
        <div style="background:#f3f4f6;border-radius:12px;padding:20px;text-align:center;margin-bottom:24px;">
          <div style="font-size:32px;font-weight:bold;letter-spacing:8px;font-family:'Courier New',monospace;">${code}</div>
        </div>
        <p style="margin:0 0 8px;font-size:14px;">This code expires in <strong>15 minutes</strong> and isn't case-sensitive.</p>
        <p style="margin:0;color:#6b7280;font-size:13px;">
          If you didn't request this, you can safely ignore this email — your password stays unchanged.
        </p>
      </div>
    `,
  });
}

module.exports = { sendPasswordResetEmail };
