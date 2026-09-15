// Web Push for the admin dashboard, mirroring the Flutter app's FCM setup on
// the backend side (same DeviceToken model, same notifyUser plumbing — see
// backend/src/services/orderNotifications.js:notifyAdminNewOrder). This file
// is the only new piece: registering this browser as a 'web' device and
// showing the incoming notification while the tab is open.
import { initializeApp, getApps } from 'firebase/app';
import { getMessaging, getToken, onMessage } from 'firebase/messaging';
import { api } from './apiClient';

const firebaseConfig = {
  apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
  authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
  storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
  messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
  appId: import.meta.env.VITE_FIREBASE_APP_ID,
};
const vapidKey = import.meta.env.VITE_FIREBASE_VAPID_KEY;

function isConfigured() {
  return Boolean(
    firebaseConfig.apiKey &&
      firebaseConfig.projectId &&
      firebaseConfig.messagingSenderId &&
      firebaseConfig.appId &&
      vapidKey
  );
}

let started = false;
// Set once by App.jsx so the notification's onclick handler (which fires
// outside React's render cycle, possibly much later) can still navigate.
let orderDeepLinkHandler = null;

/**
 * Registers this browser for new-order push notifications. Safe to call on
 * every login — it's a one-time no-op if Firebase web config isn't set
 * (the VITE_FIREBASE_* vars), if the browser/user denies permission, or if
 * it's already been started this session. Push is optional: the dashboard
 * works fully without it, same as the mobile app without a google-services.json.
 *
 * - onNewOrder(payload): fires as soon as a message arrives (e.g. to refresh
 *   the order list if it's already open) — never navigates on its own.
 * - onOrderDeepLink(orderId): fires when the admin clicks the notification.
 */
export async function registerAdminPush({ onNewOrder, onOrderDeepLink } = {}) {
  if (onOrderDeepLink) orderDeepLinkHandler = onOrderDeepLink;
  if (started) return;
  if (!isConfigured()) {
    console.warn('[push] Firebase web config not set (VITE_FIREBASE_* in .env) — admin push notifications disabled.');
    return;
  }
  if (!('Notification' in window) || !('serviceWorker' in navigator)) return;

  try {
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return;

    // firebase-messaging-sw.js is a static file in public/ and can't read Vite
    // env vars at runtime, so the config is passed to it as a query string —
    // these are public, client-safe Firebase web values, not secrets.
    const swParams = new URLSearchParams(firebaseConfig).toString();
    const registration = await navigator.serviceWorker.register(`/firebase-messaging-sw.js?${swParams}`);

    const app = getApps().length ? getApps()[0] : initializeApp(firebaseConfig);
    const messaging = getMessaging(app);
    const token = await getToken(messaging, { vapidKey, serviceWorkerRegistration: registration });
    if (!token) return;

    // Same endpoint the Flutter app already uses — 'web' is an existing
    // DeviceToken.platform value, no backend change was needed for this.
    await api.post('/devices', { token, platform: 'web' });
    started = true;

    onMessage(messaging, (payload) => {
      showForegroundNotification(payload);
      if (onNewOrder) onNewOrder(payload);
    });
  } catch (err) {
    console.error('[push] Admin push registration failed:', err.message);
  }
}

/**
 * FCM only auto-displays a notification via the service worker when the tab
 * isn't focused — a foreground message has to be shown manually, or the
 * admin would see nothing while the dashboard is open (the most likely time
 * they'd actually be looking at it).
 */
function showForegroundNotification(payload) {
  const title = payload?.notification?.title || 'New order';
  const body = payload?.notification?.body || '';
  const orderId = payload?.data?.order_id;

  try {
    const notification = new Notification(title, { body, tag: orderId || undefined });
    notification.onclick = () => {
      window.focus();
      notification.close();
      if (orderId && orderDeepLinkHandler) orderDeepLinkHandler(orderId);
    };
  } catch (err) {
    console.error('[push] Failed to show foreground notification:', err.message);
  }
}
