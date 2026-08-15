const mongoose = require('mongoose');
const env = require('./env');

/**
 * Mongoose connection, cached across serverless invocations.
 *
 * A warm serverless instance reuses the same Node process for many requests, so
 * the connection is memoised on `global` rather than reopened per invocation —
 * reconnecting each time exhausts Atlas's connection limit under any real load,
 * and pays the handshake cost on every request. On a long-running server this
 * simply resolves once at boot and returns the same connection forever after.
 *
 * The in-flight promise is cached too, not just the resolved connection, so
 * concurrent cold-start requests share one dial-out instead of racing.
 */
let cached = global._mongoose;
if (!cached) cached = global._mongoose = { conn: null, promise: null };

async function connectDb() {
  if (cached.conn) return cached.conn;

  if (!cached.promise) {
    mongoose.set('strictQuery', true);
    cached.promise = mongoose
      .connect(env.mongoUri(), { maxPoolSize: 10 })
      .then((m) => {
        console.log('MongoDB connected');
        return m;
      })
      .catch((err) => {
        // Clear the cache so the next request retries instead of resolving
        // against a permanently rejected promise.
        cached.promise = null;
        throw err;
      });
  }

  cached.conn = await cached.promise;
  return cached.conn;
}

module.exports = { connectDb };
