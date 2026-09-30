## Context

`origin/main` (eaa275e, 2026-09-30) holds A, B, C, D, E and M. `task build` writes `site/public/` for `baseURL = 'https://opmodel.dev/'` (`site/config/_default/hugo.toml`, the only setting; `build-all.sh` passes no `--baseURL`). E's `.github/workflows/site.yml` has the jobs `build` and `browser`, per-job concurrency, and the `site-public` artifact. Nothing is hosted.

GitHub Pages is already on for the repo: `build_type: workflow`, `html_url` `https://open-platform-model.github.io/opmodel.dev/`, and the environment `github-pages` with a branch policy for `main` (read-only, 2026-09-30). A project site lives under a path, `/opmodel.dev/`. GitHub serves it with fixed headers. It has no redirect rules, and it uses only the root `404.html`.

A read-only audit built the real site with only the `baseURL` changed to the Pages URL (scratchpad `research-subpath.md`). Hugo writes almost every URL through `RelPermalink`, `relURL` or `Permalink`, so almost everything already follows the base path. Four things do not:
1. `assets/css/opm/base.css` loads the fonts from `url("/fonts/...")`, which Hugo does not rewrite, so the fonts silently fall back to system fonts.
2. `build-all.sh` writes the root `index.html` refresh to `/latest/`.
3. `static/site.webmanifest` has `"start_url": "/"`.
4. `check-pages.sh links` looks a root-relative URL up in `public/` as written, so every prefixed URL failed the build.

The plan review found a fifth, which the audit missed because it checked `og:image` only:

5. `hugo.toml` sets `images = ['/images/og-default.png']`. Hextra's `head.html` calls Hugo's embedded `twitter_cards.html` and `schema.html`, and both build the image URL through `_partials/_funcs/get-page-images.html` with `absURL $img` (Hugo v0.167.0). With a leading slash, `absURL` keeps only the base URL's host, so under a path every page's `twitter:image` and `itemprop="image"` name `https://open-platform-model.github.io/images/og-default.png`, outside the project site (404). `og:image` is right only because Hextra's own `opengraph.html` strips the slash first.

Neither the audit nor the crawl could see two kinds of fault:
- a root-relative URL without the prefix resolves in `public/` and passes the crawl, but on the host it names another site;
- an absolute URL on the build's own host but outside the base URL (fault 5) is skipped by the crawl, and check 11 reads no `<meta>`.

The spike measures both (finding 1), and decision 3 turns both into build failures.

Files under `site/` this change touches: `scripts/run-in-image.sh`, `scripts/build-all.sh`, `scripts/check-pages.sh`, `scripts/test-site.sh`, `assets/css/opm/base.css`, `assets/js/opm-pagefind.js`, `static/site.webmanifest`, `layouts/_partials/custom/head-end.html` (a Hextra hook, not an override copy), `config/_default/hugo.toml` (two params), `tests/subpath/env` (new), `tests/checks/link-crawl/` (extended), `tests/checks/base-path-escape/`, `tests/checks/base-url-form/` and `tests/checks/supply-base-url/` (new). The build gains one environment input, `OPM_BASE_URL`. It gains no mount, source repo, vendored file or pinned tool. The theme override set and `overrides.sha256` do not change. The version set does not change. The published URLs of the production build do not change; the Pages URL is new.

## Goals / Non-Goals

**Goals:**
- The site builds correctly under any base URL, a path included. The default stays `https://opmodel.dev/`, and the production output does not change beyond three equivalent relative forms and one explicit Pagefind option.
- `task test:site` proves it on every run, so the base path cannot regress.
- Every push, nightly run and manual run of `main` publishes the checked build to `https://open-platform-model.github.io/opmodel.dev/`, marked `noindex`. Nothing else can deploy.
- The Cloudflare change (F) can retire the deploy in one small section, and the base-path support stays behind it.

**Non-Goals:**
- Cloudflare, a custom domain, DNS (F and the go-live change).
- Browser QA of the subpath build. The QA server serves `site/public/` at the root; a mount prefix is a follow-up if it is ever needed.
- A pull-request preview deploy.
- `TODO.md` item 3.2, which F rewrites.

## Decisions

### 1. One input, `OPM_BASE_URL`; unset means today's build

```text
Taskfile.yml       build cmd: OPM_BASE_URL={{shellQuote (.OPM_BASE_URL | default "")}} sh site/scripts/run-in-image.sh build
                   (not in the &hugo-env anchor; decision 7 says why)
run-in-image.sh    build mode only: + --env OPM_BASE_URL=<value> when it is non-empty (as OPM_VERSIONS is)
build-all.sh       resolves the base URL once, validates it, passes it to Hugo, exports the parts
```

```sh
# build-all.sh (shape; POSIX sh)
BASE_URL=${OPM_BASE_URL:-$(sed -n "s/^baseURL = '\(.*\)'\$/\1/p" config/_default/hugo.toml)}
case "$BASE_URL" in
  http://?*/|https://?*/) ;;
  *) fail "build-all: the base URL must be an absolute http(s) URL ending in / (OPM_BASE_URL, else hugo.toml's baseURL): '$BASE_URL'" ;;
esac
BASE_PATH=/${BASE_URL#*://*/}; BASE_PATH=${BASE_PATH%/}   # "" at a host root, /opm/docs under a path
export BASE_URL BASE_PATH
hugo build ... ${OPM_BASE_URL:+--baseURL "$OPM_BASE_URL"}
```

