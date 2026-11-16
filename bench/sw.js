// Service worker probe: intercepts a file that does not exist on disk,
// which proves fetch interception works when the SW is controlling the page.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  if (event.request.url.endsWith('/lab-marker.txt')) {
    event.respondWith(new Response('FROM-SERVICE-WORKER', {
      headers: { 'Content-Type': 'text/plain' }
    }));
  }
});
