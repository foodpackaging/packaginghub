const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const env = require('../config/env');

function signAccessToken(user, options = {}) {
  return jwt.sign({ sub: user._id.toString(), role: user.role }, env.jwt.accessSecret(), {
    expiresIn: options.expiresIn || env.jwt.accessExpiresIn,
  });
}

function signRefreshToken(user) {
  return jwt.sign({ sub: user._id.toString() }, env.jwt.refreshSecret(), {
    expiresIn: env.jwt.refreshExpiresIn,
  });
}

function verifyAccessToken(token) {
  return jwt.verify(token, env.jwt.accessSecret());
}

function verifyRefreshToken(token) {
  return jwt.verify(token, env.jwt.refreshSecret());
}

// Ambiguous glyphs (O/0, I/1/L) are left out so a code read off an email is easy to retype.
const RESET_CODE_LETTERS = 'ABCDEFGHJKMNPQRSTUVWXYZ';
const RESET_CODE_DIGITS = '23456789';
const RESET_CODE_LENGTH = 6;

function generateResetCode() {
  const pool = RESET_CODE_LETTERS + RESET_CODE_DIGITS;
  // Seed with one of each so every code is genuinely a letter/number mix.
  const chars = [
    RESET_CODE_LETTERS[crypto.randomInt(RESET_CODE_LETTERS.length)],
    RESET_CODE_DIGITS[crypto.randomInt(RESET_CODE_DIGITS.length)],
  ];
  while (chars.length < RESET_CODE_LENGTH) {
    chars.push(pool[crypto.randomInt(pool.length)]);
  }
  // Shuffle so the seeded letter and digit aren't always in the first two slots.
  for (let i = chars.length - 1; i > 0; i -= 1) {
    const j = crypto.randomInt(i + 1);
    [chars[i], chars[j]] = [chars[j], chars[i]];
  }
  return chars.join('');
}

// Codes are generated uppercase; normalizing lets people type them in any case.
function normalizeResetCode(code) {
  return typeof code === 'string' ? code.trim().toUpperCase() : '';
}

function hashToken(rawToken) {
  return crypto.createHash('sha256').update(rawToken).digest('hex');
}

module.exports = {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  generateResetCode,
  normalizeResetCode,
  hashToken,
  RESET_CODE_LENGTH,
};
