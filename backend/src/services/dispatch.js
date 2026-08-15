/**
 * Runs a notification send alongside the request that triggered it.
 *
 * Two runtimes, two correct behaviours:
 *
 * - **Long-running server** (`npm start`, a VM, a container): fire-and-forget.
 *   The customer's checkout must not wait on Firebase, and a push failure must
 *   never fail the order.
 *
 * - **Serverless** (Vercel, Lambda): the platform may freeze or reclaim the
 *   instance as soon as the response is sent, so a floating promise is simply
 *   dropped and the notification never goes out. There we have to await it
 *   before responding, trading a few hundred milliseconds for delivery.
 *
 * Errors are swallowed in both cases — a push is a side effect of the order
 * changing, never a precondition for it.
 */
const IS_SERVERLESS = Boolean(
  process.env.VERCEL || process.env.AWS_LAMBDA_FUNCTION_NAME || process.env.FUNCTIONS_WORKER_RUNTIME
);

async function dispatch(promiseFactory) {
  const run = Promise.resolve()
    .then(promiseFactory)
    .catch((err) => console.error('[push] Notification dispatch failed:', err.message));

  if (IS_SERVERLESS) await run;
}

module.exports = { dispatch, IS_SERVERLESS };
