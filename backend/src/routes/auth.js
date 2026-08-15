const express = require('express');
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const {
  signAccessToken,
  signRefreshToken,
  verifyRefreshToken,
  generateResetCode,
  normalizeResetCode,
  hashToken,
} = require('../utils/tokens');
const { sendPasswordResetEmail } = require('../utils/mailer');
const { requireAuth } = require('../middleware/auth');
const { serializeUser } = require('../utils/serializers');

const router = express.Router();

const RESET_CODE_TTL_MS = 15 * 60 * 1000;
const RESET_RESEND_COOLDOWN_MS = 60 * 1000;
const RESET_MAX_ATTEMPTS = 5;
const ADMIN_COOKIE_MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;

function isValidEmail(email) {
  return typeof email === 'string' && /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

// Stray whitespace and capitalisation from mobile keyboards shouldn't fail a login.
function normalizeEmail(email) {
  return typeof email === 'string' ? email.trim().toLowerCase() : '';
}

function clearResetState(user) {
  user.passwordResetTokenHash = undefined;
  user.passwordResetExpiresAt = undefined;
  user.passwordResetSentAt = undefined;
  user.passwordResetAttempts = 0;
}

// Shared by /verify-reset-code and /reset-password so both enforce identical rules.
// Returns null when the code is good, otherwise the { status, error } to respond with.
async function validateResetCode(user, code) {
  if (
    !user ||
    !user.passwordResetTokenHash ||
    !user.passwordResetExpiresAt ||
    user.passwordResetExpiresAt < new Date()
  ) {
    return { status: 400, error: 'This reset code has expired. Please request a new one.' };
  }

  if (user.passwordResetAttempts >= RESET_MAX_ATTEMPTS) {
    clearResetState(user);
    await user.save();
    return { status: 429, error: 'Too many incorrect attempts. Please request a new code.' };
  }

  if (user.passwordResetTokenHash !== hashToken(code)) {
    user.passwordResetAttempts += 1;
    await user.save();
    const remaining = RESET_MAX_ATTEMPTS - user.passwordResetAttempts;
    return {
      status: 400,
      error: `Incorrect code. ${remaining} attempt${remaining === 1 ? '' : 's'} remaining.`,
    };
  }

  return null;
}

function tokenPair(user) {
  return { access_token: signAccessToken(user), refresh_token: signRefreshToken(user) };
}

router.post('/signup', async (req, res) => {
  const { password } = req.body;
  const email = normalizeEmail(req.body.email);
  if (!isValidEmail(email) || !password || password.length < 6) {
    return res.status(400).json({ error: 'Valid email and a password of at least 6 characters are required' });
  }

  const existing = await User.findOne({ email });
  if (existing) return res.status(409).json({ error: 'An account with this email already exists' });

  const passwordHash = await bcrypt.hash(password, 10);
  const user = await User.create({ email, passwordHash, role: 'customer' });

  res.status(201).json({ ...tokenPair(user), user: serializeUser(user) });
});

router.post('/login', async (req, res) => {
  const { password } = req.body;
  const email = normalizeEmail(req.body.email);
  if (!isValidEmail(email) || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  const user = await User.findOne({ email });
  if (!user || !(await bcrypt.compare(password, user.passwordHash))) {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  res.json({ ...tokenPair(user), user: serializeUser(user) });
});

router.post('/admin/login', async (req, res) => {
  const { password } = req.body;
  const email = normalizeEmail(req.body.email);
  if (!isValidEmail(email) || !password) {
    return res.status(400).json({ error: 'Email and password are required' });
  }

  const user = await User.findOne({ email });
  if (!user || !(await bcrypt.compare(password, user.passwordHash)) || user.role !== 'admin') {
    return res.status(401).json({ error: 'Invalid email or password' });
  }

  const accessToken = signAccessToken(user, { expiresIn: '7d' });
  res.cookie('accessToken', accessToken, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    maxAge: ADMIN_COOKIE_MAX_AGE_MS,
  });
  res.json({ user: serializeUser(user) });
});

router.post('/admin/logout', (req, res) => {
  res.clearCookie('accessToken');
  res.json({ ok: true });
});

router.post('/refresh', async (req, res) => {
  const { refresh_token: refreshToken } = req.body;
  if (!refreshToken) return res.status(400).json({ error: 'refresh_token is required' });

  try {
    const payload = verifyRefreshToken(refreshToken);
    const user = await User.findById(payload.sub);
    if (!user) return res.status(401).json({ error: 'Invalid refresh token' });

    res.json({ access_token: signAccessToken(user) });
  } catch (err) {
    res.status(401).json({ error: 'Invalid or expired refresh token' });
  }
});

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: serializeUser(req.user) });
});

