// Animates a theme switch with the View Transitions API. Hextra's toggle and
// its OS-theme listener both call the global setTheme from js/head/theme.js;
// this wraps it, so no theme file is forked. A switch the pointer started
// grows the new theme as a circle from the pointer; one from the keyboard or
// the OS cross-fades. Nothing animates when the theme does not change (the
// toggle's own call at load), under prefers-reduced-motion, or in a browser
// without document.startViewTransition: there setTheme runs as before.
(function () {
  var setThemeNow = window.setTheme;
  if (typeof setThemeNow !== "function" || !document.startViewTransition) return;

  var root = document.documentElement;
  var reduce = window.matchMedia("(prefers-reduced-motion: reduce)");
  var dark = window.matchMedia("(prefers-color-scheme: dark)");
  var point = null;

  document.addEventListener("pointerdown", function (e) { point = { x: e.clientX, y: e.clientY }; }, true);
  document.addEventListener("keydown", function () { point = null; }, true);

  function resolved(theme) {
    if (theme === "light" || theme === "dark") return theme;
    return dark.matches ? "dark" : "light";
  }

  // The toggle's icon is chosen by data-theme on each button's parent.
  function icons() {
    return Array.prototype.map.call(document.querySelectorAll(".hextra-theme-toggle"), function (b) { return b.parentElement; });
  }

  function put(parents, values) {
    parents.forEach(function (p, i) {
      if (values[i] === undefined) delete p.dataset.theme;
      else p.dataset.theme = values[i];
    });
  }

  window.setTheme = function (theme) {
    var from = root.classList.contains("dark") ? "dark" : "light";
    if (reduce.matches || resolved(theme) === from) return setThemeNow(theme);

    var at = point;
    point = null;
    var cls = at ? "opm-theme-reveal" : "opm-theme-fade";
    root.classList.add(cls);

    // Hextra's switchTheme flips the toggle's icon right after setTheme
    // returns, before the browser takes the old snapshot, so the old theme
    // would show the new icon. A microtask runs after that flip and before
    // the snapshot: put the old icon back there, and set the new one when
    // the page updates.
    var parents = icons();
    var was = parents.map(function (p) { return p.dataset.theme; });
    var now = was;
    queueMicrotask(function () {
      now = parents.map(function (p) { return p.dataset.theme; });
      put(parents, was);
    });

    var t = document.startViewTransition(function () {
      setThemeNow(theme);
      put(parents, now);
    });
    t.finished.finally(function () { root.classList.remove(cls); });
    if (!at) return;

    // ready rejects when the transition is skipped, as when a second switch
    // starts before the first ends; the theme still changes, so it is ignored.
    var r = Math.hypot(Math.max(at.x, innerWidth - at.x), Math.max(at.y, innerHeight - at.y));
    t.ready.then(function () {
      root.animate(
        { clipPath: ["circle(0px at " + at.x + "px " + at.y + "px)", "circle(" + r + "px at " + at.x + "px " + at.y + "px)"] },
        { duration: 500, easing: "cubic-bezier(.4, 0, .2, 1)", pseudoElement: "::view-transition-new(root)" }
      );
    }).catch(function () {});
  };
})();
