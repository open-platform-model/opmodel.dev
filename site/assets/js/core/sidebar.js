// OPM override of Hextra's assets/js/core/sidebar.js (v0.13.0, pinned in
// site/overrides.sha256); scripts/core.html concatenates js/core/*.js, so
// this file replaces the theme's. One change: scrollToActiveItem scrolls
// only when the active item lies outside the sidebar's visible box. Upstream
// always scrolls it near the top, so the phone menu (the same sidebar, moved
// in by a transform) opened scrolled past the section root even when the
// item fitted the first screen. Out of view, it keeps upstream's placement,
// one row below the top, so the item's h2 list stays visible under it.
// Delete this copy when upstream fixes the scroll.
document.addEventListener("DOMContentLoaded", function () {
  scrollToActiveItem();
  enableCollapsibles();
});

function enableCollapsibles() {
  const buttons = document.querySelectorAll(".hextra-sidebar-collapsible-button");
  buttons.forEach(function (button) {
    button.addEventListener("click", function (e) {
      e.preventDefault();
      const list = button.closest('li');
      if (list) {
        list.classList.toggle("open");
        button.setAttribute('aria-expanded', list.classList.contains('open') ? 'true' : 'false');
      }
    });
  });
}

function scrollToActiveItem() {
  const sidebarScrollbar = document.querySelector("aside.hextra-sidebar-container > .hextra-scrollbar");
  const activeItems = document.querySelectorAll(".hextra-sidebar-active-item");
  const visibleActiveItem = Array.from(activeItems).find(function (activeItem) {
    return activeItem.getBoundingClientRect().height > 0;
  });

  if (!sidebarScrollbar || !visibleActiveItem) {
    return;
  }

  // The drawer's closed-state transform moves both boxes alike, so the
  // comparison holds while the phone menu is closed.
  const box = sidebarScrollbar.getBoundingClientRect();
  const item = visibleActiveItem.getBoundingClientRect();
  if (item.top >= box.top && item.bottom <= box.bottom) {
    return;
  }

  const yOffset = visibleActiveItem.clientHeight;
  const yDistance = item.top - box.top;
  sidebarScrollbar.scrollTo({
    behavior: "instant",
    top: sidebarScrollbar.scrollTop + yDistance - yOffset
  });
}
