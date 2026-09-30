## Why

The site builds and is tested in CI, but no reader can reach it: `opmodel.dev` is still parked, and the Cloudflare deploy (change F, `deploy-site`) waits for more documentation. The owner decided on 2026-09-30: "I think it would be easier to just publish as a github pages site for now. But only for the moment. The real plan is to use cloudflare, but when i have finish more of the documentation."

GitHub Pages needs no account, secret or DNS change. But a project site is served under a path, `https://open-platform-model.github.io/opmodel.dev/`, and the build assumes it is served at a host root in five places: four from a read-only audit with a real subpath build (2026-09-30), and a fifth from the plan review (Hugo's Twitter card and schema.org image URLs). This change makes the build correct under any base path, guards that with a test, and publishes the build to Pages until F replaces it.

## What Changes

- **A base URL input.** `OPM_BASE_URL` overrides `hugo.toml`'s `baseURL` for one build. The Taskfile's `build` command and `run-in-image.sh` pass it to the build only. Unset, the build is exactly today's, for `https://opmodel.dev/`.
- **Output that follows the base path.**
  - The web fonts load through a relative `url()`.
  - The web manifest's `start_url` is relative.
  - The root `index.html` refreshes to `<base path>/latest/`.
  - The default share image in `hugo.toml` (`params.images`) loses its leading slash. With the slash, Hugo's `absURL` drops the base path from `twitter:image` and `itemprop="image"`.
  - The Pagefind adapter passes its version's base URL to Pagefind, instead of relying on Pagefind to work it out from the bundle's URL.
  - Everything else already follows the base URL through Hugo (the audit's list is in design.md).
- **Checks that know the base path.**
  - The link crawl strips the base path before it looks a URL up. It fails a root-relative URL outside the base path, which today would pass on the wrong host.
  - The crawl reads the same attributes as check 11 (`srcset` entries, `poster`, `data`, `xlink:href` besides `href`, `src` and `data-url`), and `url()` in the published CSS and in the pages, where the font bug hid.
  - A `/latest/` URL must exist as written, as a stub page. GitHub Pages ignores `_redirects`, so the crawl no longer maps it through that file.
  - Under a path, an absolute URL on the build's own host that is outside the base URL fails the build. This covers every published text file: HTML (meta tags included), XML, TXT, Markdown, JSON and the web manifest.
  - `nav-order.txt` holds site-root paths for every base.
  - Check 11 (supply chain) allows the build's own base URL instead of the literal `https://opmodel.dev/`, compared as a literal prefix, not as a regex.
- **`noindex` off the production host.** Every HTML page of a build whose base URL host is not `opmodel.dev` carries `<meta name="robots" content="noindex, nofollow">`. GitHub Pages sends no custom headers, and a `robots.txt` under a path is ignored, so a meta tag is the only tool. It covers HTML only: the Markdown twin of every page, `llms.txt`, `sitemap.xml` and `build-stamp.json` cannot carry a meta tag. They stay unindexed only because nothing links to them from an indexable page. No build setting can fix that on Pages, and this change accepts it. The production build is unchanged.
- **QA stays on the root build.** `task qa` and `task shots` build with the default base whatever the caller's environment, because the browser checks serve `site/public/` at the root.
- **A regression test.** `task test:site` builds the fixture workspace under `https://pages.example/opm/docs/`. It proves the build, the link crawl and the key outputs under that path. Four failing fixtures prove the new check rules.
- **The interim deploy.** In `.github/workflows/site.yml`:
  - the `build` job builds the site a second time for the Pages URL and uploads it as the Pages artifact on every run, pull requests included. The artifact expires after one day;
  - a new job `pages-deploy` deploys it for pushes, nightly runs and manual runs of `main`. It uses the official Pages actions, pinned by SHA, and holds `pages: write` and `id-token: write` on that job only;
  - the stale dates comment in the workflow `env` is fixed.
- **A README runbook**, `### GitHub Pages (interim)` under `## CI`: the owner's Pages setting, how to check the first deploy, and how F retires it. The base-path and indexing rules land in `AGENTS.md`, because they outlive the interim deploy.

Nothing here is **BREAKING**. `opmodel.dev` does not change, and no URL, page or version of the production build changes.

Left out: Cloudflare, a custom domain, DNS, and `TODO.md` item 3.2, which F rewrites.

## Owner prerequisite

GitHub Pages must be enabled with source "GitHub Actions" (a repo setting, the owner's). **Done**: read-only on 2026-09-30, `gh api repos/open-platform-model/opmodel.dev/pages` shows `build_type: workflow`, `html_url` `https://open-platform-model.github.io/opmodel.dev/`, and `https_enforced: true`. The `github-pages` environment exists (created 18:03 UTC) with a branch policy that allows only `main`. Task 1.1 checks this again.

If Pages is turned off before the merge, the owner enables it first. The PR could merge before that, but then every deploy fails at its first step until Pages is on. The README gives the UI path and the command (`gh api -X POST repos/open-platform-model/opmodel.dev/pages -f build_type=workflow`).

## For the owner and the supervisor

- **Supervisor default: `noindex` while on the interim host.** The owner said the documentation is not finished. The pages stay public: the repo is public, a Pages site is public, and anyone with the link can read it. `noindex` reaches the HTML pages only; the Markdown twins and `llms.txt` stay out of search engines only because nothing links to them. If the owner wants the interim site indexed, the rule is one template line (design.md decision 5).
- **Every page is published as it is, and the owner must accept that before the merge.** 0018:D8 has every page built and shown from the moment it exists. 0018:OQ15 (what a page must hold before the site is published) is open and marked "Blocking: implementation". This change is the first public publication, so OQ15 bites here, not at go-live. The owner's decision publishes every page, placeholders included, and `noindex` plus no inbound links is the stand-in. The supervisor asks the owner for explicit acceptance before the merge and records the answer in the pull request body. This answers OQ15 for the interim site only; it comes up again at the Cloudflare go-live.
- **The interim host behaves differently from Cloudflare.** It has no 302 redirects: `/` and `/latest/` are meta-refresh pages. It serves only the root `404.html`, and it sends no custom headers. F's smoke checks do not apply to it.

## Before / After

**Before**

```text
Taskfile.yml                         build: sh site/scripts/run-in-image.sh build; no OPM_BASE_URL
site/scripts/run-in-image.sh         build forwards OPM_REQUIRE_DATES, OPM_VERSIONS, OPM_BUILD_REFS
site/scripts/build-all.sh            hugo build   (baseURL only from hugo.toml)
                                     index.html   refresh url=/latest/, <a href="/latest/">
                                     check 11     relative or https://opmodel.dev/ (as a regex)
site/scripts/check-pages.sh          links        root-relative href, src, data-url in HTML, looked up in public/
                                                  as written; /latest/ mapped through _redirects
                                     nav          sidebar hrefs as published
site/assets/css/opm/base.css         url("/fonts/Geist-Variable.woff2"), url("/fonts/GeistMono-Variable.woff2")
site/assets/js/opm-pagefind.js       pagefind.options({ excerptLength: 20 })   (baseUrl derived by Pagefind)
site/static/site.webmanifest         "start_url": "/"
site/config/_default/hugo.toml       baseURL = 'https://opmodel.dev/'; images = ['/images/og-default.png'];
                                     [params.opm] no indexedHost
site/layouts/_partials/custom/head-end.html   no robots rule (Hextra's head: index, follow)
site/tests/                          no build under a base path
.github/workflows/site.yml           env: OPM_REQUIRE_DATES (stale comment)
                                     jobs: build, browser
README.md                            ## CI: no deploy
GitHub                               Pages on (build_type workflow), environment github-pages (main only); nothing deployed
```

**After**

```text
Taskfile.yml                         build: OPM_BASE_URL={{shellQuote (.OPM_BASE_URL | default "")}} sh site/scripts/run-in-image.sh build
                                     qa and shots call build with vars {OPM_BASE_URL: ''}
site/scripts/run-in-image.sh         build: + --env OPM_BASE_URL (only when non-empty)
site/scripts/build-all.sh            OPM_BASE_URL (absolute, ends in /) -> hugo build --baseURL
                                     BASE_URL, BASE_PATH exported (BASE_PATH empty for https://opmodel.dev/)
                                     index.html   refresh url=<BASE_PATH>/latest/ (/latest/ by default, unchanged)
                                     check 11     relative or starts with <BASE_URL> (literal prefix)
site/scripts/check-pages.sh          links        strip BASE_PATH; a root-relative URL outside it fails;
                                                  check 11's attributes, srcset entries, url() in HTML and CSS;
                                                  /latest/ URLs must exist as written (the stubs);
                                                  under a path, an absolute URL on the base host outside
                                                  BASE_URL fails (HTML, XML, TXT, MD, JSON, webmanifest)
                                     nav          nav-order.txt without BASE_PATH
site/assets/css/opm/base.css         url("../fonts/Geist-Variable.woff2"), url("../fonts/GeistMono-Variable.woff2")
site/assets/js/opm-pagefind.js       pagefind.options({ baseUrl: '{{ .Site.Home.RelPermalink }}', excerptLength: 20 })
site/static/site.webmanifest         "start_url": "./"
site/config/_default/hugo.toml       baseURL = 'https://opmodel.dev/' (unchanged); images = ['images/og-default.png'];
                                     [params.opm] indexedHost = 'opmodel.dev'
site/layouts/_partials/custom/head-end.html   <meta name="robots" content="noindex, nofollow">
                                              when the base URL's host is not params.opm.indexedHost
site/tests/subpath/env               OPM_BASE_URL=https://pages.example/opm/docs/
site/tests/checks/                   link-crawl (+ CSS url cases), base-path-escape (new), base-url-form (new),
                                     supply-base-url (new)
site/scripts/test-site.sh            + subpath: the fixture builds green under /opm/docs/ and its outputs follow it
.github/workflows/site.yml
  env:                               OPM_REQUIRE_DATES (comment fixed)
                                     PAGES_BASE_URL: https://open-platform-model.github.io/opmodel.dev/
  jobs:
    build                            unchanged up to the site-public and build-stamp uploads, then:
                                     + Build for GitHub Pages: OPM_BASE_URL=$PAGES_BASE_URL task build (every event)
                                     + upload-pages-artifact opmodel.dev/site/public (every event, 1-day retention)
    browser                          unchanged
    pages-deploy                     if: repo open-platform-model/opmodel.dev, ref main, event not pull_request
                                     needs: build, browser; environment: github-pages
                                     permissions: pages: write, id-token: write (this job only)
                                     concurrency: {group: pages-deploy, cancel-in-progress: false}
                                     configure-pages -> Pages base URL equals PAGES_BASE_URL -> deploy-pages -> summary
README.md                            ## CI: + a CI table row, + ### GitHub Pages (interim)
                                     ## Tasks: + task build OPM_BASE_URL=<url>; Directory Structure: tests/ names the base-path build
AGENTS.md                            Durable decisions: base path, indexed host; Environment Notes: OPM_BASE_URL;
                                     layout tree: tests/subpath/
Published (after the owner's merge)  https://open-platform-model.github.io/opmodel.dev/ -> latest/ -> v1.0/ (noindex)
```

## Impact

- **Touches.**
  - `.github/workflows/site.yml`: the workflow `env` (the dates comment and `PAGES_BASE_URL`), two steps at the end of `build`, and the new job `pages-deploy`. No other line of `build` or `browser` changes.
  - `Taskfile.yml`: the `build` command, and the `qa` and `shots` calls to `build`.
  - `site/scripts/run-in-image.sh`, `build-all.sh`, `check-pages.sh` and `test-site.sh`.
  - `site/assets/css/opm/base.css`, `site/assets/js/opm-pagefind.js`, `site/static/site.webmanifest`, `site/layouts/_partials/custom/head-end.html`, and `site/config/_default/hugo.toml` (`params.images` and `params.opm.indexedHost` only).
  - `site/tests/subpath/env` (new), `site/tests/checks/link-crawl/` (extended), `site/tests/checks/base-path-escape/`, `site/tests/checks/base-url-form/` and `site/tests/checks/supply-base-url/` (new).
  - `README.md`: `## CI`, one line in `## Tasks`, and the `site/tests/` line of "Directory Structure". `AGENTS.md`: "Durable decisions", "Environment Notes" and the `tests/` line of the layout tree.
  - `openspec/changes/publish-interim-github-pages/`: task ticks and the spike findings in `design.md`.
- **Build inputs.** One environment input, `OPM_BASE_URL`, and one Hugo param. No new mount, source repo, vendored file or pinned tool. `head-end.html` is a Hextra hook, not an override copy, so `site/overrides.sha256` does not change. No new output directory: the Pages pass rebuilds `site/public/`.
- **Source repos.** None has to change. The dialect's root-absolute `/docs/...` links keep working: the link hook writes them through `RelPermalink`, which carries the base path.
- **Published URLs and versions.** New: `https://open-platform-model.github.io/opmodel.dev/`, serving the same version set (`v1.0`) as the production build, with `noindex` on its HTML pages. `opmodel.dev` does not change. A default build's output is the same except for these, all valid at the root: the stylesheet's two font URLs and its fingerprint in every page; the Pagefind adapter's one new option (`baseUrl`, the value Pagefind already derived) and its fingerprint in every page; and the manifest's `start_url`. The share-image param gives the same URLs as before. Versioning stays 0021:OQ15, an open question this change does not touch.
- **Depends on.** These are the cells of this change's row in section 2 of `orchestration.md`. The brief has no row for this change yet; the supervisor adds one before launch (and assigns the ID).
  - Repo: opmodel.dev. Kind: OpenSpec `docs-site-change`. Branch: `ci/publish-interim-github-pages`. Wave: 3, before F.
  - Starts when: `origin/main` as of 2026-09-30, with A, B, C, D, E and M merged (true today), and the supervisor's six `site-src` worktrees exist.
  - Owner prerequisite: Pages on with source "GitHub Actions" (done; above). It must still hold when the owner merges.
  - Merges when: the verify is green, the `Site` workflow is green on this change's pull request, the owner has reviewed it, and the owner has explicitly accepted publishing every page as it is, placeholders included, with `noindex` as the stand-in for 0018:OQ15. That acceptance is recorded in the pull request body. **Merge owner: the owner**, because the merge deploys publicly, as F's does.
  - The pull request run proves the Pages build and the `upload-pages-artifact` step (its tar of the real Pages tree). It cannot prove `configure-pages` or `deploy-pages`: the job is skipped on pull requests, and the `github-pages` environment allows only `main`. The merge push runs them for the first time. A failure there is fixed forward by a new small change; until one passes, nothing is published.
  - Pull request title (the squash commit on `main`): `ci: deploy the site to github pages for now`.
  - Gates: `task check`, `task ci`, `task qa` (section 2), `task ci:lint` (section 3).
  - After the merge: the push to `main` runs the first deploy. The supervisor checks it by curl (README "GitHub Pages (interim)") and reports to the owner. A failure is fixed forward by a new small change.
  - F (`deploy-site`) starts after this change is merged (or dropped), on the owner's go for Cloudflare. F retires this deploy. After F's first Cloudflare deploy is verified, the owner turns Pages off.

## Enhancement

None as a delivery claim. This change carries no `enhancement.yaml`, because no change in this set claims delivery (supervisor ruling O7).

Related decisions, for context only:
- 0018:D8 has every page built and shown from the moment it exists. The interim site shows exactly that build.
- 0018:OQ15 (what a page must hold before the site is published) is open and blocks implementation. This change does not settle it. The owner's explicit acceptance before the merge (above) answers it for the interim site only; it comes up again at the Cloudflare go-live.
