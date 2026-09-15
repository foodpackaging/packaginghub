const { verifyAccessToken } = require('../utils/tokens');
const User = require('../models/User');

function getBearerToken(req) {
  const header = req.headers.authorization || '';
  if (header.startsWith('Bearer ')) return header.slice(7);
  return null;
}

async function requireAuth(req, res, next) {
  try {
    const token = getBearerToken(req) || req.cookies?.accessToken;
    if (!token) return res.status(401).json({ error: 'Not authenticated' });

    const payload = verifyAccessToken(token);
    const user = await User.findById(payload.sub);
    if (!user) return res.status(401).json({ error: 'Not authenticated' });

    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
}

function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin access required' });
  }
  next();
}

/**
 * Gates the `?all=true` bypass some public catalog GET routes (categories,
 * products, filters) offer the admin dashboard to see inactive/unpublished
 * records. Without this, anyone unauthenticated could pass all=true and see
 * the same data. When all=true isn't requested, this is a no-op and the
 * route stays public, same as before.
 */
async function requireAdminForAllTrue(req, res, next) {
  if (req.query.all !== 'true') return next();
  await requireAuth(req, res, (err) => {
    if (err) return next(err);
    requireAdmin(req, res, next);
  });
}

module.exports = { requireAuth, requireAdmin, requireAdminForAllTrue, getBearerToken };
