# Site URLs: layout, base path and indexing

Covers the shape of every URL the site publishes, the rule that the site builds under any base path, and which pages search engines may index. Where the pages come from is not here.

## URL layout

- Every version lives under `/<version>/`. `/latest/` is the default version, and `/` goes to `/latest/` through `public/_redirects` plus meta-refresh stubs for hosts that ignore it. `/reference-archive/` is reserved.
- The Catalogs tab lives at `/catalogs/<name>/<MAJOR.MINOR>/` and `/catalogs/<name>/edge/`, outside every version. `/catalogs/<name>/` and `/catalogs/<name>/<MAJOR>/...` are aliases of the newest minor (of that major), as `_redirects` lines and `noindex` stubs; `edge` has none. Docs pages link catalogs only through the bare tab root or the major alias; the site writes the resolved minor's URL.
- The Enhancements section is at `/enhancements/`, unversioned.
- Site-owned pages are mounted into every version, so their links must resolve in every version.
- A `/latest/` URL in the output must exist as written, because some hosts ignore `_redirects`.

## Base path

The site builds under any base URL, a path included (`https://example.org/docs/`). The reason is hosts that serve it below a path, such as an interim GitHub Pages deploy.

- Every URL the build writes comes from Hugo's URL functions or is relative, CSS `url()` included.
- `params.images` carries no leading slash: with one, Hugo's `absURL` drops the path.
- `OPM_BASE_URL` overrides the `baseURL` of the Hugo config for one build; the config keeps `https://opmodel.dev/`. The value must be absolute and end in `/`.
- The link crawl in `site/scripts/` fails a root-relative URL outside the base path (in HTML attributes, inline styles and CSS) and, under a path, an absolute URL on the base URL's host outside the base URL, in every published text file.
- `task test:site` builds the fixture bundles under a two-segment path (`site/tests/subpath/`).

## Indexing

- Only the host in `params.opm.indexedHost` (`opmodel.dev`) is indexed.
- In the Catalogs tab only the newest minor of each major is indexed and listed in `llms.txt` and the sitemap. Older minors and `edge` are `noindex`. Every segment has its own Pagefind index.
- A build for any other host carries a robots `noindex, nofollow` meta tag on every HTML page (the head-end partial under `site/layouts/_partials/custom/`), and a missing param fails the build.
- Markdown twins, `llms.txt`, `sitemap.xml` and `build-stamp.json` cannot carry the tag. On a host that sends no headers they stay out of search results only because nothing indexable links to them.

## Pitfalls

- A hard-coded `/latest/...` or root-relative link in a layout: use Hugo's URL functions.
- A leading slash in `params.images`.
- Linking a catalog minor from a docs page: link the tab root or the major alias.
- Previewing a path build with `task preview`: preview and the browser checks serve at the root, so `task qa` and `task shots` always build the default base URL.

## Check before you finish

- [ ] `task build OPM_BASE_URL=https://example.org/docs/` passes the link crawl.
- [ ] `task test:site` passes, including the subpath case.
- [ ] A new redirect has a `noindex` stub where the layout rules above require one.
