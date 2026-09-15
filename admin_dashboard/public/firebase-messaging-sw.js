// Background handler for admin new-order push notifications. This is a
// static file (served as-is by Vite, not processed) so it can't read the
// app's Vite env vars — src/pushService.js passes the Firebase web config
// through the registration URL's query string instead. Those values are
// public/client-safe by design (restricted by Firebase's own security rules,
// not by secrecy), unlike the backend's service-account private key.
importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.1/firebase-messaging-compat.js');

const params = new URLSearchParams(self.location.search);

firebase.initializeApp({
  apiKey: params.get('apiKey'),
  authDomain: params.get('authDomain'),
  projectId: params.get('projectId'),
  storageBucket: params.get('storageBucket'),
  messagingSenderId: params.get('messagingSenderId'),
  appId: params.get('appId'),
});

// Firebase's compat SDK shows a default notification for a background
// message on its own (the payload always includes a `notification` block —
// see backend/src/services/pushService.js) and attaches `data` to it, so
// there's nothing to do here beyond initializing — only notificationclick
// needs custom handling, to open the right order.
firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const orderId = event.notification?.data?.order_id;
  const targetUrl = orderId ? `/?order=${encodeURIComponent(orderId)}` : '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) return clients.openWindow(targetUrl);
    })
  );
});
