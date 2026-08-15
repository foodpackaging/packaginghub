/**
 * Vercel serverless entry point.
 *
 * Vercel invokes this per request instead of running `src/server.js` as a
 * process, so the database connection has to be established inside the handler
 * rather than at boot. connectDb() is cached, so this is a no-op on every
 * request after the first on a warm instance.
 *
 * vercel.json rewrites every path here while preserving the original URL, so
 * Express still routes on `/api/orders`, `/health`, and so on unchanged.
 */
const app = require('../src/server');
const { connectDb } = require('../src/config/db');

module.exports = async (req, res) => {
  try {
    await connectDb();
  } catch (err) {
    console.error('Database connection failed:', err);
    return res.status(503).json({ error: 'Service temporarily unavailable' });
  }
  return app(req, res);
};
