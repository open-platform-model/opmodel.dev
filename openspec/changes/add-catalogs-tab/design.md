## Context

The site is one Hugo 0.167 build over Hextra v0.13.0, run in Docker with `--network none`. Docs come from six source repositories per site version; the Enhancements section (`add-enhancements-tab`, archived 2026-10-02) proved an unversioned section built in the same run: a content adapter mounted into the default version only, pages given `url` so they publish outside `/<version>/`, a generated section page, a menu entry written by `gen-mounts.sh` only when the section exists, and explicit exclusions (version label, `/latest/` stubs, `llms.txt`, sitemap, search).

The Catalogs tab follows that pattern with three differences: its source is a set of pulled, signed bundles rather than a git tree; one section holds several version trees (one per opm minor, plus `edge`), each with its own sidebar, search and switcher; and it has aliases. The contracts it consumes are docs-kit's `build-opm-docs-phase-1` `design.md`: the bundle tree and `manifest.json` (C3), tags (C4), the pull config, unpack layout and lock (C7), URLs, links and aliases (C8), the signer (C9), the page dialect (C11) and tool distribution (C12). They are cited as `docs-kit C7` and so on. Supervisor decisions recorded in that design's "Site decisions" (2026-10-02; the owner may override), binding here: there is no `catalog-k8s` bundle (only `catalog-opm`, at `/catalogs/opm/`); the sitemap lists only the newest minor of each major; `edge` gets its own Pagefind index but no alias stubs; version-history data (phase 1b, not this change) will be a data file written by `opm-docs pull` at `<out>/<project>/history.json`. Also decided there: `opm-docs` is pinned in the site's build image (C12, image pattern); the members leave Reference in the build that gains the tab; no redirects are served from the old Reference URLs; `publish.yml` is pinned by tag, so the signer check is the SAN `.../publish.yml@refs/tags/v*` (C9), with no SHA allowlist and no site commit per docs-kit release.

Every file under `site/` this change touches is listed in proposal.md's Impact. The build gains one input (the bundles, by digest) and two pinned tools in the build image (`opm-docs`, `jq`); no upstream pin in `site/overrides.sha256` changes and no new theme file is overridden.

## Goals / Non-Goals

**Goals:**

- The opm catalog's members readable per minor, from 4.4 on, and on `edge`, at stable URLs `/catalogs/opm/<MAJOR.MINOR>/<kind>/<name>/`, built only from bundles whose signature names catalog_opm's `main` and docs-kit's workflow.
- A reader who follows a docs link lands on the newest minor of the major the docs were written for, and can switch minor without losing their place.
- The build stays as strict as it is: every existing check keeps failing on what it fails on today; every new rule brings a failing fixture.
- Sections 1 to 4 are built and tested against fixture bundles, before docs-kit or the real bundles exist.

**Non-Goals:**

- Version history badges and change lists (docs-kit phase 1b): the adapter only keeps the bundle's `data/` reachable.
- A k8s catalog tab, third-party catalogs (`docs-kit DESIGN decision 11`), bundles placed in a site version's `/docs/` (docs-kit phase 2).
- Replacing `lint-sources.sh` with `opm-docs lint`, or site versions from bundle tags (docs-kit phase 3).
- Redirects from the removed Reference URLs (decided against: the site is interim and `noindex`, so nothing depends on them).

## Decisions

### 1. `opm-docs` runs in the build image, and only the pull step has network

`opm-docs` is pinned in `site/Dockerfile` like Hugo and Pagefind, with the SHA-256 committed in the repository (`docs-kit C12`, the build-image pattern; no `.opm-docs-version`, no host install):

```dockerfile
ARG OPM_DOCS_VERSION=0.1.0
ARG OPM_DOCS_SHA256=<the archive's line in v0.1.0's checksums.txt>
RUN wget -q "https://github.com/open-platform-model/docs-kit/releases/download/v${OPM_DOCS_VERSION}/opm-docs_${OPM_DOCS_VERSION}_linux_amd64.tar.gz" -O opm-docs.tgz \
 && echo "${OPM_DOCS_SHA256}  opm-docs.tgz" | sha256sum -c - \
 && tar -xzf opm-docs.tgz opm-docs && ./opm-docs version
# final stage: apk add ... jq=<pinned>; COPY --from=fetch /dl/opm-docs /usr/local/bin/
```

`run-in-image.sh pull` is the one new network step. It mounts only what the pull needs:

