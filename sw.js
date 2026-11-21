// Bộ nhớ đệm để website mở nhanh và mở được khi mất mạng (chỉ xem).
const CACHE = "gia-pha-v9";
const CORE = ["./", "./index.html", "./manifest.webmanifest", "./icon.svg", "./icon-192.png", "./icon-512.png", "./apple-touch-icon.png"];
self.addEventListener("install", e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)).then(() => self.skipWaiting())); });
self.addEventListener("activate", e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE).map(x => caches.delete(x)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", e => {
  const req = e.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (req.mode === "navigate") {
    e.respondWith(caches.open(CACHE).then(async c => {
      const net = fetch(req, { cache: "no-store" }).then(res => { if (res.ok) c.put("./index.html", res.clone()); return res; });
      try { const res = await Promise.race([net, new Promise(r => setTimeout(() => r(null), 3000))]); if (res) return res; } catch (_) {}
      return (await c.match("./index.html")) || net;
    }));
    return;
  }
  if (url.origin === location.origin || /(gstatic|googleapis)\.com$/.test(url.hostname) || url.hostname === "cdn.jsdelivr.net") {
    e.respondWith(caches.match(req).then(hit => {
      const net = fetch(req).then(res => { if (res.ok || res.type === "opaque") caches.open(CACHE).then(c => c.put(req, res.clone())); return res; }).catch(() => hit);
      return hit || net;
    }));
  }
});
