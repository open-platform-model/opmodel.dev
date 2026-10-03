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

  // EXPERIMENT: ?themefx=reveal|fade|none picks the effect, and is remembered
  // for this browser. Remove before shipping, keeping the chosen effect.
  var fx = "reveal";
  try {
    var asked = new URLSearchParams(location.search).get("themefx");
    if (asked) localStorage.setItem("opm-themefx", asked);
    fx = localStorage.getItem("opm-themefx") || fx;
  } catch (e) {}

  document.addEventListener("pointerdown", function (e) { point = { x: e.clientX, y: e.clientY }; }, true);
  document.addEventListener("keydown", function () { point = null; }, true);

  function resolved(theme) {
    if (theme === "light" || theme === "dark") return theme;
    return dark.matches ? "dark" : "light";
  }

  window.setTheme = function (theme) {
    var from = root.classList.contains("dark") ? "dark" : "light";
    if (fx === "none" || reduce.matches || resolved(theme) === from) return setThemeNow(theme);

    var at = fx === "reveal" ? point : null;
    point = null;
    var cls = at ? "opm-theme-reveal" : "opm-theme-fade";
    root.classList.add(cls);
    var t = document.startViewTransition(function () { setThemeNow(theme); });
    t.finished.finally(function () { root.classList.remove(cls); });
    if (!at) return;

    var r = Math.hypot(Math.max(at.x, innerWidth - at.x), Math.max(at.y, innerHeight - at.y));
    t.ready.then(function () {
      root.animate(
        { clipPath: ["circle(0px at " + at.x + "px " + at.y + "px)", "circle(" + r + "px at " + at.x + "px " + at.y + "px)"] },
        { duration: 500, easing: "cubic-bezier(.4, 0, .2, 1)", pseudoElement: "::view-transition-new(root)" }
      );
    });
  };
})();
