// Offline-Service-Worker für Barstardo Learning.
// __BUILD_VERSION__ wird beim Build ersetzt (tools/web/prepare_offline.sh);
// eine neue Version lädt alle Dateien neu und löscht den alten Cache.
'use strict';

const VERSION = '__BUILD_VERSION__';
const CACHE = `barstardo-${VERSION}`;

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    const response = await fetch('precache.json', { cache: 'no-store' });
    const files = await response.json();
    const cache = await caches.open(CACHE);
    await cache.addAll(files.map((f) => new Request(f, { cache: 'reload' })));
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const key of await caches.keys()) {
      if (key.startsWith('barstardo-') && key !== CACHE) await caches.delete(key);
    }
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // Seitenaufruf: zuerst Netz (für Updates), offline aus dem Cache.
    if (request.mode === 'navigate') {
      try {
        const fresh = await fetch(request);
        if (fresh.ok) await cache.put('./', fresh.clone());
        return fresh;
      } catch (_) {
        return (await cache.match('./')) || (await cache.match('index.html')) ||
          Response.error();
      }
    }
    // Alles andere: Cache zuerst, sonst Netz (und für später merken).
    const cached = await cache.match(request, { ignoreSearch: true });
    if (cached) return cached;
    const response = await fetch(request);
    if (response.ok && url.pathname.indexOf('offline_sw.js') === -1) {
      cache.put(request, response.clone());
    }
    return response;
  })());
});