```text
docker run --rm --init --user <uid>:<gid> --env HOME=/tmp --env XDG_CACHE_HOME=/cache
  --volume <repo>/site/bundles.cue:/in/bundles.cue:ro
  --volume <repo>/site/.bundles:/out
  --volume <repo>/site/.cache/opm-docs:/cache
  [--volume <OPM_BUNDLES_LOCAL dir>:/local/<project>/<segment>:ro]...      (one per pair)
  [--volume <repo>/site/bundles.frozen.json:/in/frozen.json:ro]
  --entrypoint opm-docs <build image>
  pull --config /in/bundles.cue --out /out --lock /out/lock.json
       [--local <project>@<segment>=/local/<project>/<segment>]... [--frozen /in/frozen.json]
```

Default network (bridge); no source root, no repo-wide write. Anonymous pull: the packages are public, so no token reaches the container. `task bundles:pull` runs it; `task versions:fetch` runs it after the git fetch, so "a local build after a release" stays `task versions:fetch build`. `task build` never pulls.

The release's own `checksums.txt` is read once, by the person bumping the pin, and the hash is committed; the image build checks the download against the committed hash. See Research & Decisions for the host-download alternative the docs-kit orchestration proposed.

### 2. The pull config, and when bundles are required

`site/bundles.cue`, exactly as `docs-kit C7` shows it:

```cue
tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.4"}
}
```

The bundles a build reads, resolved in `site/scripts/sections.sh` (Decision 3):