- **Unset is byte-for-byte today's invocation.** `--baseURL` is passed only when `OPM_BASE_URL` is non-empty, and `hugo.toml` keeps `baseURL = 'https://opmodel.dev/'` for good. So "back to `https://opmodel.dev/`" (F) needs no edit. Empty and unset mean the same everywhere, because the Taskfile's inline assignment always sets the variable, empty when no value is given.
- **Three ways in, one path.** The template var `.OPM_BASE_URL` resolves, in order, from a call var (`qa` and `shots` pass `''`), a CLI var (`task build OPM_BASE_URL=<url>`) and the exported environment (CI's Pages step). The inline assignment hands that value to `run-in-image.sh`.
- **Forwarded in `build` mode only, not in `run()`.** `run()` is shared: `test` (fixture builds), `lint`, `serve` and the two-version build of `task versions:test` (`check-two-versions.sh` calls `run()` directly) all use it. A caller's exported `OPM_BASE_URL` must reach none of them. `serve.sh` keeps its own `--baseURL http://127.0.0.1:<port>/`.
- **Validated.** A base URL without a trailing slash makes Hugo join paths wrongly, silently. The build fails first, with a fixture (`tests/checks/base-url-form`).
- **Alternatives.** Hugo's own `HUGO_BASEURL` never reaches the container (`run()` passes a fixed env list), and a name of our own documents itself in `run-in-image.sh`'s header. Editing `hugo.toml` for the Pages build would leave two configs to keep in step.

### 2. The five root assumptions, fixed where the output is written

```text
site/assets/css/opm/base.css    src: url("../fonts/Geist-Variable.woff2") format("woff2");
                                src: url("../fonts/GeistMono-Variable.woff2") format("woff2");
site/static/site.webmanifest    "start_url": "./"
site/scripts/build-all.sh       index.html: <meta http-equiv="refresh" content="0; url=${BASE_PATH}/latest/"> ... <a href="${BASE_PATH}/latest/">
                                _redirects: unchanged (/ /latest/ 302, /latest/* /<default>/:splat 302)
site/config/_default/hugo.toml  images = ['images/og-default.png']   (no leading slash; comment says why)
site/assets/js/opm-pagefind.js  pagefind.options({ baseUrl: '{{ .Site.Home.RelPermalink }}', excerptLength: 20 })
```

- **Fonts: relative, not templated.** The OPM stylesheet publishes at `css/opm.min.<hash>.css` (`head-end.html`), so `../fonts/` resolves at every base. The alternative, `resources.ExecuteAsTemplate` over `base.css` with `relURL`, turns a static stylesheet into a template for two URLs. The preload in `head-end.html` already uses `relURL` and stays.
- **Manifest: `./`** resolves against the manifest's own URL, `/site.webmanifest` or `/<path>/site.webmanifest`. The icons are already relative.
- **Root `index.html`: prefixed, not relative.** `${BASE_PATH}/latest/` is `/latest/` by default, so the production file does not change. The crawl checks it, because it is root-relative. A relative `latest/` would also work, but the crawl skips relative links, and it would change the production file.
- **`_redirects` stays** for Cloudflare. Pages ignores it and serves it as a harmless static file. Check 12 still requires it.
- **Share image: relative, not root-absolute.** `absURL "images/og-default.png"` joins onto the whole base URL, so `twitter:image` and `itemprop="image"` keep the path. Hextra's `opengraph.html` takes its no-slash branch (`absURL` directly) and gives the same URL as before. At `https://opmodel.dev/` every one of the three URLs stays `https://opmodel.dev/images/og-default.png`. `resources.GetMatch` finds nothing either way: `assets/` has no `images/`. The `hugo.toml` comment says why there is no slash, because the slash is the natural thing to add back. Nothing else reads `params.images` (`task brand:og` writes the file and reads only the title and description).
- **Pagefind base URL: explicit.** Pagefind 1.5.2 builds result URLs from `baseUrl`, which defaults to the path before `pagefind/` in the bundle's import URL (`getDefaultBaseUrl`). That gives `/opm/docs/v1.0/` today, but only by inference, and `search.py` runs at the root, where a change in that inference would not show. Passing `.Site.Home.RelPermalink` (`/v1.0/` by default, the same as the derived value) makes the URL a build output that `subpath/search` asserts.
- **Already correct under a path** (audit, confirmed in the probe output): the `/latest/` stubs (`head-end.html`, from `RelPermalink`), the 404 page's links, the version switch, favicons, stylesheets and scripts, the Pagefind bundle path (`opm-pagefind.js`, from `.Site.Home.RelPermalink`), the Markdown outputs' links (`Site.Home.Permalink`), the "Copy page" `data-url`, canonical, `og:url` and `og:image` (Hextra strips the leading slash itself), `sitemap.xml`, `robots.txt` and `llms.txt`. The regression test asserts the ones a reader or a crawler meets (decision 6). The crawl's absolute-URL rule (decision 3) catches any other URL on the host that leaves the base path, meta tags included.

### 3. The link crawl and the nav order know the base path

```text
check-pages.sh post, links (Pagefind bundles excluded, as today):
  root-relative URLs:
    in every published HTML file: href, src, data-url (as today), plus check 11's other
      attributes: every srcset entry, poster, data and xlink:href; and every url() in a
      style attribute or a <style> block
    in every published CSS file: every url() (new)
    data: URLs, fragments and protocol-relative //host URLs are skipped
  for each root-relative URL u:
    p = u without #fragment and ?query
    BASE_PATH set:  p is BASE_PATH or starts with BASE_PATH/  ->  p = p without BASE_PATH
                    anything else                              ->  LINK FAIL "  <u> (in <file>): outside the base path <BASE_PATH>"
    p names a file, or a directory holding index.html, under public/  ->  ok; else LINK FAIL (as today)
    /latest/... is looked up as written: it must be a stub page (no _redirects mapping any more)
  for each relative url() in CSS: resolved against the CSS file's directory under public/;
    one that climbs above public/ fails; the resolved site-root path is looked up and printed
  absolute URLs, only when BASE_PATH is set:
    in every published *.html, *.xml, *.txt, *.md, *.json and *.webmanifest file:
    an http://, https:// or protocol-relative URL whose host is BASE_URL's host and that does
    not start with BASE_URL (a //host URL gets BASE_URL's scheme first)
      ->  LINK FAIL "  <u> (in <file>): outside the base URL <BASE_URL>"
    (compared as a literal prefix with awk index(), never as a regex built from the URL)
  one line per distinct URL (the first file that holds it), as today
check-pages.sh post, nav:
  nav-order.txt holds the sidebar hrefs with BASE_PATH stripped, so the file is the same for every base
```

- **The escape rules are the point.** Under a path, `/v1.0/docs/` exists in `public/` but names another site on the host. So does `https://<host>/images/og-default.png` (fault 5). Without the rules, the crawl would pass the broken links it exists to catch. With `BASE_PATH` empty, neither rule applies, and the default build's crawl result is as today.
- **CSS and inline styles join the crawl** because that is where the font bug hid from an HTML-only crawl. Relative `url()` values are resolved too, so the new `../fonts/` paths are still checked. This extends check 4's crawl; it is not a new check. Its failing cases extend `tests/checks/link-crawl`.
- **The attribute set is check 11's.** Check 11 already reads `src`, `srcset`, `href`, `poster`, `data` and `xlink:href` for hosts; the crawl reads the same set for paths, so a site-owned `<img srcset="/images/...">` (the `supply-srcset` fixture has one) is checked for both. A plain `<a href>` stays in the crawl, as today.
- **`/latest/` must exist as written.** GitHub Pages ignores `_redirects`; there, `/latest/...` works only through the stubs, which exist only for HTML pages (`head-end.html`). Mapping through `_redirects` would pass a link to `/latest/.../index.md` or `/latest/pagefind/` that 404s on Pages. The rule holds on both hosts, so it applies always. Today only the root `index.html` links into `/latest/`, and `latest/index.html` exists (check 12 requires it).
- **What the crawl does not read: JavaScript.** A root-path string built in JS is invisible to it. The spike scans the published JS once (finding 1), and `subpath/js` (decision 6) guards the fixture build's JS, which is the same site and theme JS as the real build.
- **The web manifest** holds `start_url` and `icons[].src`, which no crawl reads. `subpath/assets` asserts that no value in it starts with `/`.
- **`nav-order.txt` stays base-independent.** `a11y.py` maps its URLs onto `public/`, and the regression test compares the subpath build's file with the default build's.

### 4. Check 11 allows the build's own base URL

The literal `https://opmodel.dev/` (three places in `build-all.sh`, and the OK message) becomes `$BASE_URL`, compared as a literal prefix:

```text
build-all.sh check 11, tags:  awk -v B="$BASE_URL" ... if (u ~ /^(https?:)?\/\// && index(u, B) != 1) print ...
build-all.sh check 11, CSS:   the grep -oiE extraction stays; the filter becomes awk index() on the extracted URL,
                              not grep -viE with the URL inside a regex
```

- **Literal, not a regex.** Put into a regex as it is, the `.` in a URL matches any character, so `https://opmodelXdev/` or `https://pagesXexample/opm/docs/` would pass. Today's hand-escaped literal has no such hole; a variable would.
- By default nothing changes. Under a path, a tag loading from `https://opmodel.dev/` fails, which is right: it would load from the parked apex. A tag loading from a sibling project on the same host (`https://pages.example/opm/x.js` under `/opm/docs/`) fails check 11 too, but the crawl's absolute-URL rule (decision 3) fails it first, because the crawl runs before check 11. A tag loading from the build's own URL passes.
- `tests/checks/supply-lookalike` still fails as before. `tests/checks/supply-base-url` (new, decision 6) runs check 11 under a path.

### 5. `noindex` on every host but the production one

```toml
# site/config/_default/hugo.toml, [params.opm]
    # The only host whose pages may be indexed. A build for any other base URL
    # host carries a robots noindex tag (layouts/_partials/custom/head-end.html).
    indexedHost = 'opmodel.dev'
```

```go-html-template
{{- /* site/layouts/_partials/custom/head-end.html. Only the production host is
       indexed. Another host (the interim GitHub Pages site, a local server)
       sends no robots header, and a robots.txt under a path is ignored, so the
       page asks for itself. Hextra's head has already written "index, follow";
       search engines apply the most restrictive rule. */ -}}
{{- with site.Params.opm.indexedHost -}}
  {{- if ne (urls.Parse site.BaseURL).Host . -}}
<meta name="robots" content="noindex, nofollow">
  {{- end -}}
{{- else -}}
  {{- errorf "params.opm.indexedHost is not set in hugo.toml" -}}
{{- end -}}
```

- **Supervisor default: `noindex` while the site is on the interim host.** The owner said the documentation is not finished. The owner can overrule it; the change is this block.
- **Why a meta tag.** Pages sends no custom headers, so there is no `X-Robots-Tag`. Crawlers read `robots.txt` only at the host root, `open-platform-model.github.io/robots.txt`, which this repo does not control. The page must stay crawlable for the tag to be seen, and it is.
- **HTML only, accepted.** The build also publishes a Markdown twin of every page and section (`[outputs]` page and section are `['html', 'markdown']`), `llms.txt`, `sitemap.xml` and `build-stamp.json`. None can carry a meta tag, and Pages sends no header, so nothing marks them `noindex`. They stay out of search results only because nothing indexable links to them: the "Copy page" `data-url` is not a link, and every HTML page is `nofollow`. No build setting fixes this on Pages. The README subsection and the `AGENTS.md` indexing rule say so.
- **Why keyed on the host.** Nobody has to toggle it. F's Cloudflare build keeps `https://opmodel.dev/`, the `workers.dev` preview included, so F gets no tag and its `X-Robots-Tag` header does the preview's job. The rule stays correct after F, and F leaves it in place. A missing param fails the build rather than silently de-indexing production.
- **Two robots tags.** A hook cannot remove the `index, follow` tag that Hextra's `head.html` writes first. Google and Bing apply the most restrictive of several robots rules. The alternatives were rejected:
  - A generated `cascade` that sets `.Params.noindex` (Hextra's own switch) gives one tag, but it adds a generated config file keyed on the base URL and merged with the site-owned cascades.
  - A non-`production` Hugo environment makes Hextra write `noindex`, but it switches the config directory (`config/production/` holds the generated mounts) and Hextra's CSS pipeline.
- **`nofollow`** matches Hextra's non-production value. The `/latest/` stubs and the root `index.html` already carry `noindex`.
- **Tested both ways** (decision 6): no tag on a default build's version pages, and the tag on every version page of the subpath build.

### 6. The regression test: the fixture workspace under a two-segment path

`site/tests/subpath/env` holds `OPM_BASE_URL=https://pages.example/opm/docs/`. `.example` is a reserved domain, and two path segments prove the prefix handling in general, not only for one segment. The URL is neutral, so the test outlives the interim host.

A new block in `test-site.sh`, after `fixture`, builds the fixture workspace with that env file. Its assertions (quote-tolerant, as the existing ones are):

| Case | Asserts |
|---|---|
| `subpath` | the build is green: the crawl with both escape rules, CSS and inline styles, check 11 with the base URL, the page set and every other check pass under `/opm/docs/` |
| `subpath/root` | the root `index.html` refreshes to `/opm/docs/latest/`, and its link says the same; `_redirects` still reads `/ /latest/ 302` |
| `subpath/latest` | `latest/index.html` refreshes to `/opm/docs/v1.0/`; `latest/docs/start/quickstart/index.html` to `/opm/docs/v1.0/docs/start/quickstart/` |
| `subpath/404` | the root `404.html` "Go to the docs" link is `/opm/docs/v1.0/docs/` |
| `subpath/search` | the published Pagefind adapter script holds `/opm/docs/v1.0/pagefind/` (the bundle) and `baseUrl` with `/opm/docs/v1.0/` (the result URLs) |
| `subpath/assets` | no published CSS matches `url\(["']?/` (quote-tolerant: the minifier keeps quotes a URL needs); `site.webmanifest` has `"start_url": "./"`, and no value in it starts with `/` (no match for `":[[:space:]]*"/`) |
| `subpath/js` | no published `*.js` outside `*/pagefind/*` holds a quoted or backtick string literal (`'`, `"` or a backtick, then `/`) that starts with `/v` and a digit, `/latest`, `/docs`, `/pagefind`, `/css`, `/js`, `/fonts` or `/images` |
| `subpath/absolute` | on the quickstart page: canonical and `og:url` are `https://pages.example/opm/docs/v1.0/docs/start/quickstart/`; `og:image`, `twitter:image` and `itemprop` `image` are all `https://pages.example/opm/docs/images/og-default.png`. `llms.txt` says `Site: https://pages.example/opm/docs/` |
| `subpath/markdown` | `quickstart.md` links to `https://pages.example/opm/docs/v1.0/docs/concepts/fixture-concept/#why` |
| `subpath/noindex` | every version page (`index.html` under `public/v1.0/`, Pagefind excluded) carries the robots `noindex` tag |
| `subpath/nav` | its `nav-order.txt` equals the `fixture` block's |

The `fixture` block gains two assertions: its quickstart page carries no robots `noindex` tag, and its `twitter:image` is `https://opmodel.dev/images/og-default.png` (the share-image param still gives the production URL).

Failing fixtures (each build must fail, and print its lines). Each uses URLs that no other fixture file holds, because the crawl prints one line per distinct URL:
- `tests/checks/link-crawl` (extended): a site-owned stylesheet `site/assets/css/opm/zz-dead-url.css` with `url("/fonts/missing-from-css.woff2")` and `url("../images/missing-from-css.png")`. Expect `+   /fonts/missing-from-css.woff2 (in css/opm.min.` and `+   /images/missing-from-css.png (in css/opm.min.`: the relative one is printed resolved, as a site-root path. The existing HTML lines stay as they are.
- `tests/checks/base-path-escape` (new): `env` with `OPM_BASE_URL=https://pages.example/opm/docs/`, and a site-owned page whose raw HTML links to `/v1.0/docs/start/` and to `https://pages.example/opm/elsewhere/`. Expect `LINK FAIL`, `outside the base path /opm/docs` and `https://pages.example/opm/elsewhere/ (in`, with `outside the base URL https://pages.example/opm/docs/`.
- `tests/checks/base-url-form` (new): `env` with `OPM_BASE_URL=https://pages.example/opm/docs` (no slash). Expect the base URL message, and `- == hugo build`.
- `tests/checks/supply-base-url` (new): `env` with `OPM_BASE_URL=https://pages.example/opm/docs/`, and a site-owned page with `<script src="https://opmodel.dev/x.js">` (the production host, wrong under a path) and `<script src="https://pagesXexample/opm/docs/x.js">` (passes if the base URL were a regex). Neither host is the base host, so the crawl lets both through. Expect `SUPPLY FAIL`, `src=https://opmodel.dev/x.js` and `src=https://pagesXexample/opm/docs/x.js`.

`test-site.sh` unsets `OPM_BASE_URL` at its top, as it sets `OPM_REQUIRE_DATES=0`. A case sets it only through its own `env` file. The subpath build costs one more fixture build per `test:site`.

### 7. QA and preview stay on the root build

- `task qa` and `task shots` call `task: build` with `vars: {OPM_BASE_URL: ''}`, and the `build` command assigns `OPM_BASE_URL` inline from the template var (decision 1).
- **Why inline, not an `env:` entry.** A call var wins in templates, not in `env:` maps. Task 3.52.0 (the CI pin and the local binary) leaves an `env:` entry alone when the OS already has that variable, unless `TASK_X_ENV_PRECEDENCE` is set. So with `OPM_BASE_URL` exported, an `&hugo-env` entry `'{{.OPM_BASE_URL}}'` still hands the exported value to the build under `task qa`, and so does a task-level `env: {OPM_BASE_URL: ''}` on `qa`. A shell assignment in the command itself does override the OS value. A scratch Taskfile on 2026-09-30 showed all of this. With `OPM_BASE_URL=https://pages.example/opm/docs/` exported:
  - the call-var form printed the exported value in the env and `[]` in the template;
  - the `env:` form printed the exported value;
  - `OPM_BASE_URL={{shellQuote (.OPM_BASE_URL | default "")}} sh ...` printed `[]` under `qa`, the exported value for a plain `task build`, and the CLI value for `task build OPM_BASE_URL=...`;
  - a call var also beat a CLI var (`task qa OPM_BASE_URL=...` printed `[]`).
  A bare `{{shellQuote .OPM_BASE_URL}}` errors when the variable is unset, hence the `default ""`. `versions:test` already overrides `OPM_VERSIONS` inline for the same reason.
- The section 2 gate proves it on the real tasks: `task qa` runs with `OPM_BASE_URL` exported, and the root `index.html` it built must refresh to `/latest/`.
- `task preview` serves `site/public/` at the root; `AGENTS.md` says to preview a default build. No guard: a subpath build previewed at the root shows broken links at once.
- A browser check of the subpath build is left out (Non-Goals). Search on the live Pages site gets one manual check after the first deploy (README).

### 8. The Pages build: a second pass at the end of the `build` job

```yaml
env:
  # A page without a git date fails the build. Dates are computed on the host
  # by versions:prepare (materialise.sh), where git can read every source; the
  # build image never runs git. CI can require them because every source is a
  # full clone (fetch-depth: 0), so every page has history. Locally a page that
  # is not committed yet has no date, so a local build leaves this off.
  OPM_REQUIRE_DATES: '1'
  # The interim GitHub Pages site, until the Cloudflare deploy replaces it
  # (README.md, "GitHub Pages (interim)"). Never name it OPM_BASE_URL here:
  # every task build of the run, task qa's included, would build for this path.
  PAGES_BASE_URL: https://open-platform-model.github.io/opmodel.dev/

jobs:
  build:
    steps:
      # ... unchanged, through the site-public and build-stamp uploads ...
      - name: Build for GitHub Pages (interim)
        # The same sources, dates and checks, for the project site's path. It
        # runs on pull requests too, so a change that breaks the path fails there.
        env:
          OPM_BASE_URL: ${{ env.PAGES_BASE_URL }}
        run: |
          task build
          echo "GitHub Pages build for $OPM_BASE_URL: $(find site/public -type f | wc -l) files" >> "$GITHUB_STEP_SUMMARY"
      - name: Upload the GitHub Pages artifact
        # Every event, so a pull request proves the tar and upload of the real
        # Pages tree. Only pages-deploy is limited to main. It expires in a day.
        uses: actions/upload-pages-artifact@fc324d3547104276b827a68afc52ff2a11cc49c9 # v5.0.0
        with:
          path: opmodel.dev/site/public
```

- **Not in the deploy job.** That job holds `pages: write` and `id-token: write`. Building there would run seven checkouts, two images and the whole build under a token that can publish. The deploy job runs only the Pages actions and checks nothing out.
- **Not a parallel job.** A second job would check out the six source repos again and could see a later `main` of one. This pass reuses the same checkouts and `site/.versions/`, so both builds show the same sources and dates.
- **Not the `site-public` artifact.** Every root-relative and absolute URL is baked in for `/`, and rewriting it with `sed` is unsafe (Pagefind, hashed names, sitemaps, `llms.txt`).
- **After the uploads, into `site/public/`.** Every step that reads the production tree (summary, `site-public`, `build-stamp`) has run by then, and F's jobs download `site-public`, which holds the default build. A separate output directory would need `run-in-image.sh` argument passing, a `.gitignore` line and a `clean` entry for nothing. The clean-tree step before it covers the same generated paths this pass writes.
- **On pull requests too, the upload included.** The fixture test covers the layouts; this pass covers the real pages, and the upload proves the tar and the artifact of the real Pages tree before the merge. Only `pages-deploy` is limited to `main`. `configure-pages` and `deploy-pages` cannot run before the merge (the environment allows only `main`), so the merge push is their first run, and a failure there is fixed forward. The artifact keeps the action's default retention of one day, so the pull request artifacts cost nothing that lasts.
- **A literal URL, as `PAGES_BASE_URL`.** It is not derived from `github.repository`: a fork cannot aim it anywhere, and one line retires it.
- **Cost.** One more Hugo and Pagefind pass against the job's 30-minute timeout; the spike records the time (finding 4).

### 9. The `pages-deploy` job

```yaml
jobs:
  pages-deploy:
    name: Deploy to GitHub Pages (interim)
    needs: [build, browser]
    # github.repository is set on every event; the schedule payload has no
    # repository object, so github.event.repository.fork would compare null.
    if: >-
      github.repository == 'open-platform-model/opmodel.dev' &&
      github.ref == 'refs/heads/main' &&
      github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    permissions:               # this job only; the workflow keeps contents: read
      pages: write             # create the Pages deployment
      id-token: write          # deploy-pages proves the run's identity to Pages
    environment:
      name: github-pages       # branch policy: main only (owner setting)
      url: ${{ steps.deployment.outputs.page_url }}
    concurrency:               # never cancel a deploy; a newer run waits its turn
      group: pages-deploy
      cancel-in-progress: false
    steps:
      - id: pages
        uses: actions/configure-pages@45bfe0192ca1faeb007ade9deae92b16b8254a0d # v6.0.0
      - name: The build targets this Pages site
        env:
          SITE_URL: ${{ steps.pages.outputs.base_url }}
        run: |   # base_url has no trailing slash
          if [ "${SITE_URL%/}/" != "$PAGES_BASE_URL" ]; then
            echo "::error::GitHub Pages serves $SITE_URL, but the site was built for $PAGES_BASE_URL (README.md, GitHub Pages (interim))"
            exit 1
          fi
      - id: deployment
        uses: actions/deploy-pages@368f82528645a54fb793d4d04e342629a3f51346 # v5.0.1
      - name: Summary
        env:
          PAGE_URL: ${{ steps.deployment.outputs.page_url }}
        run: |
          { echo '### GitHub Pages (interim)'; echo; echo "Deployed $GITHUB_SHA to $PAGE_URL"; } >> "$GITHUB_STEP_SUMMARY"
```

- **Triggers.** No change to `on:`. The `if` narrows the workflow's `push`, `schedule` and `workflow_dispatch` to `main`, and the environment's branch policy refuses any other ref a second time. The nightly run matters as much as for F: it is how a source-repo merge reaches the site.
- **`needs: browser`**, as F does. A build that fails its accessibility or search smoke test is not published. The browser job tests the default build, not the Pages pass; the crawl and the fixture test cover the path. Accepted for an interim.
- **`configure-pages` first.** It fails with its own message when Pages is off ("verify that the repository has Pages enabled"). Its `base_url` is then compared with `PAGES_BASE_URL`: a custom domain set on the Pages site, or a renamed repo, would move the site to a URL the build did not target, and the deploy stops before it publishes. It never enables Pages: that needs a token other than `GITHUB_TOKEN`, and the setting is the owner's.
- **Permissions.** Only this job has them. It has no checkout and no `defaults.run`; its `run:` steps read nothing from the repo, and step outputs reach the shell only through `env`.
- **Concurrency.** Its own group, `pages-deploy`, never cancels a running deploy, and GitHub keeps only the newest pending run. The name differs from F's `site-deploy`, so both can exist while F lands.
- **Pins,** resolved 2026-09-30 (`gh api`; each tag is a lightweight tag on a commit). Task 3.1 checks for newer releases.

| Action | Version | Commit |
|---|---|---|
| `actions/configure-pages` | v6.0.0 | `45bfe0192ca1faeb007ade9deae92b16b8254a0d` |
| `actions/upload-pages-artifact` | v5.0.0 | `fc324d3547104276b827a68afc52ff2a11cc49c9` |
| `actions/deploy-pages` | v5.0.1 | `368f82528645a54fb793d4d04e342629a3f51346` |

- **The artifact.** `upload-pages-artifact` tars `site/public/`. It skips dotfiles (there are none; `include-hidden-files` stays at its default, false) and follows symlinks (`tar --dereference`; Hugo writes none). The limit is 1 GB, and the site is a few MB. The Actions source runs no Jekyll, so `_redirects` and underscore names publish as they are, without `.nojekyll`.
- **A failed deploy is safe.** The previous deployment keeps serving.

### 10. The README runbook, under `## CI`

`### GitHub Pages (interim)` goes at the end of `## CI`, not under a `## Deploy` heading: F adds `## Deploy`, and F's task 2.1 adds exactly one. The `## CI` table gains a row for the Pages build (`OPM_BASE_URL=<url> task build`). The subsection covers:

1. **What and when.** The URL, the triggers, `needs: [build, browser]`, `noindex` on the HTML pages. The site is public and linkable, and it is interim.
2. **How this host differs** from the Cloudflare plan: meta-refresh pages instead of 302s for `/` and `/latest/` (so `/latest/` works only for HTML pages, through the stubs), only the root `404.html`, no headers, `robots.txt` ignored under a path. So only the HTML pages carry `noindex`: the Markdown twins, `llms.txt`, `sitemap.xml` and `build-stamp.json` cannot, and stay unindexed only because nothing links to them (decision 5).
3. **The owner's setting.** Settings > Pages > Build and deployment > Source: GitHub Actions (repo admin). Or `gh api -X POST repos/open-platform-model/opmodel.dev/pages -f build_type=workflow`. On a 422, add `-f 'source[branch]=main' -f 'source[path]=/'`; if the site exists with another source, use `gh api -X PUT repos/open-platform-model/opmodel.dev/pages -f build_type=workflow`. Check with `gh api repos/open-platform-model/opmodel.dev/pages --jq .build_type`, which prints `workflow`. The environment `github-pages` must allow only `main`: `gh api repos/open-platform-model/opmodel.dev/environments/github-pages/deployment-branch-policies --jq '[.branch_policies[].name]'` prints `["main"]`. The owner enables Pages before the first deploy; a deploy before that fails at `configure-pages`, and a manual run (`gh workflow run Site --ref main`) repeats it.
4. **Checking a deploy** (literal commands):
   - `curl -sS https://open-platform-model.github.io/opmodel.dev/ | grep -o 'url=[^"]*'` prints `url=/opmodel.dev/latest/`.
   - `curl -sS https://open-platform-model.github.io/opmodel.dev/latest/ | grep -o 'url=[^"]*'` prints `url=/opmodel.dev/v1.0/`.
   - `curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/v1.0/docs/` prints `200`.
   - `curl -sS https://open-platform-model.github.io/opmodel.dev/v1.0/docs/ | grep -c 'noindex, nofollow'` prints `1` (the value holds a space, so the minifier keeps it quoted and whole).
   - `curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/v1.0/no-such-page/` prints `404`.
   - `curl -sS https://open-platform-model.github.io/opmodel.dev/v1.0/no-such-page/ | grep -o 'href=[^ >]*>Go to the docs'` prints the link to `/opmodel.dev/v1.0/docs/` (the site's own 404 page).
   - `curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/fonts/Geist-Variable.woff2` prints `200`.
   - `curl -sS https://open-platform-model.github.io/opmodel.dev/build-stamp.json` names the SHAs in the run's summary.
   - One search in a browser on `/opmodel.dev/v1.0/docs/`, because Pagefind runs only in a browser.
5. **Retirement.** The Cloudflare change removes the job, the two `build` steps, `PAGES_BASE_URL` and this subsection. After its first deploy is verified, the owner turns Pages off (`gh api -X DELETE repos/open-platform-model/opmodel.dev/pages`, or Settings > Pages) and deletes the environment (`gh api -X DELETE repos/open-platform-model/opmodel.dev/environments/github-pages`). Then `curl -sS -o /dev/null -w '%{http_code}\n' https://open-platform-model.github.io/opmodel.dev/` prints `404`. These are repo settings, the owner's actions.

### 11. What F retires and what stays

- **F removes:** the `pages-deploy` job, the two `build` steps of decision 8, `PAGES_BASE_URL`, and the README subsection and table row of decision 10.
- **F keeps:**
  - `OPM_BASE_URL` and the base-path handling, a tested capability that costs nothing when unset. Removing it would reopen the five faults for the next host under a path.
  - The subpath test.
  - The indexed-host rule, which stays correct: `opmodel.dev` is indexed, and the `workers.dev` preview is built for `https://opmodel.dev/` and gets F's header.
- **F deploys** the `site-public` artifact, built without `OPM_BASE_URL`, so it deploys the `https://opmodel.dev/` build.
- **Nothing to un-edit.** The `AGENTS.md` lines written here name no host but the production one, so F need not touch `AGENTS.md`. `hugo.toml`'s `baseURL` never changes.

## Research & Decisions

### How the site behaves under a path (planning audit, 2026-09-30)
**Context**: The Pages URL is a project site under `/opmodel.dev/`; the build had never run under a path.
**Explored**: A read-only audit of `origin/main` eaa275e, plus a real build in a throwaway detached worktree with only `hugo.toml`'s `baseURL` changed, through `run-in-image.sh build` in Docker with no network (scratchpad `research-subpath.md`; the worktree was removed). Hugo 0.167.0 built, Pagefind indexed 57 pages, the stubs and root files were written, and the build then failed only at the link crawl. Output samples: `/latest/index.html` pointed at `/opmodel.dev/v1.0/`, the CSS held `url(/fonts/...)`, `og:image` and the `robots.txt` Sitemap line named the github.io URL.
**Decision**: Fix the four faults at their source (decision 2), teach the crawl the base path (decision 3), and assert the rest (decision 6).
**Rationale**: Everything else already goes through Hugo's URL functions. The crawl failure listed every prefixed URL, so an unprefixed one would have passed unseen. Spike finding 1 measures that before the fixes are trusted.

### The share-image URLs (plan review, 2026-09-30)
**Context**: The audit checked `og:image` only.
**Explored**: Hugo v0.167.0's embedded `_partials/_funcs/get-page-images.html`, `twitter_cards.html` and `schema.html` (read from the tag on GitHub), Hextra v0.13.0's `head.html` and `opengraph.html` (vendored), and Hugo's `urls.AbsURL` docs (with `baseURL` `https://example.org/docs/`, `absURL "/style.css"` gives `https://example.org/style.css`). A default build already writes `twitter:image` and `itemprop="image"`, so these partials run.
**Decision**: Fault 5: drop the leading slash from `params.images` (decision 2), assert all three image URLs (decision 6), and fail any absolute URL on the base host outside the base URL (decision 3).
**Rationale**: The slash is the whole bug, and removing it changes no default URL. The absolute-URL rule closes the class, not only this instance: it reads meta tags and the non-HTML outputs, where the crawl never looked.

### GitHub Pages behaviour and limits (planning, 2026-09-30)
**Context**: The host decides what the build must provide.
**Explored**: GitHub docs (custom workflows, publishing source, custom 404, limits, schedule events); the READMEs and `action.yml` of `actions/configure-pages`, `upload-pages-artifact` and `deploy-pages`; a read-only curl probe of a live project site (rust-lang.github.io/mdBook); `gh api` for the repo's Pages site and environments (scratchpad `research-pages.md`, `research-ci.md`).
**Decision**: Meta-refresh pages and the root `404.html` carry the routing. The meta tag carries `noindex`. The deploy uses `upload-pages-artifact` and `deploy-pages` from a job with `pages: write` and `id-token: write` only, and `configure-pages` as an early check.
**Rationale**:
- A project site redirects a directory without a slash (301). It serves `index.html` for a directory, the root `404.html` (status 404) for a missing path at any depth, and fixed headers only.
- It has no `_redirects`, `_headers` or server rules. `robots.txt` counts only at the host root.
- Limits: 1 GB per site, 100 GB a month soft bandwidth, a 10-minute deployment timeout. Actions workflows are exempt from the builds-per-hour limit.
- Pages was switched on by the owner on 2026-09-30 (`build_type: workflow`), and `github-pages` allows only `main`.

### Spike findings (section 1, filled in at apply time)
**Context**: Five facts need a real build or run.
**Explored**: tasks 1.2 to 1.4 (finding 2 in 1.2, finding 3 in 1.3 and 2.8, findings 1 and 4 in 1.4 and 2.7), and 3.1 (finding 5).
**Decision**: Record here:
- Finding 1: in the real subpath build:
  - every root-relative URL not under `/opmodel.dev/` in HTML (`href`, `src`, `data-url`, `srcset` entries, `poster`, `data`, `xlink:href`, `url()` in styles), and every `url(/` or `url("/` or `url('/` in CSS;
  - every absolute URL on `open-platform-model.github.io` (`https://`, `http://` or `//`) that does not start with `https://open-platform-model.github.io/opmodel.dev/`, in `*.html` (meta `content` included), `*.xml`, `*.txt`, `*.md`, `*.json` and `*.webmanifest`;
  - every quoted or backtick root-path string literal (`/v<digit>`, `/latest`, `/docs`, `/pagefind`, `/css`, `/js`, `/fonts`, `/images`) in published JS outside `*/pagefind/*`;
  - any value in `site.webmanifest` that starts with `/`.
  Any hit outside the five known faults is a scope question for the supervisor (task 1.4).
- Finding 2: whether two default builds of the same tree are identical, and which files differ if not (the noise the output diffs ignore).
- Finding 3: the default build after section 1 is identical to the baseline; after section 2 it differs only as decision 2 says.
- Finding 4: the Pages pass's time and file count for the real site.
- Finding 5: the action pins at apply time.

Recorded at apply time (2026-09-30, sources at the six `site-src` worktrees: opm 94c9289, core 748dfc7, catalog_opm 3cb3344, cli 025e1b6, library c99403c, opm-operator 546d649):
- **Finding 2 (task 1.2).** Two default builds of the unchanged tree are not byte-identical. They differ in exactly two places, both outside this change's reach: `v1.0/llms.txt` line 76 (`Generated on <UTC time>`), and the Pagefind index, whose content-hashed names differ from run to run (`v1.0/pagefind/index/en_<hash>.pf_index`, `v1.0/pagefind/pagefind.en_<hash>.pf_meta`, and the hash inside `v1.0/pagefind/pagefind-entry.json`; `page_count` stays 57). Every other file of the 275 is identical. This is the noise every later output diff ignores.
- **Finding 3, first half (task 1.3).** With `OPM_BASE_URL` unset, the section 1 build's `site/public` differs from the baseline `public-a` only in finding 2's noise.
- **Finding 1 (task 1.4).** The real site built for `https://open-platform-model.github.io/opmodel.dev/` ran green through Hugo, the root files and Pagefind, and failed at `check-pages (post)` with `LINK FAIL` (130 URLs, every one prefixed with `/opmodel.dev/`), as expected. The scans of `site/public` found the five known faults and nothing else:
  - HTML root-relative values outside `/opmodel.dev/` (`href`, `src`, `data-url`, `srcset` entries, `poster`, `data`, `xlink:href`): one, `href=/latest/` in the root `index.html` (with its `url=/latest/` refresh). No `url()` in a `style` attribute or `<style>` block is root-relative.
  - CSS: the two font URLs in `css/opm.min.<hash>.css`, `url(/fonts/Geist-Variable.woff2` and `url(/fonts/GeistMono-Variable.woff2`.
  - Absolute URLs on `open-platform-model.github.io` outside the base URL: one URL, `https://open-platform-model.github.io/images/og-default.png`, 120 times: `twitter:image` and `itemprop="image"` in each of the 60 HTML pages that carry them (58 version pages and the two `404.html`). `og:url`, canonical, `og:image`, `sitemap.xml`, `robots.txt` and `llms.txt` all stay under the base URL.
  - JS outside `*/pagefind/*`: no root-path string literal. The Pagefind adapter publishes at the root as `v1.0.en.pagefind.min.<hash>.js`, and its bundle path is the literal `"/opmodel.dev/v1.0/pagefind/"`.
  - `site.webmanifest`: `"start_url": "/"` only; the icons are relative.
  - On `v1.0/docs/index.html`: the only robots meta is Hextra's `index, follow`; `og:url` and canonical are `https://open-platform-model.github.io/opmodel.dev/v1.0/docs/`; `og:image` is `https://open-platform-model.github.io/opmodel.dev/images/og-default.png`; `twitter:image` and `itemprop` `image` are `https://open-platform-model.github.io/images/og-default.png` (fault 5). `llms.txt` says `Site: https://open-platform-model.github.io/opmodel.dev/`.
- **Finding 4, first pass (task 1.4).** The whole `task build` to the crawl failure took about 1 s of wall clock on the host, with 275 files in `site/public` (the same count as the default build).

**Rationale**: Findings 1 and 3 hold decisions 1 and 2 as planned: the input changes nothing when unset, and the subpath build's only faults are the five that decision 2 fixes, so no fix outside the planned files and no override copy is needed. Finding 2 adds no decision; the output diffs of tasks 1.3 and 2.8 filter its two noise sources.

## Interface (orchestration.md section 6)

- **Adds:**
  - the environment input `OPM_BASE_URL` (the `build` task only; default unset, meaning `hugo.toml`'s `baseURL`);
  - `BASE_URL` and `BASE_PATH`, which `build-all.sh` exports to its checks;
  - the Hugo param `params.opm.indexedHost`;
  - the fixture case `site/tests/checks/supply-base-url/`, and `base-path-escape` and `base-url-form` beside it;
  - `site/tests/subpath/`;
  - the `site.yml` job `pages-deploy`, the workflow env `PAGES_BASE_URL` and the artifact `github-pages`.
- **Relies on:**
  - `build-all.sh`'s `--public` and `--check`, and check 12;
  - the `/latest/` stubs that `head-end.html` writes, which the crawl now requires as written (it no longer reads `_redirects`);
  - E's `build` and `browser` jobs, per-job concurrency and the `site-public` artifact;
  - `task qa` building `site/public/`;
  - the `github-pages` environment (owner).
- **Changes,** each the same as today for the default base:
  - `nav-order.txt` holds site-root paths;
  - check 11 allows the build's base URL, compared as a literal prefix;
  - the crawl also reads check 11's attribute set, `url()` in HTML and CSS, and (under a path) absolute URLs on the base host in every text output;
  - a `/latest/` URL must exist as written (a stub), on every build;
  - `params.images` holds `images/og-default.png`, with no leading slash.
- Section 6 of the brief does not list `OPM_BASE_URL`, and still says that the root `index.html` refreshes to `/latest/` and that check 11 allows only `https://opmodel.dev/`. Updating it is the supervisor's planning edit, not this change's.

## Risks / Trade-offs

- [A root URL without the prefix hides in a theme file] -> Finding 1 lists them before any fix, and the crawl's escape rule fails the build on one from then on. A fix that needs a new override copy is scope growth: stop and report.
- [Search is broken on the live site] -> The bundle path and the explicit `baseUrl` are both asserted (`subpath/search`), so a Pagefind bump cannot change the result URLs silently. The README's first-deploy check includes one search in a browser.
- [An exported `OPM_BASE_URL` leaks into QA, the fixture tests or the two-version test] -> `qa` and `shots` pass `''` as a call var, and the `build` command's inline assignment carries it past the exported value (a Task `env:` entry would not; decision 7). `test-site.sh` unsets it, and `run-in-image.sh` forwards it only in `build` mode.
- [An absolute URL on the host escapes the base path] -> The crawl's absolute-URL rule, under a path, over every text output (decision 3). It is how fault 5 would have been caught.
- [Someone sets `OPM_BASE_URL` at workflow or job level] -> The workflow uses `PAGES_BASE_URL`, and its comment says why.
- [Pages is turned off, or a custom domain is set on it] -> `configure-pages` fails, or the URL check stops the deploy. The live version keeps serving.
- [Two robots tags on the interim site] -> The most restrictive rule applies. The test asserts the `noindex` tag.
- [The interim site is public while 0018:OQ15 is open] -> `noindex` on the HTML pages, and nothing links to it. The owner decided to publish; the merge waits for the owner's explicit acceptance, recorded in the pull request body (proposal).
- [The Markdown twins and `llms.txt` carry no `noindex`] -> Accepted: no build setting can mark them on Pages. Nothing indexable links to them.
- [The production output changes] -> Three relative forms (fonts, manifest), the stylesheet's fingerprint, and the Pagefind adapter's `baseUrl` option (the value Pagefind already derived) with its fingerprint. The share-image URLs do not change. Finding 3 proves nothing else moved.
- [The first real deploy is the merge push] -> The pull request proves the Pages build and the artifact upload; `configure-pages` and `deploy-pages` first run on `main`. A failure is fixed forward by a new small change (proposal, Depends on).
- [The nightly run republishes identical content] -> Harmless. The 60-day schedule lapse (README "CI") stops deploys too.
- [The interim URL ends up in bookmarks and 404s at retirement] -> Accepted: the README calls it interim.
- [The `build` job gets slower] -> Finding 4 measures it. If it hurts, the Pages pass and its upload can skip pull requests with a one-line `if` each, at the cost of an unproven upload before the merge.
- [Canonical, sitemap and share-image URLs name github.io] -> Correct for that host; the HTML pages are `noindex`.
- [Docker and the host] (traps 18, 20, 22, 23) -> Every build runs through the Taskfile's Docker tasks. The spike's scans read `site/public/` on the host with `grep` and `find` only.

## Durable decisions

- **Base path** -> `AGENTS.md`, "Durable decisions":
  - the site builds under any base URL, a path included;
  - every URL the build writes comes from Hugo's URL functions or is relative, CSS `url()` included;
  - `OPM_BASE_URL` overrides `hugo.toml`'s `baseURL` for one build;
  - the link crawl fails a root-relative URL outside the base path (HTML attributes, inline styles and CSS), and, under a path, an absolute URL on the base host outside the base URL, in every text output;
  - a `/latest/` URL in the output must exist as written, because some hosts ignore `_redirects`;
  - `task test:site` builds the fixture under a two-segment path.
- **Indexing** -> `AGENTS.md`, "Durable decisions": only `params.opm.indexedHost` is indexed; a build for any other host carries a robots `noindex` tag on its HTML pages. The Markdown twins, `llms.txt`, `sitemap.xml` and `build-stamp.json` cannot carry it, so on a host without headers they stay unindexed only by being unlinked.
- **`OPM_BASE_URL` and QA** -> `AGENTS.md`, "Environment Notes"; `README.md`, "Tasks" (one line): QA, shots and preview serve the root, so QA always builds the default base.
- **`site/tests/subpath/`** -> the layout trees in `AGENTS.md` ("Repository Layout") and `README.md` ("Directory Structure").
- **The interim deploy and its runbook** -> `README.md`, `## CI`, "GitHub Pages (interim)", until F removes them.
- **Spike findings** stay with the change.

## Open Questions

- Whether search works on the live Pages site. The owner's one manual search after the first deploy answers it; the approach does not change either way.
