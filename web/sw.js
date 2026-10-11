// Fa funzionare Brain anche offline: i file dell'app restano in memoria sul telefono.
// I dati non passano di qui: stanno nel salvataggio locale del telefono.
// __BUILD__ viene sostituito a ogni pubblicazione, così le nuove versioni si scaricano.
const CACHE = 'brain-__BUILD__';
const FILES = [
  './', './index.html', './styles.css', './app.js', './logic.js', './store.js',
  './manifest.webmanifest', './icons/icon-180.png', './icons/icon-192.png', './icons/icon-512.png'
];

self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(FILES)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

// Prima la copia salvata (apertura istantanea, anche senza rete), poi l'aggiornamento in sottofondo.
self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  event.respondWith(
    caches.open(CACHE).then(async cache => {
      const cached = await cache.match(event.request, { ignoreSearch: true });
      const network = fetch(event.request)
        .then(response => {
          if (response.ok && new URL(event.request.url).origin === location.origin) cache.put(event.request, response.clone());
          return response;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
