// ══════════════════════════════════════════════════════
//  NutriCoach — Service Worker (PWA)
//  Versión: 1.0
// ══════════════════════════════════════════════════════

const CACHE_NAME = 'nutricoach-v1';

// Archivos que se guardan para uso offline
const ASSETS_TO_CACHE = [
  '/login.html',
  '/app.html',
  '/manifest.json',
  '/icon-192.png',
  '/icon-512.png'
];

// ── INSTALL: guardar archivos en caché ──
self.addEventListener('install', event => {
  console.log('[SW] Instalando...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('[SW] Guardando archivos en caché');
        // addAll puede fallar si algún archivo no existe — usamos add individual
        return Promise.allSettled(
          ASSETS_TO_CACHE.map(url => cache.add(url).catch(e => console.warn('[SW] No se pudo cachear:', url)))
        );
      })
      .then(() => self.skipWaiting())
  );
});

// ── ACTIVATE: limpiar cachés antiguas ──
self.addEventListener('activate', event => {
  console.log('[SW] Activando...');
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(key => key !== CACHE_NAME)
          .map(key => {
            console.log('[SW] Eliminando caché antigua:', key);
            return caches.delete(key);
          })
      )
    ).then(() => self.clients.claim())
  );
});

// ── FETCH: estrategia Network First con fallback a caché ──
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // No interceptar peticiones a Supabase ni APIs externas
  if (
    url.hostname.includes('supabase.co') ||
    url.hostname.includes('anthropic.com') ||
    url.hostname.includes('fonts.googleapis.com') ||
    url.hostname.includes('fonts.gstatic.com') ||
    url.hostname.includes('esm.sh') ||
    url.hostname.includes('cdnjs.cloudflare.com')
  ) {
    return; // Dejar pasar sin interceptar
  }

  // Para archivos locales: Network First, fallback a caché
  event.respondWith(
    fetch(event.request)
      .then(response => {
        // Si la respuesta es válida, guardarla en caché
        if (response && response.status === 200 && response.type === 'basic') {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then(cache => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      })
      .catch(() => {
        // Sin red — intentar desde caché
        return caches.match(event.request).then(cached => {
          if (cached) return cached;
          // Si no hay caché y es una navegación, mostrar login
          if (event.request.mode === 'navigate') {
            return caches.match('/login.html');
          }
        });
      })
  );
});