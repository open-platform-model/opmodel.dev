# Build environment: Docker, images, network and host git

Covers how the site is built, served and tested: the two images, the network rule, the host requirements, git dates, the brand tasks and the comment-rule task. Bundle pulls and URLs are not here.

## Docker only

The build image (Hugo, Pagefind, `opm-docs`, git, jq) and the QA image (Chromium, Playwright, axe-core) are the only toolchain. Their versions are pinned in `site/Dockerfile` and `site/tests/browser/Dockerfile`; every download is SHA-256-checked and the base image is pinned by digest. A change of a version is a change of that file.

- Image tags are `opmodel-dev-hugo:<12 hex>` and `opmodel-dev-qa:<12 hex>`, the hash of the Dockerfile. Never stop or rebind a container another checkout runs, and never prune an image another checkout may use.
- `task build:edge` runs the pull, so it needs the network too. An all-local pull needs none.
- `serve` and `preview` publish only `127.0.0.1:${SITE_PORT:-1313}`. One Ctrl+C stops them.
- Never commit `node_modules/`.
- The repository is mounted at `/work/repo`, and `OPM_BUNDLES` read-only at `/bundles`.

## Host requirements and git dates

The host needs git, awk and jq. Git runs on the host for this repository only; nothing reads another repository. The reason: a worktree's `.git` file names a host path that the container does not mount.

- Before a build or serve, the runner script in `site/scripts/` computes the last commit date of each site-owned page into `data/opm/lastmod.json` and passes the commit as `OPM_SITE_COMMIT`. A worktree build therefore has every date.
- In a shallow clone it dates nothing (one commit would date every page), so CI keeps `fetch-depth: 0` for this repository.
- The date check counts the misses; `OPM_REQUIRE_DATES=1` (CI) makes one fail the build.
- Every other page carries its bundle manifest's `lastmod`.

## Source repositories

No other repository needs to be on disk, and there is no source-root variable. To see a branch of a source repository, build its bundle there and pull it locally (`OPM_BUNDLES_LOCAL` on `task bundles:pull build`, or on `task build:edge` to check it against every other `main`).

## Brand marks and comment rule

- `task brand:favicons` and `task brand:og` regenerate the favicons and the Open Graph card in the QA image with no network. The output is committed and never hand-edited: redraw the SVGs, or change the title or description, and rerun. The README has the brand rules.
- `task cite-lint` runs the comment rule of the enhancements repo at a pinned commit, with no exclude. It needs the network and a host Go toolchain, so it is not part of `task check` or `task ci`. CI runs the same rule in a job that calls the reusable workflow of the `.github` repo; keep the pinned commit in the Taskfile equal to that workflow's default at each `.github` pin move, and put any exclude in both places with a reason.

## Pitfalls

- Running `hugo` on the host to be quick: it skips the checks and uses another version.
- A fixed image tag in a script: it breaks parallel worktrees.
- Building a base-path preview with `task preview`: preview serves at the root, so build the default base URL for it.
- A shallow clone building with `OPM_REQUIRE_DATES=1`: it fails by design.

## Check before you finish

- [ ] Every command ran through a `task` target.
- [ ] No new network step in a build, test or QA target.
- [ ] `task ci` passes where Docker and the network are available.
