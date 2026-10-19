# Site bundles: pull, trust, versions and bundle-fed sections

Covers how the site gets its pages: the pull, the trust chain, the pins, the recovery from a bad bundle, the site versions, the edge build and the Catalogs and Enhancements sections. URL shapes, base path and indexing are not here.

## The flow

Every page outside `site/content/` arrives in a signed docs bundle. `task bundles:pull` runs `opm-docs pull` in the build image. It resolves each tag in GHCR, verifies the Sigstore signature, lints every page in bundle mode, and unpacks into `site/.bundles/` with `lock.json`. `task build` never pulls and fails without a lock pulled for the current `site/bundles.cue`. A local build after a release is `task bundles:pull build`.

The build stamp (`site/public/build-stamp.json`) records the site commit, `versions.<v>.bundles` and the sections. With the lock (CI's `bundles-lock` artifact) it is enough to rebuild the same pages.

## The trust chain

- The `opm-docs` pin in `site/Dockerfile` holds the version and the SHA-256 of its `linux_amd64` archive, taken from the release's `checksums.txt`.
- The trust policy in `site/bundles.cue` is written out in full: `registry`, `signer.issuer`, `signer.workflow` and `signer.refs`. The pull accepts a bundle only when its signature names the docs-kit publish workflow at a ref that matches `signer.refs`, and the tab's `repo` at `refs/heads/main`.
- Bump order: no producer's `.opm-docs-version` may name a docs-kit release newer than the one in `site/Dockerfile`. A new docs-kit schema is adopted in this order: docs-kit release, this repo's reader and pin bump, then the producer's bump.

## Recover from a bad bundle

Commit the last good run's lock (its `bundles-lock` artifact) as `site/bundles.frozen.json`. A frozen pull still fetches from GHCR and Sigstore, so an outage of either is waited out. `OPM_BUNDLES_FROZEN=<lock>` pins the digests for one run (how a failed edge run replays from its `edge-lock` artifact). A committed `site/bundles.frozen.json` applies only to `site/bundles.cue`: with another `OPM_BUNDLES_CONFIG` it is skipped with a line saying so.

## Pull settings

- `OPM_BUNDLES_LOCAL="<project>@<segment>=<dir> ..."` takes local bundle trees; a local project skips the registry. When every tab and docs project is local, the pull needs no network. Name a release minor too for a catalog, or the docs' catalog links fail.
- `OPM_BUNDLES_CONFIG` (default `site/bundles.cue`) and `OPM_BUNDLES_OUT` (default `site/.bundles`) choose the config and the output. The output must be a dot-directory under `site/` that holds no tracked file and, when not empty, a `lock.json`; anything else is refused, because the pull removes whatever it did not write. They apply to the pull only.
- `OPM_BUNDLES` is the unpacked tree a build reads. The pull never reads it, so a plain pull with it exported still writes `site/.bundles/`.

## Site versions

- The version list is `site/bundles.cue`: its `versions` names every site version and the bundles that make it. Nothing else lists versions: the build, Pagefind, the redirects, the root files, the generated Hugo versions config and the tests all take that list. `site/versions.conf` holds only each version's `label`, `weight` and `default` (exactly one). The build fails when it names a different set of versions than the lock, or any other key. `OPM_VERSIONS_CONF` selects another file for one build.
- The pull chooses pins; the site resolves none. The cli bundle is at the anchor tag in `site/bundles.cue`; library, core and opm-controller are at exactly the versions the cli bundle's manifest `pins`; opm is at its own tag (its minor follows the site version); `catalog-opm-docs` is at the catalog's major. All resolve again on every pull, the nightly one included (the owner chose release lines). A new cli line or catalog major is a commit to `site/bundles.cue`.
- Every bundle's `content/` is mounted at its version's `content/docs`. The page-set checks and the link crawl cover bundle pages and site-owned pages alike. "Edit this page" goes to `main` at the manifest's `edit` path; a generated page has none. A docs fix reaches a version through the producer's next release or a docs revision, never at the next site build.
- Preview a source repository's pages through its bundle: `opm-docs serve` there, or `OPM_BUNDLES_LOCAL="<project>@v1.0=<dir>" task bundles:pull serve` here. To see a branch, build its bundle there (`task docs:bundle` or `opm-docs build`) and pull it locally.
- The two-version test (`task versions:test`, also run by `task test:site`) needs a current pull. It builds the real version and a test version from the fixture bundles into `site/.check/versions-test/` and never writes `site/public/`.

## The edge build

`task build:edge` (CI's `sources-main`) checks every repository's `main` together. It derives `site/.edge/bundles.cue` from `site/bundles.cue` (every top-level block kept, `versions` replaced by one version with the cli at `edge` as anchor, every other docs project at `edge`), pulls into `site/.edge/bundles/`, and builds over it. The file is derived and never committed, so the trust policy has one copy. The edge build is CI-only and never a published version: its lock is the only upload, and the version set, URLs, sitemap and switcher do not change. A missing edge bundle fails it with exit 2, naming the repository.

## The Catalogs section

The catalog reference is one unversioned section, built only from signed docs bundles that the pull resolves from the tabs in `site/bundles.cue`. A new minor appears with no site commit. The adapter in `site/catalogs/` reads only the generated catalogs data, is mounted into the default version only, and sets `url` on every page. The tab exists only in a build with bundles.

The site reads the catalog's version history (`history.json`, written by the pull, recorded in the lock) and never computes it. Badges, "Changes in X" and "Removed in X" follow the docs-kit derivation only; field changes appear only in that list. A `history.json` whose digest differs from the lock, or that holds a value the docs-kit contract does not allow, fails the build; recover with a fresh pull. The fixtures under `site/tests/fixtures/bundles/` are bundle trees plus the history and lock an all-local pull writes; `task test:site` re-pulls them offline and fails on any difference.

## The Enhancements section

The enhancements repository is one unversioned section, built from its signed section bundle, pulled at `edge` only into `site/.bundles/enhancements/edge/`. The site sets each page's `url` and header params and never rewrites a page: the producer has stripped comments, resolved links and run the markup check. The adapter in `site/enhancements/` is mounted into the default version only. Never mount the section into every version. The tab exists only in a build with the section; the mounts script writes it with a copy of the default menu, because Hugo cannot merge a slice across config directories.

The data is docs-kit's schema v1 or v2 and nothing else. A v1 entry reads as the legacy layout; an OpenSpec-layout entry adds `breaking`, `after`, `accepted`, `progress`, `capabilities`, `aliases` and a list `supersededBy`. A retired slug (an alias) gets a stub and a `_redirects` line, never a Hugo `aliases` entry (it lands under the default version's directory), and the link render hook resolves a link to it to the replacing page. The fixture source holds OpenSpec-layout entries and archived legacy entries only, because the pinned `opm-docs` refuses a live old-layout folder.

## Pitfalls

- Loosening the trust policy to turn a build green: fix the cause or freeze the last good lock.
- Exporting `OPM_BUNDLES` to steer a pull: it steers the build only.
- Adding a version by a directory glob: add it to `site/bundles.cue` and `site/versions.conf`.
- A producer bumping `.opm-docs-version` before the site: the pull then fails on an unknown field.

## Check before you finish

- [ ] A trust-policy change touches `site/bundles.cue` only, and no check is loosened.
- [ ] The build runs after `task bundles:pull` with the new config.
- [ ] `task test:site` passes, including the version and fixture cases.
- [ ] No lock is staged; `site/bundles.frozen.json` is staged only for a recovery.
