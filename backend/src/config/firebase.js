// firebase-admin v13+ is modular: the root export no longer carries the
// `credential` namespace or a `messaging()` method, so both come from their
// own subpaths.
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const env = require('./env');

let app = null;
let initialized = false;
let warned = false;

/**
 * Returns the Firebase Admin app, or null when credentials are not configured.
 *
 * Push is an optional capability: a developer running the API without Firebase
 * keys should still be able to place orders and change statuses, so every caller
 * treats null as "skip sending" rather than an error.
 */
function getFirebaseApp() {
  if (initialized) return app;
  initialized = true;

  const credentials = env.firebase.credentials();
  if (!credentials) {
    if (!warned) {
      warned = true;
      console.warn('[push] Firebase credentials not configured — push notifications are disabled.');
    }
    return null;
  }

  try {
    // Reuse the default app if something already created it (e.g. a script that
    // required this module twice through different paths).
    app = getApps().length > 0
      ? getApps()[0]
      : initializeApp({
          credential: cert(credentials),
          projectId: credentials.projectId,
        });
  } catch (err) {
    console.error('[push] Failed to initialize Firebase Admin:', err.message);
    app = null;
  }
  return app;
}

function getMessagingClient() {
  const instance = getFirebaseApp();
  return instance ? getMessaging(instance) : null;
}

module.exports = { getFirebaseApp, getMessaging: getMessagingClient };
