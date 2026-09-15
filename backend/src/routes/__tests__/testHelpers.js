// Shared setup for the route test suites. Not itself a test file — jest.config.js
// restricts testMatch to *.test.js so this can live alongside them safely.
//
// Deliberately sets these BEFORE anything else is required, so tests are
// hermetic: predictable secret values under our control for computing
// matching HMACs, regardless of whatever a real developer .env
// (backend/.env) happens to contain. Never connects to a real database —
// startDb() below always points Mongoose at an in-memory replica set.
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.RAZORPAY_KEY_ID = 'rzp_test_dummy';
process.env.RAZORPAY_KEY_SECRET = 'test-razorpay-key-secret';
process.env.RAZORPAY_WEBHOOK_SECRET = 'test-razorpay-webhook-secret';
process.env.NODE_ENV = 'test';

const mongoose = require('mongoose');
const { MongoMemoryReplSet } = require('mongodb-memory-server');
const bcrypt = require('bcryptjs');
const User = require('../../models/User');
const Product = require('../../models/Product');
const { signAccessToken } = require('../../utils/tokens');

let replSet;

/** A one-node replica set is a genuine replica set — transactions work — without the overhead of a multi-node cluster. */
async function startDb() {
  replSet = await MongoMemoryReplSet.create({
    replSet: { count: 1 },
    // Pinned rather than "latest", so a future mongodb-memory-server run
    // doesn't silently start downloading a different MongoDB server version.
    binary: { version: '7.0.14' },
  });
  await mongoose.connect(replSet.getUri(), { maxPoolSize: 10 });
}

async function stopDb() {
  await mongoose.disconnect();
  if (replSet) await replSet.stop();
}

async function clearDb() {
  const { collections } = mongoose.connection;
  await Promise.all(Object.values(collections).map((c) => c.deleteMany({})));
}

async function createUser({ role = 'customer', email, password = 'password123', ...rest } = {}) {
  const passwordHash = await bcrypt.hash(password, 4); // low cost: test speed, not secrecy
  const user = await User.create({
    email: email || `${role}-${Date.now()}-${Math.random().toString(36).slice(2)}@test.com`,
    passwordHash,
    role,
    ...rest,
  });
  return { user, token: signAccessToken(user), password };
}

async function createProduct(overrides = {}) {
  return Product.create({
    name: 'Test Product',
    price: 100,
    stockQuantity: 50,
    minOrderQty: 1,
    isActive: true,
    ...overrides,
  });
}

module.exports = { startDb, stopDb, clearDb, createUser, createProduct };
