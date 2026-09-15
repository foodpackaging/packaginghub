const rateLimit = require('express-rate-limit');

// Generic message on every limiter — never hints at which specific check
// failed (email exists, wrong password, etc.), so this can't be used to
// enumerate accounts any more than the routes themselves already prevent.
const message = { error: 'Too many attempts. Please wait a while and try again.' };

const standardOptions = {
  standardHeaders: true,
  legacyHeaders: false,
  message,
};

/**
 * Customer and admin login. Tighter than signup/reset: a login endpoint is
 * the direct target of credential-stuffing/brute-force, and the admin
 * account in particular controls the entire catalog and every order.
 */
const loginLimiter = rateLimit({
  ...standardOptions,
  windowMs: 15 * 60 * 1000,
  limit: 10,
});

/** Account creation and password-reset requests — abuse-prone but lower stakes than login. */
const signupLimiter = rateLimit({
  ...standardOptions,
  windowMs: 60 * 60 * 1000,
  limit: 10,
});

/**
 * Password-reset code verification/consumption. auth.js already enforces a
 * 5-attempt-per-code cap and a 60s resend cooldown at the application level;
 * this is IP-based defense-in-depth on top of that, not a replacement for it.
 */
const resetLimiter = rateLimit({
  ...standardOptions,
  windowMs: 15 * 60 * 1000,
  limit: 20,
});

module.exports = { loginLimiter, signupLimiter, resetLimiter };
