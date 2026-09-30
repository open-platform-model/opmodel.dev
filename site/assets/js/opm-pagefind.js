// Pagefind as the data plane of Hextra's search command palette.
// Implements the window.hextraSearch contract that Hextra v0.13.0's
// search-dialog.js reads:
//   preload(): Promise<void>
//   search(query): Promise<[{id, route, title, breadcrumbs[], matches: [{id, route, title, content}]}]>
// so the palette renders Pagefind results with Hextra's own markup and
// styles. The bundle is this version's (/<version>/pagefind/), so results
// never leave the version being read. Loaded on first open of the palette.
(function () {
  const bundlePath = '{{ .Site.Home.RelPermalink }}pagefind/';
  const maxPages = 10;
  const maxSubResults = 3;
  let loading = null;

  function preload() {
    if (!loading) {
      loading = import(bundlePath + 'pagefind.js')
        .then(async (pagefind) => {
          await pagefind.options({ excerptLength: 20 });
          pagefind.init();
          return pagefind;
        })
        .catch((err) => { loading = null; throw err; });
    }
    return loading;
  }

  // Pagefind excerpts carry <mark>; the palette highlights the query itself.
  function text(html) {
    const el = document.createElement('div');
    el.innerHTML = html || '';
    return (el.textContent || '').trim();
  }

  async function search(query) {
    const pagefind = await preload();
    const response = await pagefind.search(query);
    const pages = await Promise.all(response.results.slice(0, maxPages).map((r) => r.data()));
    let n = 0;
    return pages.map((page) => {
      const title = (page.meta && page.meta.title) || page.url;
      const crumbs = page.meta && page.meta.crumbs ? page.meta.crumbs.split(' / ').filter(Boolean) : [];
      const subs = (page.sub_results || []).slice(0, maxSubResults);
      const matches = (subs.length ? subs : [{ url: page.url, title, excerpt: page.excerpt }]).map((sub) => ({
        id: `hextra-search-opt-${n++}`,
        route: sub.url,
        title: sub.title || title,
        content: text(sub.excerpt),
      }));
      return { id: `hextra-search-opt-${n++}`, route: page.url, title, breadcrumbs: crumbs, matches };
    });
  }

  window.hextraSearch = { preload, search };
})();
