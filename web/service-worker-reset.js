// Service worker "di pulizia": sostituisce quello generato da Godot, che teneva in cache
// index.html e i file del gioco anche dopo un nuovo deploy.
// Appena il browser lo scarica: prende il controllo subito, cancella tutte le cache,
// si disinstalla e ricarica le pagine aperte. I salvataggi (IndexedDB) non vengono toccati.
self.addEventListener("install", function () {
  self.skipWaiting();
});

self.addEventListener("activate", function (event) {
  event.waitUntil((async function () {
    var keys = await caches.keys();
    await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    await self.registration.unregister();
    var wins = await self.clients.matchAll({ type: "window" });
    wins.forEach(function (c) { c.navigate(c.url); });
  })());
});
