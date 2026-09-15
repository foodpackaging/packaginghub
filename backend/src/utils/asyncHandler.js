// Express 4 does not forward a rejected/thrown error from an async route
// handler to the global error handler on its own — a caller has to pass it to
// next() explicitly. Wrapping a handler in this does that automatically, so a
// thrown error (a failed transaction, a Mongoose validation error) reaches the
// existing global handler in server.js and returns a safe generic 500 instead
// of hanging the request or crashing the process.
function asyncHandler(fn) {
  return (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
}

/** A deliberate, user-facing failure with a specific status code — as opposed
 * to an unexpected error, which the global handler turns into a generic 500. */
class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

module.exports = { asyncHandler, HttpError };
