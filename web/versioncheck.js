// Controllo versione: a ogni deploy il workflow scrive version.json con l'hash del commit.
// Se la versione online è diversa da quella con cui questo browser ha caricato il gioco,
// elimina service worker e cache e ricarica. I salvataggi (IndexedDB) NON vengono toccati.
(function () {
  var KEY = "space_arcade_version";
  fetch("version.json?t=" + Date.now(), { cache: "no-store" })
    .then(function (r) { return r.json(); })
    .then(function (data) {
      var remote = String(data.v);
      var local = null;
      try { local = localStorage.getItem(KEY); } catch (e) {}
      if (local === remote) { return; }
      try { localStorage.setItem(KEY, remote); } catch (e) { return; } // niente storage: evita cicli di ricarica
      var jobs = [];
      if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
        jobs.push(navigator.serviceWorker.getRegistrations().then(function (regs) {
          return Promise.all(regs.map(function (g) { return g.unregister(); }));
        }));
      }
      if (window.caches && caches.keys) {
        jobs.push(caches.keys().then(function (keys) {
          return Promise.all(keys.map(function (k) { return caches.delete(k); }));
        }));
      }
      Promise.all(jobs).then(function () {
        var u = new URL(location.href);
        u.searchParams.set("v", remote);
        location.replace(u.toString());
      });
    })
    .catch(function () { /* offline o file assente: si continua normalmente */ });
})();
