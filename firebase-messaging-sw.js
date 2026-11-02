/* Firebase Messaging worker for the Mensajeros 911 PWA. */
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.0.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDAOBQG8FbJDff-GzRVqrKvYlBzS3aUTkc',
  authDomain: 'mensajeria911-e84c7.firebaseapp.com',
  projectId: 'mensajeria911-e84c7',
  storageBucket: 'mensajeria911-e84c7.firebasestorage.app',
  messagingSenderId: '916723097837',
  appId: '1:916723097837:web:9f184deee93aeb52502ce4',
});

const messaging = firebase.messaging();
const iconUrl = new URL('icons/Icon-192.png', self.registration.scope).href;

messaging.onBackgroundMessage((payload) => {
  // Con notification el SDK ya lo muestra; mostrarlo otra vez lo duplicaría.
  if (payload.notification) return;
  const notification = payload.notification || {};
  const data = payload.data || {};
  self.registration.showNotification(
    notification.title || `Nuevo servicio · ${data.code || '911'}`,
    {
      body: notification.body || 'Tienes un servicio pendiente de revisar.',
      icon: iconUrl,
      badge: iconUrl,
      tag: data.service_id || 'mensajeros-911-service',
      data,
      requireInteraction: true,
    },
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const target = new URL(self.registration.scope);
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if ('focus' in client) return client.focus();
      }
      return clients.openWindow(target.href);
    }),
  );
});