router.post('/logout', requireAuth, (req, res) => {
  res.json({ ok: true });
});

router.post('/forgot-password', async (req, res) => {
  const email = normalizeEmail(req.body.email);
  if (!isValidEmail(email)) return res.status(400).json({ error: 'Valid email is required' });

  const user = await User.findOne({ email });
  // Always respond with 200 so this endpoint can't be used to enumerate registered emails.
  if (!user) return res.json({ ok: true });

  const sinceLastSend = user.passwordResetSentAt ? Date.now() - user.passwordResetSentAt.getTime() : Infinity;
  if (sinceLastSend < RESET_RESEND_COOLDOWN_MS) {
    const retryAfter = Math.ceil((RESET_RESEND_COOLDOWN_MS - sinceLastSend) / 1000);
    return res.status(429).json({ error: `Please wait ${retryAfter}s before requesting another code.` });
  }

  const code = generateResetCode();

  // Send before persisting: a failed send shouldn't invalidate a code the user already has.
  try {
    await sendPasswordResetEmail(user.email, code);
  } catch (err) {
    console.error('Failed to send password reset email:', err.message);
    return res.status(502).json({ error: "We couldn't send the reset email right now. Please try again in a moment." });
  }

  user.passwordResetTokenHash = hashToken(code);
  user.passwordResetExpiresAt = new Date(Date.now() + RESET_CODE_TTL_MS);
  user.passwordResetSentAt = new Date();
  user.passwordResetAttempts = 0;
  await user.save();

  res.json({ ok: true });
});

// Step 1 of the reset flow: confirm the code before the app asks for a new password.
// Deliberately does not consume the code — /reset-password re-checks it on submit.
router.post('/verify-reset-code', async (req, res) => {
  const email = normalizeEmail(req.body.email);
  const code = normalizeResetCode(req.body.code);
  if (!isValidEmail(email) || !code) {
    return res.status(400).json({ error: 'Email and reset code are required' });
  }

  const user = await User.findOne({ email });
  const failure = await validateResetCode(user, code);
  if (failure) return res.status(failure.status).json({ error: failure.error });

  res.json({ ok: true });
});

router.post('/reset-password', async (req, res) => {
  const { new_password: newPassword } = req.body;
  const email = normalizeEmail(req.body.email);
  const code = normalizeResetCode(req.body.code);
  if (!isValidEmail(email) || !code || !newPassword || newPassword.length < 6) {
    return res.status(400).json({ error: 'Email, code, and a new password of at least 6 characters are required' });
  }

  const user = await User.findOne({ email });
  const failure = await validateResetCode(user, code);
  if (failure) return res.status(failure.status).json({ error: failure.error });

  user.passwordHash = await bcrypt.hash(newPassword, 10);
  clearResetState(user);
  await user.save();

  res.json({ ok: true });
});

router.post('/update-password', requireAuth, async (req, res) => {
  const { new_password: newPassword } = req.body;
  if (!newPassword || newPassword.length < 6) {
    return res.status(400).json({ error: 'A new password of at least 6 characters is required' });
  }
  req.user.passwordHash = await bcrypt.hash(newPassword, 10);
  await req.user.save();
  res.json({ ok: true });
});

module.exports = router;
