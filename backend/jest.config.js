module.exports = {
  testEnvironment: 'node',
  // Explicit rather than Jest's default (which also matches any .js file
  // inside a __tests__ folder) so testHelpers.js can live alongside the
  // actual test files without Jest trying to run it as one.
  testMatch: ['**/__tests__/**/*.test.js'],
  // Spinning up an in-memory MongoDB replica set (needed for the
  // transactions in routes/orders.js) is slower than a typical unit test,
  // especially on the first run while mongodb-memory-server downloads and
  // caches the MongoDB binary.
  testTimeout: 60000,
};