| Case | Bundles directory | Required | Config check |
|---|---|---|---|
| manifest mode (no `OPM_VERSIONS`), `site/bundles.cue` exists | `site/.bundles/` | yes: no `lock.json` fails, naming `task bundles:pull` | `lock.config` MUST equal `sha256:` of `site/bundles.cue`'s bytes, else fail naming `task bundles:pull` |
| explicit mode (`OPM_VERSIONS` set) | `site/.bundles/` when it holds `lock.json` | no: without it the build has no Catalogs section | as above, when present |
| `OPM_BUNDLES=<dir>` set (tests, an author's saved tree) | that directory (mounted read-only by `run-in-image.sh`) | yes | skipped; the stamp records `"from": "OPM_BUNDLES"` |

`OPM_BUNDLES_LOCAL` takes one or more `<project>@<segment>=<host dir>` pairs (`docs-kit C7`, repeatable); `run-in-image.sh pull` mounts each directory read-only and passes `--local` per pair. A pull whose every tab is local runs with `--network none`. A lock entry with `"local": true` builds, and the stamp shows it. CI never sets `OPM_BUNDLES_LOCAL` or `OPM_BUNDLES` for a published build.

**Recovery.** When a newly published bundle breaks the build (it fails `pull`'s lint or a site check), a committed `site/bundles.frozen.json` (a copy of the last good build's lock, from the `build-manifest` artifact) makes `bundles:pull` pass `--frozen`; deleting it returns to resolution. It plays the role `override` plays for a version, and README names it.

### 3. One sourced script for the unversioned sections

`build-all.sh` (`:56-99`) and `serve.sh` (`:21-56`) carry the same version and `ENH_*` resolution. Section 1 moves it into `site/scripts/sections.sh`, sourced by both, with no change in output; section 2 adds the catalogs block there:

```text
sections.sh  (sourced; needs SITE_DIR)
  sets VERSIONS DEFAULT                                       (unchanged rules)
  sets ENH_TREE ENH_PATHS ENH_REF ENH_SHA ENH_HOW             (unchanged rules)
  sets CAT_DIR  CAT_FROM (manifest | explicit | OPM_BUNDLES)  (Decision 2; empty CAT_DIR = no section)
  exports all of them; a failure names the caller (build-all / serve)
```

### 4. `data/opm/catalogs.json`: one derivation from the lock

`site/scripts/gen-catalogs.sh` (in the image, before `gen-stamp.sh`, which reads its output for the stamp, and before `gen-mounts.sh`) reads `$CAT_DIR/lock.json` and each entry's `manifest.json` with `jq` and writes `data/opm/catalogs.json`; everything else (adapter, switcher, sidebar, redirects, stubs, `noindex`, sitemap, Pagefind, checks) reads only this file:

```json
{
  "lock": "sha256:<hex of lock.json>",
  "catalogs": [
    {
      "project": "catalog-opm", "name": "opm", "root": "/catalogs/opm/",
      "repo": "open-platform-model/catalog_opm",
      "newest": "4.5",
      "majors": {"4": "4.5"},
      "segments": [
        {"segment": "4.5", "label": "4.5", "major": "4", "edge": false, "indexed": true,
         "version": "4.5.0", "revision": 0, "commit": "<40 hex>", "digest": "sha256:...", "local": false,
         "dir": "catalog-opm/4.5"},
        {"segment": "4.4", "label": "4.4", "major": "4", "edge": false, "indexed": false, "...": "..."},
        {"segment": "edge", "label": "main (unreleased)", "major": "", "edge": true, "indexed": false, "...": "..."}
      ]
    }
  ]
}
```

Rules `gen-catalogs.sh` enforces, each failing the build naming project, segment and digest (or `local`): the lock's `schema` is `docs.opmodel.dev/lock/v1`; every entry's `dir` exists and holds `manifest.json`; the manifest's `project`, `version`, `revision` and `source.commit` equal the lock entry's; every entry of one project has the same `root`, which matches `^/catalogs/[a-z0-9]+(-[a-z0-9]+)*/$` and equals the manifest's `placement.root` (`placement.kind: "tab"`); the segment is `<MAJOR>.<MINOR>` of `version` or `edge`. `root` comes from the lock (`docs-kit C7`, every entry carries it); the manifest check is a cross-check. Order: newest first by numeric `MAJOR.MINOR` (`4.10` before `4.9`), `edge` last, sorted by `gen-catalogs.sh` itself; the lock's own order (`docs-kit C7`: minors ascending, then `edge`) is not relied on. `indexed` is true for exactly the newest minor of each major. `name` is the last segment of `root`.

`gen-catalogs.sh` also writes `.gen/catalogs/_index.md` (the `/catalogs/` section page: title "Catalogs", a description, `url: /catalogs/`, `params.llms`, and one line per catalog linking its newest minor), since an adapter cannot add the empty path (as for `/enhancements/`).

### 5. Mounts and the content adapter

`gen-mounts.sh`, when `CAT_DIR` is set:

```toml
[[mounts]]                      # the bundles, as assets; only the files a bundle may hold
  source = "<CAT_DIR>"
  target = "assets/bundles"
  files  = ['*/*/manifest.json', '*/*/content/**', '*/*/data/*.json']   # phase 1b adds '*/history.json'
[[mounts]]                      # the adapter, default version only
  source = "catalogs"
  target = "content/catalogs"
  [mounts.sites.matrix]
    versions = ["<default>"]
[[mounts]]                      # the generated section page, default version only
  source = ".gen/catalogs"
  target = "content/catalogs"
  [mounts.sites.matrix]
    versions = ["<default>"]
```

and the Catalogs menu entry, written with the copy of `_default`'s `[menus]` block as Enhancements is (`gen-mounts.sh:172-176`). `config/_default/hugo.toml` shifts Search, GitHub and Theme to weights 5, 6, 7; Catalogs is 3 and Enhancements 4.

`site/catalogs/_content.gotmpl`, for each catalog, each segment and each `pages[]` entry of its `manifest.json`:

```text
content/<p>.md        -> path  <name>/<segment>/<p'>        (p' = p without .md; x/_index -> x; _index -> "")
                         url   <root><segment>/<p' URL>/    (docs-kit C8)
front matter          -> title, description, weight from the page; the dialect `type` kept as params.docType
                         (the type badge), Hugo type "catalogs" (layouts/catalogs/)
manifest pages[]      -> lastmod (when present); params.catalog = {project, name, segment, version, revision,
                         edge, indexed, commit, repo, source, generated}
segment row           -> sitemap.disable = not indexed; params.llms = indexed
```

The landing needs nothing special: it is the authored contract page followed by the generated `## Catalog members` block (`docs-kit C8`; a generated landing holds only the block), so the members of each minor are one click from its landing, and `#catalog-members` is a stable anchor on every landing.

The adapter fails the build, naming project, segment, digest and page, on: a page `manifest.json` lists that is not mounted, a front-matter key outside the dialect, a missing `title` or `description`, and a Hugo shortcode delimiter (`{{<`, `{{%`) other than an `opm/<figure>` call the dialect allows. `pull` already lints in bundle mode; the adapter's refusals are the site's own guard, and the only one fixture bundles get.

### 6. Layouts, navigation and leakage

- `layouts/catalogs/{list,single}.html`: one-line wrappers of `opm/docs-main.html`, as `layouts/enhancements/` are.
- `sidebar.html`: on a catalog page `$navRoot` is the segment landing (`/catalogs/<name>/<segment>`); sibling segments never show; the `/catalogs/` page has no sidebar tree beyond its list. Mobile menu links as `sidebar.html:50-53`.
- `navbar-link.html`: Catalogs is active on every page under `/catalogs/`.
- `opm/source.html`: a catalog page with `params.catalog.source` links "View source" to `https://github.com/<repo>/blob/<commit>/<source>`; no Edit link (an edit lands on `main` and reaches a released minor only through a docs revision, so "Edit" would mislead). A page without `source` gets no link.
- `banner.html`, `opm/version-switch.html`, `custom/head-end.html` (the `/latest/` stubs, `:40`), `sitemap.xml`'s and `llms.txt`'s filters: the `ne .Section "enhancements"` tests become a test against both unversioned sections, so no site-version label, banner or `/latest/` stub appears on a catalog page.
- No outdated-minor banner: the switcher's button names the minor on every page, and the renderer already writes "unreleased" in an edge member's Catalog row (YAGNI).

### 7. The switcher

`layouts/_partials/opm/catalog-links.html` returns the same list shape as `opm/version-links.html` (`{name, href, exact, isLatest, isCurrent}`), so `opm/catalog-switch.html` reuses `opm/version-switch.html`'s markup and CSS:

```text
rel := page path minus "/catalogs/<name>/<segment>/"
for seg in catalogs.json segments (newest first, edge last):
  p := site.GetPage "/catalogs/<name>/<seg>/<rel>"
  while not p and rel != "": rel := path.Dir rel ; p := GetPage(...)     # nearest existing parent
  p := p or the segment landing
  item {name: seg.label, href: p.RelPermalink, exact: (p is the same rel), isLatest: seg == newest, isCurrent: seg == this}
```

Cached per page with `Store.Set`, as `version-links.html:8,31` does. Older apiVersions (`<name>-<apiVersion>`) are ordinary paths: a reader on `backup-v1alpha1` in 4.4 lands on `backup-v1alpha1` in 4.5 when it exists, else on `traits/`.

### 8. Aliases: `_redirects` lines and stubs

`build-all.sh` appends, per catalog, after the two existing lines:

```text
/catalogs/opm/ /catalogs/opm/4.5/ 302
/catalogs/opm/4/ /catalogs/opm/4.5/ 302
/catalogs/opm/4/* /catalogs/opm/4.5/:splat 302
```

None starts with `/latest/`, so `qa_common.default_version()`'s pattern still matches only the second line. For hosts that ignore `_redirects`, `custom/head-end.html` publishes meta-refresh stubs (`noindex`, canonical to the target, base path included) with the same `resources.FromString ... .Publish` mechanism as the `/latest/` stubs:

```text
public/catalogs/opm/index.html                 -> newest minor's landing   (published by that landing)
public/catalogs/opm/<MAJOR>/index.html         -> newest-of-major landing
public/catalogs/opm/<MAJOR>/<rel>/index.html   -> the same <rel> there     (published by every page of an indexed segment)
```

`edge` gets no stub and no `_redirects` line. `check-pages.sh` learns the stubs (want/have/stray), and the output guards assert the catalog lines are present exactly when the section is.

### 9. Indexing and search

| Page | `<meta robots>` | `llms.txt` | sitemap | Pagefind |
|---|---|---|---|---|
| `/catalogs/` | indexed | yes | yes | none (no minor) |
| newest minor of each major | indexed | yes | yes (`lastmod` from the manifest) | `public/catalogs/opm/<seg>/pagefind/` |
| older minor | `noindex` | no | no | its own |
| `edge` | `noindex` | no | no | its own |
| alias stub | `noindex` | no | no | none |

The non-production-host `noindex, nofollow` (`head-end.html:79-80`) still wins. `build-all.sh` runs `pagefind --site public/catalogs/<name>/<seg>` per `catalogs.json` segment (the loop beside `:145-153`); `scripts/search.html` picks `catalogs/<name>/<seg>/pagefind/` on a catalog page, so a search stays in the minor being read. `sitemap.xml` reads a catalog page's `.Lastmod` instead of the `lastmod.json` key.

### 10. Links

- **On catalog pages**, `layouts/catalogs/_markup/render-link.html` (a section hook, as Enhancements has): a link to the page's own root and segment (`/catalogs/opm/4.4/resources/volumes/`) MUST resolve to a page of the same segment; a link to its own root at another segment or at a major fails (the renderer rewrites own-root links to its segment, `docs-kit C8`); `/docs/...` resolves in the default version; `/enhancements/...` as the global hook does; another catalog's major alias resolves as on docs pages. A miss fails the build naming project, segment and page.
- **On docs pages**, `layouts/_markup/render-link.html` gains a `/catalogs/` branch beside the `/enhancements/` one: `/catalogs/<name>/` (the bare tab root) resolves to the newest minor's landing, and `/catalogs/<name>/<MAJOR>/<rel>` through `catalogs.json` to the newest minor of that major, then through `hugo.Sites` to the page, and the link is written to that page's URL (not the alias: no redirect hop, and the crawl checks a real page). A missing catalog, major or page, or a build without the section, fails the build with a message naming `task bundles:pull`. Fragments are kept.
- **Legacy map (transition, Decision 12).** While the build has the `catalog-opm` tab, the global hook also maps two old targets, resolved like their alias forms: `/docs/reference/catalog-contract/` (with its fragment) as `/catalogs/opm/4/`, and `/docs/reference/catalog-members/` as `/catalogs/opm/4/#catalog-members` (the landing's generated block). `build-all.sh` lists every page still writing one, without failing.

### 11. The page dialect

`site/scripts/lint-sources.sh` accepts, on docs pages, exactly the bare tab root `/catalogs/<name>/` and `/catalogs/<name>/<MAJOR>/(<seg>/)*`, each with an optional `#fragment` (`docs-kit C11`, docs mode), and rejects every other `/catalogs` form with a message naming the major-alias form: a minor (`/catalogs/opm/4.4/`), `edge`, a missing trailing slash, a version prefix, and `/catalogs/` alone (C11 does not list it). `site/tests/lint/link-catalogs/` holds the rejected forms, `lint/clean/` the accepted ones. The byte-identical copy and its SHA-256 in `openspec/changes/deploy-site/orchestration.md` change with it.

`site/tests/lint/` is the source of the dialect conformance fixture set (`docs-kit C11`): docs-kit copies it into `internal/dialect/testdata/conformance/` with the expected `<file>:<line>` output and the source commit, and both linters must pass it until phase 3 retires the shell lint. For the new `/catalogs/` link forms docs-kit is the source: its conformance set carries the fixtures and their expected lines, and this repository re-syncs `site/tests/lint/link-catalogs/` and the `/catalogs/` lines of `lint/clean/` from it at the docs-kit tag `site/Dockerfile` pins (task 5.5), so the shell lint is checked against exactly what the pinned `opm-docs lint` reports. Until that release exists (sections 1 to 4) the fixtures are written from C11 and docs-kit's branch, and section 5 replaces them. Any later rule change lands in docs-kit first, then here with the same fixture, in the PR that bumps the pin; README ("Page dialect") states it.

### 12. Transition: the members leave Reference in the same build that gains the tab

When `catalogs.json` holds `catalog-opm`, `gen-mounts.sh` excludes `reference/catalog-members/**`, `reference/catalog-members.md` (the single page an older catalog_opm tree holds at the same URL; the two-version test's v0.9 has it) and `reference/catalog-contract.md` from catalog_opm's `docs/site` mount in every version (a `files` exclusion, as the placeholder yield does), and the legacy map (Decision 10) resolves the two old link targets sources still write. Without the tab (an explicit build without bundles, most fixtures) nothing changes. `content/docs/reference/_index.md`'s description stops naming catalog members and its body points to the Catalogs tab.

So: from the merge, each member is published once; no source link breaks before cli and catalog_opm follow up; the follow-ups may merge in any order. Once catalog_opm `publish-docs-bundle` section 3 has deleted the pages and no page writes either old target (the listing in Decision 10 is empty on a `main` build), a follow-up deletes the exclusion and the map (`TODO.md`). No redirects are served from the old `/<version>/docs/reference/catalog-*` URLs (supervisor decision, 2026-10-02: the site is interim and `noindex`, so no reader or index depends on them); their `/latest/` stubs go with the pages.

### 13. Build stamp and CI

`gen-stamp.sh` adds, from `catalogs.json` and the lock:

```json
"sections": {
  "enhancements": {"ref": "...", "sha": "...", "how": "..."},
  "catalogs": {"lock": "sha256:...", "from": "manifest",
               "bundles": [{"project": "catalog-opm", "segment": "4.4", "version": "4.4.5", "revision": 1,
                            "digest": "sha256:...", "commit": "<40 hex>", "local": false}]}
}
```

`.github/workflows/site.yml`: a step "Pull the docs bundles" (`task bundles:pull`) before `task ci` in the build job, before `task qa` in the browser job, and before the build in the sources-main job; the job's "Summary" step prints a Catalogs table from `sections.catalogs` (today's jq expects every section to have `ref`/`sha`/`how`, so it must skip `catalogs`); the `build-manifest` artifact gains `site/.bundles/lock.json` (the recovery input of Decision 2). No permission changes: the pull is anonymous.

### 14. Fixtures and checks

`site/tests/fixtures/bundles/` holds three bundle trees, `catalog-opm/{4.4,4.5,edge}/`, each with `manifest.json`, `content/` (a landing ending in the `## Catalog members` block, the three kind indexes, two or three members, one older apiVersion page in 4.4 only, one member in 4.5 only) and `data/catalog.json`, and `lock.json`: exactly what an all-local pull writes over them (`--local catalog-opm@4.4=... --local catalog-opm@4.5=... --local catalog-opm@edge=...`, `docs-kit C7`), so three entries with `"local": true` and `root`, and `config` the digest of `site/tests/fixtures/bundles.cue`. Because a bundle tree and its unpacked copy are the same files, the fixture directory is at once the `--local` input and a ready unpack layout.

The tests use it in two ways (decided: pull in the tests, but only once the tool exists). In sections 2 to 4, before docs-kit is released, `test-site.sh` copies the tree and `bundles.cue` into its site copy (`.bundles/`, `bundles.cue`), so fixture builds read them without `opm-docs`: explicit mode (`OPM_VERSIONS`, as every fixture build) reads `.bundles/` when it holds a lock, with the config check; one positive case, `catalogs/manifest`, and the failing case `cat-without-bundles` build in manifest mode (`CASE_MANIFEST=1` in the case's env, a `.versions/versions.tsv` its setup writes) and assert `(manifest)`; `versions:test` passes `OPM_BUNDLES` to the tree. In section 5, once `opm-docs` is in the image, `test-site.sh` first runs that all-local `opm-docs pull` with `--network none` into `.check/tests/bundles/` and fails unless its output tree and `lock.json` are byte-identical to the fixture. That proves the fixtures are what the real tool writes (manifest validation, unpack guards, bundle-mode lint, the lock's fields), and every later fixture build uses the pulled copy. A fixture edit regenerates `lock.json` the same way. The fixture workspace's `catalog_opm/docs/site/reference/` gains a `catalog-contract.md` and a `catalog-members/` stub (to prove the exclusion and the legacy map), and a fixture docs page links `/catalogs/opm/4/` and a member through the alias.

New check cases under `site/tests/checks/`, each failing on its fixture: `cat-q2` (a page the manifest lists is missing from output), `cat-stray-file`, `cat-link-miss` (a docs link to a member the newest `4` minor lacks), `cat-own-root-other-segment` (a catalog page linking its own root at another segment), `cat-docs-link-without-section`, `cat-without-bundles` (manifest mode, `bundles.cue`, no lock), `cat-lock-mismatch` (lock `config` differs), `cat-manifest-mismatch` (lock and `manifest.json` disagree on version), `cat-front-matter` (an unknown key), `cat-shortcode`, `cat-redirects` (a missing catalog `_redirects` line or stub). Assertions in `test-site.sh` beside `:262-332`: the pages of every segment, the tab present and current, the switcher's targets (same page, parent fallback, landing), indexed vs `noindex` per segment, `llms.txt` and sitemap content, the alias stubs and `_redirects` lines, no edge stub, the excluded Reference pages absent and the legacy links resolved, `nav-order-catalogs-<segment>.txt`. `check-two-versions.sh`: the section is published once, outside both versions, and the tab is in every version.

Browser: `qa_common.catalog_pages()`; `shots.py` adds a catalog landing, a member page with a spec block, a kind index, an edge page and the switcher open, in the six variants; `a11y.py` covers them; `search.py` searches from a 4.4 page and from an edge page and asserts every result stays in that segment.

## Research & Decisions

### Where does `opm-docs` run?

**Context**: the pull needs the network and a pinned tool; the build is offline in Docker.
**Explored**: the docs-kit orchestration's proposal (a repo-root `.opm-docs-version`, `task tools:opm-docs` downloading the release tarball and its `checksums.txt` to `site/.bin/` on the host); the tool in the build image, run with network for the pull only; a separate pull image.
**Decision**: the build image (Decision 1).
**Rationale**: AGENTS.md's rule is that the site's tools live only in the images and the host needs only git and docker. A host download needs a binary per host OS and architecture (docs-kit's release only has to ship `linux_amd64` this way, which `publish.yml` already uses) and `sha256sum` or `shasum` on the host. A checksum read from the same release protects against corruption only; a hash committed here protects against a replaced asset as well, and is the rule every other build download already follows. A separate image would add a third Dockerfile for one binary. The cost is one more network step and an image rebuild on a bump, both visible.

### Parse the lock in shell, Hugo, or with `jq`?

**Context**: the shell side needs the segment list (mounts, Pagefind, `_redirects`); Hugo needs it for every template.
**Explored**: `awk` over JSON; reading `lock.json` only in Hugo and listing `public/catalogs/*/` afterwards; `jq` in the image.
**Decision**: `jq` (pinned apk) writes one `data/opm/catalogs.json`, read by both sides.
**Rationale**: `awk` over JSON is fragile; a Hugo-only derivation leaves the shell guessing from output directories (an alias stub directory looks like a segment). One derived file keeps "newest per major" computed once.

### Mount per segment or the whole unpack directory?

**Context**: docs-kit's orchestration suggests one mount per lock entry.
**Decision**: one `assets/bundles` mount with a `files` filter, and the adapter walks `catalogs.json`.
**Rationale**: the mount list stops depending on the segment count; the filter keeps anything but `manifest.json`, `content/` and `data/*.json` out of the build, including a future history file until the templates need it. All of `content/` is mounted, not `content/**.md`: with the narrower glob, `resources.Match` does not walk nested directories, so the adapter could not see (and refuse) a file the manifest does not list.

### Docs links: write the alias or the resolved minor?

**Decision**: the resolved minor's URL (Decision 10). **Rationale**: no redirect hop on hosts without `_redirects`, the crawl checks a real page, and every build re-resolves, so a new minor moves every link at the next build.

### Close the double-publish window here, or accept it?

**Context**: docs-kit's first orchestration accepted that members exist twice from this merge until catalog_opm retires refgen (now its `publish-docs-bundle` section 3), and ordered cli's link fix strictly between them. This decision was accepted into docs-kit's orchestration on 2026-10-02; the record below is why.
**Explored**: accepting the window; marking the Reference copies `noindex` during it; excluding them from the mount and mapping the two links still written into them.
**Decision**: exclude and map (Decision 12).
**Rationale**: only two link targets are written outside the excluded pages, by three pages (grep over all six `docs/site` trees, 2026-10-02: cli `registry-namespaces.md:19,38`, catalog_opm `kubernetes-resources.md:8,51`, and opm `reference/glossary.md:97`, added later that day; every other hit is a planning comment). `build-all.sh` lists every page still writing one on each build. Two map entries and one mount exclusion remove both the duplicate and the merge-order coupling, and are deleted by one follow-up.

### Pre-unpacked fixtures or `pull --local` in the tests?

**Context**: `docs-kit C7` now takes `--local <project>@<segment>=<dir>`, repeatable, with no network for an all-local pull, so the tests can run the real pull.
**Explored**: pre-unpacked trees only (no tool needed, but never proves the fixtures match the tool); `pull --local` only (gates sections 2 to 4 on docs-kit's release); both.
**Decision**: both, in order (Decision 14): the bulk is built on the tree, and section 5 makes the all-local pull the tests' path and checks it reproduces the tree byte for byte.
**Rationale**: the sections that need no registry also need no tool, and the gated section turns the fixtures into a conformance check of the real `pull`.

### Section 1 is not a spike

The Hugo mechanisms are the ones the Enhancements section proved on 0.167 (adapter `url`, default-only mounts, `.Publish` stubs, a section-scoped Pagefind bundle, section markup hooks). The unverified assumption is the real bundles' shape, which no spike here can check before docs-kit exists; it is held by the fixtures following `docs-kit C3`/`C8` and verified by section 5 against the real bundles.

## Contract gaps (with docs-kit `build-opm-docs-phase-1`, read at `origin/plan/phase-1` 83f08d0)

Accepted into the contract on 2026-10-02 (supervisor): the image pin (C12), the no-double-publish transition (orchestration item 12), repeatable `--local <project>@<segment>=<dir>` with no network for an all-local pull (C7), `root` in every lock entry (C7), the shared conformance fixture set and the bare `/catalogs/<name>/` link (C11), the generated `## Catalog members` block on every landing (C8), no redirects from the old Reference URLs, and `publish.yml` pinned by tag, so the signer is the SAN `.../publish.yml@refs/tags/v*` (C9) with no SHA allowlist and no site commit per docs-kit release. The k8s bundle is gone, and catalog_opm `publish-docs-bundle` section 3 (retire refgen) waits for the k8s catalog's removal, which takes `kubernetes-resources.md` and its two `catalog-members/` links with it. The cli fix now names both links.

Left in the docs-kit text, for docs-kit to tidy (none blocks this change). The tag-pinning decision itself is recorded in C5 at 83f08d0 and relies on docs-kit's tag rulesets being in place before its first release.

- **G1. Lock check placement.** Orchestration item 3 still puts the lock/config check in `versions:prepare` on the host; here it runs in the image (`sections.sh`) for build and serve, so the host needs no `sha256sum` and serve is covered too.
- **G2. Mounts.** Item 5 still says one mount per lock entry at `assets/catalogs/<project>/<segment>`; here it is one filtered `assets/bundles` mount (Research & Decisions).
- **G3. Item 12's first sentence** (Reference loses the pages only when catalog_opm retires refgen) is stale against its next sentence; docs-kit is fixing it. Step 5 already matches at 83f08d0.

## Open questions

- **Release cascade**: whether a docs-kit release opens the `OPM_DOCS_VERSION` bump here (workspace `RELEASING.md`); until then it is bumped by hand, version and SHA-256 in one Dockerfile edit.

## Risks / Trade-offs

- [GHCR or Sigstore is down] -> `bundles:pull` fails and so does every site build; recovery is `site/bundles.frozen.json` plus a warm cache, or waiting. The nightly run makes this visible within a day.
- [A bad bundle reaches `edge` or a minor] -> `pull` refuses it on lint or signature; a page that passes `pull` but fails a site check fails the site build; the frozen lock is the escape hatch.
- [The real renderer's output differs from the fixtures] -> section 5 builds the real bundles with every check before merge; differences are fixed in docs-kit or here, never by loosening a check.
- [Duplicated or broken catalog links during the transition] -> Decision 12.
- [Hugo behaviour reliance] -> the same mechanisms as Enhancements; the two-version test and the fixture suite catch a regression on a Hugo bump.

## Durable decisions

- **The Catalogs tab is an unversioned section at `/catalogs/<name>/<MAJOR.MINOR>/` (and `edge`), built only from signed docs bundles that `opm-docs pull` resolves from the tabs in `site/bundles.cue`; a new minor appears with no site commit; the lock is not committed and the stamp records it.** Lands in README ("The Catalogs section", "Sources") and AGENTS.md ("Site versions" bullet beside the Enhancements one, Repository Layout).
- **`opm-docs` is pinned by version and SHA-256 in `site/Dockerfile` (`docs-kit C12`, image pattern); `task bundles:pull` is the only step besides the image builds and `versions:fetch` that reaches the network, and an all-local pull runs without it; recovery is `site/bundles.frozen.json`. A bundle is accepted only when signed by docs-kit's `publish.yml` at a `refs/tags/v*` ref for catalog_opm's `main` (`docs-kit C9`).** Lands in AGENTS.md (Repository Rules, Build And Dev Commands) and README ("Sources").
- **Only the newest minor of each major is indexed and listed in `llms.txt` and the sitemap; older minors and `edge` are `noindex`; each segment has its own Pagefind index.** Lands in README and AGENTS.md (Durable decisions, Indexing).
- **Aliases: `/catalogs/<name>/` and `/catalogs/<name>/<MAJOR>/...` go to the newest minor (of that major), as `_redirects` lines and stubs; `edge` has none. Docs pages link catalogs only through the bare tab root or the major alias, and the site writes the resolved minor's URL.** Lands in README ("Page dialect", "URL layout"), the dialect contract, and workspace `STYLE.md` (follow-up).
- **Catalog members are no longer committed reference: Principle III's "the catalog's members ... committed there" becomes "or published as signed docs bundles by docs-kit".** Lands in `openspec/config.yaml` context and AGENTS.md ("Generated reference" pattern).
- **The transition exclusion and legacy link map are temporary, removed once catalog_opm has deleted the pages and no source writes the old links; the old Reference URLs get no redirects.** Lands in `TODO.md` and README ("The Catalogs section").
- **`site/tests/lint/` and docs-kit's conformance set are kept identical: docs-kit is the source of new rules and their fixtures (the `/catalogs/` forms first), this repository re-syncs from it at the pinned docs-kit tag with every pin bump, and both linters must pass the set until phase 3 retires the shell lint.** Lands in README ("Page dialect") and AGENTS.md (Repository Rules, the source-lint bullet).
- **The fixtures in `site/tests/fixtures/bundles/` are bundle trees plus the lock an all-local pull writes over them; `task test:site` re-pulls them offline and fails on any difference.** Lands in README ("Tests").
