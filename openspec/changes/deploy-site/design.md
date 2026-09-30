## Context

This change starts after E (`add-site-ci`) merges. By then, `main` holds:
- A's Hugo build (`orchestration.md` section 6). `task build` writes `site/public/`, including `_redirects` (`/ /latest/ 302`, `/latest/* /v1.0/:splat 302`), a root `index.html` refresh to `/latest/`, the `/latest/` meta-refresh stubs, a root `404.html`, a per-version `404.html`, `robots.txt` and `build-stamp.json`. Static files publish once at the root (trap 9). `baseURL` is `https://opmodel.dev/` (trap 7).
- E's `.github/workflows/site.yml` (workflow `Site`). It has jobs `build` and `browser`, a concurrency group per job and none at workflow level, seven `path:` checkouts, and an artifact `site-public` holding the whole `site/public` tree. It also has `task ci:lint` (actionlint by digest). E's design names these as its hand-off to F.

Nothing is hosted today. `opmodel.dev` is parked at Namecheap: its apex has no TLS, and `www` serves a parking page (checked 2026-09-30). The repo has no GitHub environment.

A's plan leaves `TODO.md` item 3.2 (Deployment) to this change. It still lists three options (A GitHub Pages, B Cloudflare Pages, C Netlify) and ends with `**Decision**: TBD based on infrastructure preferences.`

Files under `site/` this change touches: `site/static/_headers` (new) and `site/deploy/` (new). The Hugo build gains one static input, `_headers`. It gains no mount, source repo, vendored file or pinned build tool. The theme override set, the published URLs and the version set do not change.

## Goals / Non-Goals

**Goals:**
- Every push to `main`, every nightly run and every manual run on `main` deploys the checked `site/public` to Cloudflare. Nothing else can deploy.
- Before the merge, secret-free local gates show what Cloudflare will do with the tree: its limits, its redirects, its 404 pages and its headers.
- The preview host stays out of search indexes. The future custom domain does not inherit that.
- A go-live runbook the owner can follow at cutover.

**Non-Goals:**
- The DNS change, the zone, and binding the custom domain. Those are the owner's, at cutover (O2).
- Analytics, runtime third-party scripts, and security headers such as a CSP (a possible follow-up).
- A pre-merge preview deploy. It would need a second environment without the `main` rule, which departs from O1's "deploy triggers on main" (plan-final, owner round 1).
- Changing A's build output or E's `build` and `browser` jobs.

## Decisions

### 1. Cloudflare Workers static assets, not Cloudflare Pages

An assets-only Worker named `opmodel-dev` serves `site/public`. It has no `main` script.

- **Cloudflare's own advice.** The Pages docs say "Start new projects with Workers" and that Workers "supports most Pages use cases and offers a broader feature set" (read 2026-09-30).
- **A pre-merge gate with no secret.** `wrangler deploy --dry-run` compiles a deploy "without actually deploying to live servers". `wrangler pages deploy` has no dry-run flag. With Pages, the first real deploy would be the first check (plan-final F).
- **A local runtime with the same asset routing.** `wrangler dev` serves the asset directory in workerd, so the redirects, 404 pages and headers can be exercised before the merge (decision 6). The spike confirms that `wrangler dev` applies `_redirects` and `_headers`.
- **Same `_redirects` and `_headers`.** Workers supports both natively, with the Pages syntax. "Redirects are always followed, regardless of whether or not an asset matches the incoming request", so `/latest/*` beats A's stubs.
- **Explicit 404s.** `not_found_handling: "404-page"` serves "the nearest `404.html`" with status 404. So `/v1.0/missing/` gets the version's own 404, and `/missing` gets the root one. Pages guesses the mode from the files present instead.
- **Same limits and price.** 20,000 files per version on Free and 100,000 on Paid, 25 MiB per file. Requests to static assets are "free and unlimited", and they do not count against the Free plan's Worker requests.
- **Cost accepted.** A Worker custom domain needs an active Cloudflare zone, so the nameservers must move from Namecheap. O1 already plans that move.

### 2. The deploy toolchain lives in `site/deploy/`, in one pinned image

```text
site/deploy/
  Dockerfile         FROM node:<LTS>-<debian>-slim@sha256:<index digest> AS base
                     FROM base; WORKDIR /opt/deploy; COPY package.json package-lock.json;
                     RUN npm ci --no-audit --no-fund; PATH += node_modules/.bin;
                     ENV WRANGLER_SEND_METRICS=false
  package.json       {"name": "opmodel-dev-deploy", "private": true,
                      "dependencies": {"wrangler": "<exact version, >= 4.34.0>"}}
  package-lock.json  written only by task deploy:lock
  wrangler.jsonc     decision 3
  check-deploy.sh    decision 5
  smoke.mjs          decision 6
```

- **One image for the dry run, the smoke test and the real deploy.** The version that passes the local gates is the one that deploys. The image tag is `opmodel-dev-deploy:<first 12 hex of sha256 over Dockerfile, package.json and package-lock.json>`. It is built only if missing, as A's `task image` does (trap 20). A fixed tag could let one worktree replace another's image. No container gets a `--name`.
- **wrangler by lockfile, not `cloudflare/wrangler-action`.** The action installs wrangler at run time, and wrangler's own dependencies then float. The process that holds the Cloudflare token should run only code whose integrity hash is committed. `npm ci` checks a sha512 for every package. This is Principle IV (pinned by version and checksum) applied to the deploy tool.
- **Debian slim, not Alpine.** workerd, which wrangler depends on and `wrangler dev` runs, ships glibc binaries. The Node LTS is the current one at apply time (24 on 2026-09-30). wrangler must be 4.34.0 or newer, the first release that knows the raised file limits; 4.144.0 was current on 2026-09-29. Take the newest release at apply time and record it.
- **npm never runs on the host.** `task deploy:lock` reads the `FROM ... AS base` line from the Dockerfile and runs `npm install --package-lock-only` in that image, with `site/deploy` mounted. The first lockfile is written the same way.
- **`WRANGLER_SEND_METRICS=false`.** The deploy tool reports nothing to Cloudflare beyond the deploy itself.
- **Why in `site/`.** The deploy ships `site/public`; its config sits beside what it ships. Hugo reads only its known directories, so `site/deploy/` never reaches the build. The plan named "possibly `wrangler.toml`" and "the dry-run image's Dockerfile". The lockfile, the check and the smoke test belong to that same image.

### 3. `wrangler.jsonc`: assets only, `workers.dev` on, no routes

```jsonc
{
  // Assets-only Worker for opmodel.dev. Deployed only by the Site workflow on main.
  // The custom domain is added here at go-live (README, "Go live"), never in the dashboard.
  "name": "opmodel-dev",
  "compatibility_date": "<apply date>",
  "workers_dev": true,       // the preview host, https://opmodel-dev.<account subdomain>.workers.dev/
  "preview_urls": false,     // no per-version preview hosts: one public preview is enough
  "assets": {
    "directory": "../public",              // site/public, relative to this file
    "not_found_handling": "404-page",      // nearest 404.html, status 404
    "html_handling": "auto-trailing-slash" // /x -> 307 /x/ when /x/index.html exists (Hugo's pretty URLs)
  }
}
```

- **JSONC, not TOML.** Cloudflare "recommends using `wrangler.jsonc` for new projects", and some new features are JSON-only.
- **No `routes` and no custom domain.** Binding `opmodel.dev` here would act on the zone before the owner's DNS go (O2). While the zone is still at Namecheap, it would fail every deploy. At go-live, a small follow-up change adds the route (decision 9, step 7).
- **Why never the dashboard.** "If you change your routes in the dashboard, Wrangler will override them in the next deploy with the routes you have set in your Wrangler configuration file." A domain bound by hand could vanish at the next nightly deploy. Keeping it in the config also follows the supervisor's rule: fix forward with a change, never by hand in Cloudflare.

### 4. `site/static/_headers`: noindex on `workers.dev`, a long cache only for hashed names

```text
# Every workers.dev host of this Worker stays out of search indexes.
# The custom domain never matches, so go-live needs no edit here.
https://:worker.:subdomain.workers.dev/*
  X-Robots-Tag: noindex

# Names that carry a content hash never change content: cache them for a year.
# check-deploy.sh fails the deploy if a file here has no hash in its name.
/css/*
  Cache-Control: public, max-age=31536000, immutable
/js/*
  Cache-Control: public, max-age=31536000, immutable
/:version/pagefind/fragment/*
  Cache-Control: public, max-age=31536000, immutable
/:version/pagefind/index/*
  Cache-Control: public, max-age=31536000, immutable
```

The immutable paths above are the expected set. The spike reads A's real build and fixes the final list (Research & Decisions). Evidence so far: the prototype's Hextra fingerprints its CSS and JS bundles in production (`layouts/_partials/head.html`, `scripts/core.html`), A's head hook fingerprints `assets/css/opm/*.css`, and Pagefind names its fragment and index chunks by hash.

- **Noindex scoped to the preview host.** Cloudflare's docs give this rule for `workers.dev` hosts, with placeholders in the host. It meets O1 ("the preview host sends `X-Robots-Tag: noindex` until go-live") and keeps holding after go-live, when `workers.dev` stays a mirror. The HTML cannot carry the difference, because one build serves every host.
- **No `/latest/*` rule.** The plan asked for "`latest/` no cache". On Cloudflare it would never apply: every `/latest/*` request is redirected before assets are looked up, and "redirects are applied before headers, so when a request matches both a redirect and a header, the redirect takes priority". Cloudflare's default for every file is already `Cache-Control: public, max-age=0, must-revalidate`, which revalidates each time. So a stub could never go stale even if served. The smoke test asserts both facts.
- **Everything else keeps the default.** HTML, `llms.txt`, sitemaps, fonts and Pagefind's unhashed entry files revalidate on every request. A docs page is never stale after a deploy.
- **No overlapping `Cache-Control` rules.** When several rules match one path, Cloudflare joins their values with a comma. So no two rules here may set `Cache-Control` on the same path, and there is no catch-all `/*` rule. Rules replace what Cloudflare "ordinarily sends"; the smoke test asserts the exact value.
- **Limits.** At most 100 rules, and 2,000 characters per line. This file stays far below.

### 5. `check-deploy.sh`: the limits and invariants Cloudflare will not report clearly

POSIX `sh`, `find` and `awk`, like A's scripts. It runs on the host and on the runner.

```text
sh site/deploy/check-deploy.sh DIR          exit 0 clean, 1 violations; "<path>: <message>" per violation
sh site/deploy/check-deploy.sh --self-test  builds fixtures in a mktemp directory; each must fail as expected
```

- **File count.** At most `OPM_DEPLOY_MAX_FILES`, default 20,000: the Workers Free limit per version (Cloudflare limits page, updated 2026-09-05). The summary line prints the count and the limit. Raising the limit means a Paid plan and a deliberate edit of the default.
- **File size.** No file over 25 MiB.
- **Root files the routing needs.** `_headers`, `_redirects`, `index.html`, `404.html` and `build-stamp.json` at the root of DIR. A broken or partial artifact then fails before upload, not after.
- **Long cache implies a hashed name.** It reads every path rule in `_headers` whose `Cache-Control` says `immutable`. Every file under such a path must carry a content hash in its name. The hash pattern is fixed by the spike from the real names (Hugo: `.<64 hex>.`; Pagefind: `_<hex>.`). This keeps a later change from long-caching a file that can change under the same name. The rules are read from `_headers` itself, so the two cannot drift.
- **Self-test.** The fixtures are a clean tree, a tree without `_redirects`, a tree over a lowered `OPM_DEPLOY_MAX_FILES`, a sparse file over 25 MiB, and an unhashed `css/site.css` under an immutable rule. The clean tree must pass and each other one must fail with its message. `deploy:dry-run` runs the self-test first, so the check proves itself on every run (Principle II).
- If the spike shows that wrangler's dry run does not check the `_redirects` limits (2,000 static and 100 dynamic rules) or report an invalid line, the script also counts the rules and fails on the warning. Otherwise wrangler owns that.

### 6. `smoke.mjs`: Cloudflare's routing, run locally before the merge

`task deploy:smoke` runs it in the deploy image, with `site/` mounted read-only, `--network none` and no credentials. It starts `wrangler dev` on the container's loopback against `site/public`, waits until it answers, and checks:

| Request | Expected |
|---|---|
| `GET /` | 302, `Location: /latest/` |
| `GET /latest/` | 302 to the `/latest/*` target in `_redirects` (so the redirect wins over the stub) |
| `GET /latest/<a page found in the tree>` | 302 to the same page under the default version |
| `GET /<default version>/` | 200, `Cache-Control: public, max-age=0, must-revalidate`, no `X-Robots-Tag` on the loopback host |
| `GET /<default version>/<section>` (no slash) | 307 to the same path with a trailing slash |
| `GET /<default version>/no-such-page/` | 404 with the body of `<default version>/404.html` |
| `GET /no-such-page/` | 404 with the body of the root `404.html` |
| `GET /_headers`, `GET /_redirects` | 404: the rule files are not served |
| one file under each immutable rule | `Cache-Control: public, max-age=31536000, immutable`, exactly |
| a request whose host is `opmodel-dev.x.workers.dev` | `X-Robots-Tag: noindex`, if `wrangler dev` matches rules on the request host (spike). Otherwise the supervisor's first-deploy curl checks it |

- The default version is read from `_redirects`, never hard-coded. So B's manifest can change it without editing this file.
- It runs in Node inside the image, not with curl. The Debian-slim image has no curl, and an apt package would not be pinned by checksum.
- **Where wrangler writes.** By default `wrangler dev` keeps its local state in `.wrangler/state` beside the config file, not in the working directory (wrangler's `getLocalPersistencePath`). Here the config sits on the read-only `site/` mount, so a default run would fail at `/work/site/deploy/.wrangler/`. `smoke.mjs` therefore starts `wrangler dev` with `--persist-to /tmp/wrangler-state`; `HOME` and the working directory are `/tmp` as well.
- **Staging fallback.** The spike (task 1.4) records whether any wrangler call, `deploy --dry-run` included, still writes under `.wrangler/` beside the config (temporary files, for example) and fails on the read-only mount. If one does, every wrangler call stages the config inside the container instead: copy `wrangler.jsonc` to `/tmp/stage/deploy/`, symlink `/tmp/stage/public` to `/work/site/public` so that `../public` still resolves, and pass `--config /tmp/stage/deploy/wrangler.jsonc`. The spike then checks that wrangler follows the symlink. The mount stays read-only. A read-write mount would leave an untracked `site/deploy/.wrangler/`, which `.gitignore` does not cover and this change does not touch.
- **Dropping the smoke test.** If the spike shows that `wrangler dev` does not apply `_redirects` and `_headers` as a deploy does, the smoke test is left out. The finding is recorded, and the supervisor's first-deploy curl stays the only check. That is plan-final's baseline.

### 7. `deploy:*` tasks

| Task | Does | Network | Secrets |
|---|---|---|---|
| `deploy:image` | builds `site/deploy/Dockerfile` as `opmodel-dev-deploy:<hash>` if missing | yes | no |
| `deploy:lock` | rewrites `package-lock.json` with npm in the Dockerfile's base image | yes | no |
| `deploy:dry-run` | `check-deploy.sh --self-test`, then `check-deploy.sh site/public`, then `wrangler deploy --dry-run` in the image | none, if the spike allows | no |
| `deploy:smoke` | `smoke.mjs` in the image; `wrangler dev` keeps its state in `/tmp/wrangler-state` | none | no |
| `deploy:publish` | `check-deploy.sh site/public`, then `wrangler deploy --message "<commit sha>"` in the image | yes | `CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID` |

- **Container rules.** Every container runs `--rm --init --user <uid>:<gid>`, with `HOME=/tmp` and `--workdir /tmp`. `site/` is mounted read-only at `/work/site`, with no `:z` (trap 23), and there is no fixed `--name`. The wrangler config is passed as `--config /work/site/deploy/wrangler.jsonc`, or as the staged copy when decision 6's fallback applies. Every wrangler call uses the same path, `deploy:publish` included, so the dry run checks the config the deploy uses.
- **A missing `site/public` stops the task first.** Each task that reads it has a precondition on `site/public/build-stamp.json`, with "run `task build`" as the message. A Docker bind mount of a missing path would otherwise create a root-owned directory (trap 22).
- **`deploy:publish` refuses to run outside Actions.** Its preconditions run in order: `GITHUB_ACTIONS` is `true`, then `CLOUDFLARE_API_TOKEN` is set, then `CLOUDFLARE_ACCOUNT_ID` is set. Each failure names what is missing and where it belongs. An agent's local run therefore stops before anything starts. The secrets reach the container by name only (`--env CLOUDFLARE_API_TOKEN`), never as values on a command line.
- **No task depends on `build`.** The gates run `task ci` first, and CI deploys a downloaded artifact. A hidden rebuild would check a different tree from the one deployed.

### 8. Two new jobs in `site.yml`

```yaml
  deploy-check:
    name: Deploy checks
    needs: build
    runs-on: ubuntu-latest
    timeout-minutes: 15
    concurrency:                       # E's rule: one group per job, never at workflow level
      group: ${{ github.workflow }}-${{ github.ref }}-deploy-check
      cancel-in-progress: true
    steps:
      - uses: actions/checkout@<E's pin> # v7.0.1
        with: {path: opmodel.dev, persist-credentials: false}
      - uses: go-task/setup-task@<E's pin> # v2.2.0
        with: {version: <E's exact Task version>}
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
        with: {name: site-public, path: opmodel.dev/site/public}
      - working-directory: opmodel.dev
        run: task deploy:dry-run
      - working-directory: opmodel.dev
        run: task deploy:smoke

  deploy:
    name: Deploy to Cloudflare
    needs: [build, browser, deploy-check]
    # github.repository is set on every event; the schedule payload has no repository object,
    # so the org's usual github.event.repository.fork guard would compare null there.
    if: >-
      github.repository == 'open-platform-model/opmodel.dev' &&
      github.ref == 'refs/heads/main' &&
      github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment:
      name: production                 # branch rule: main only; holds the two secrets
      url: ${{ steps.publish.outputs.url }}
    concurrency:                       # never cancel a deploy; a newer run waits its turn
      group: site-deploy
      cancel-in-progress: false
    steps:
      - name: Require the Cloudflare secrets
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          CLOUDFLARE_ACCOUNT_ID: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
        run: |   # one ::error:: line per missing name, then exit 1
          ...
      - uses: actions/checkout@<E's pin> # v7.0.1
        with: {path: opmodel.dev, persist-credentials: false}
      - uses: go-task/setup-task@<E's pin> # v2.2.0
        with: {version: <E's exact Task version>}
      - uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
        with: {name: site-public, path: opmodel.dev/site/public}
      - id: publish
        working-directory: opmodel.dev
        env: {the two secrets}
        run: |   # set -o pipefail; task deploy:publish | tee the log; write url=<workers.dev URL> to GITHUB_OUTPUT
          ...
      - name: Summary
        run: |   # file count and limit (check-deploy's line), the preview URL, the deployed commit
          ...
```

- **Triggers.** E's workflow already has `push` to `main`, the nightly `schedule` and `workflow_dispatch`; F adds no trigger. The job's `if` narrows them to `main` (O1). The environment's branch rule refuses any other ref a second time. The nightly run matters most: it is the only way a source-repo merge reaches the site.
- **The deploy ships what was checked.** It downloads the `site-public` artifact of the same run, which `build` built and tested and `deploy-check` passed. It never rebuilds.
- **`needs: browser` too.** A build that fails its accessibility or search smoke test is not published. The live version stays until a later run passes.
- **`deploy-check` runs on pull requests.** A change that breaks the header rules, the hash invariant or the routing fails its own pull request, not the next deploy. It costs each run one image build, about a minute.
- **Concurrency.** E sets no workflow-level group. A workflow-level `cancel-in-progress` group would cancel a deploy mid-run. The deploy's own group `site-deploy` never cancels a running deploy, and GitHub keeps only the newest pending one. The newest `main` wins, which is what a deploy of `main` should do.
- **A failed deploy is safe.** A Worker version goes live only when its upload finishes. Until then, the previous version keeps serving.
- **Only opmodel.dev is checked out.** The deploy jobs need the Taskfile and `site/deploy`, not the sources. Task 1.2 checks that A's Taskfile compiles, `sh:` vars included, with no sibling repos present. Task 1.9 runs the new `deploy:*` tasks the same way, with the artifact in place. If either fails because a sibling repo is missing, these two jobs copy E's seven checkouts, shallow.
- **Pins.** Reuse E's pins for `actions/checkout` and `go-task/setup-task`, and E's exact Task version. `actions/download-artifact` is new to the org: v8.0.1, commit `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c`, resolved 2026-09-30. Check for a newer release at apply time.

### 9. The go-live runbook lives in `README.md`

It sits under `## Deploy`, as `### Go live`, in owner order:

1. **Before.** The supervisor recommends C, D, M and F merged. The owner's go is the only gate (O2). 0018:OQ15 (what a page must hold before publication) is the owner's to weigh here.
2. **Record the zone.** Screenshot Namecheap's Advanced DNS page. List the live records with `dig +short <name> <type>` for the apex (A, AAAA, MX, TXT, CAA), `www`, `_dmarc` and any mail-forwarding or verification record found. Keep both with the go-live notes.
3. **Add the zone to Cloudflare (Free).** Compare Cloudflare's imported records with step 2. Add any missing TXT or MX record. Drop the Namecheap parking and URL-forward records (the apex A record to 192.64.119.93, and `www` to the parking host).
4. **DNSSEC.** If it is on at Namecheap, turn it off before the move. Turn it on again with Cloudflare's DS record once the zone is active.
5. **Move the nameservers** at Namecheap to the two Cloudflare names. Wait until the zone shows Active.
6. **Token.** If Cloudflare's custom-domain docs then require zone permissions, extend `CLOUDFLARE_API_TOKEN` to the `opmodel.dev` zone.
7. **Bind the domain through a change.** On the owner's go, the supervisor launches a small follow-up change that adds `"routes": [{"pattern": "opmodel.dev", "custom_domain": true}]` to `site/deploy/wrangler.jsonc`, keeping `workers_dev: true`. The owner merges it, and its deploy binds the domain, its DNS record and its certificate. The dashboard is never used for this (decision 3).
8. **`www`.** The owner either binds `www.opmodel.dev` in the same change or adds a zone redirect from `www` to the apex. The runbook recommends the redirect, with the path kept and a 301.
9. **Check.** Curl `https://opmodel.dev/`, which must go 302 to `/latest/`, 302 to `/v1.0/`, then 200. Also curl one page, a 404 under `/v1.0/`, `robots.txt` and the sitemap. The apex must send no `X-Robots-Tag`; the `workers.dev` host still must.
10. **Noindex needs no edit.** The rule matches only `workers.dev` hosts (decision 4).
11. **Keep the schedule alive.** GitHub disables a public repo's schedule after 60 days without repository activity. The deploy then runs only on pushes to opmodel.dev, and source-repo merges stop reaching the site. Re-enable it in the Actions tab.
12. **Roll back.** The owner may roll back to the previous version in the Cloudflare dashboard in an emergency. The rollback lasts only until the next deploy: the next push to `main`, nightly run or manual run redeploys `main` and undoes it. So pair it with a fix on `main`, or disable the `Site` workflow (`gh workflow disable Site`) until the fix is ready and re-enable it then. The fix itself lands as a change.

### 10. Where this departs from plan-final

- **No `/latest/*` no-cache rule** (decision 4). On Cloudflare it can never apply, and the default already revalidates.
- **Noindex is scoped to `workers.dev` and stays after go-live**, where O1 says "until go-live". So the runbook has no "remove the noindex rule" step (decisions 4 and 9). This touches an owner decision: the supervisor relays it to the owner for acceptance (proposal, "For the owner and the supervisor").
- **The custom domain is bound at go-live through a one-line config change**, not in the dashboard, where plan-final says "The owner applies it at cutover". This keeps it out of every deployed config until the owner's go, as the plan requires, and survives the next deploy (decision 3). The supervisor launches that change on the owner's go, and the owner merges it. The supervisor relays this to the owner for acceptance too.
- **wrangler runs from the `site/deploy` image, pinned by lockfile**, in every step, the real deploy included. Plan-final names `cloudflare/wrangler-action` or `npx wrangler` on the runner (decision 2).
- **More in `site/deploy/`** than "the dry-run image's Dockerfile" and "possibly `wrangler.toml`": the lockfile, `wrangler.jsonc`, the check and the smoke test (decision 2).
- **A `deploy-check` job and a local smoke test** beside the dry run (decisions 6 and 8). They catch routing and header mistakes before the owner's merge, where the plan left them to the first deploy.
- **Scope beyond plan-final.** The smoke test, the `deploy-check` job, the hash-invariant rule with its self-test in `check-deploy.sh`, and `deploy:lock` are all additions. The supervisor accepts them explicitly when releasing F, or splits the smoke test and the `deploy-check` job into a follow-up change (orchestration.md section 9, "Scope growth"). Decision 6 already makes the smoke test droppable.
- **Owner prerequisites:** no Cloudflare "project" exists for Workers, but the account's `workers.dev` subdomain must be registered. The `production` environment must have no required reviewers.
- **Fork guard:** `github.repository == 'open-platform-model/opmodel.dev'`, not `github.event.repository.fork == false` (decision 8).
- **`TODO.md` item 3.2** joins the Touches list, because A's plan hands it to this change.
- **Two implementation sections, as planned, plus a protocol section.** `tasks.md` section 3 follows the worker protocol (verify, report, archive) and builds nothing. The report counts only the implementation sections: `sections: 2/2`.

## Research & Decisions

### Cloudflare product, limits and routing (planning, read 2026-09-30)
**Context**: O1 leaves the choice between Workers static assets and Pages to this change, "with current Cloudflare docs". The plan remembered a 20,000-file cap and asked for it to be verified.
**Explored**: developers.cloudflare.com: `pages/` (the "Start new projects with Workers" callout); `workers/static-assets/redirects/`, `.../headers/`, `.../routing/static-site-generation/`, `.../routing/advanced/html-handling/`, `.../billing-and-limitations/`, `.../migration-guides/migrate-from-pages/`; `workers/platform/limits/` (updated 2026-09-05); `workers/wrangler/commands/workers/` and `.../pages/`; `workers/wrangler/configuration/`; `workers/configuration/routing/custom-domains/`; `workers/ci-cd/external-cicd/github-actions/`. GitHub releases: wrangler 4.144.0 (2026-09-29), `cloudflare/wrangler-action` v4.1.3, `actions/download-artifact` v8.0.1. `gh api repos/open-platform-model/opmodel.dev/environments`: none.
**Decision**: Workers static assets, deployed by wrangler from a lockfile-pinned image; the facts quoted in decisions 1 to 4.
**Rationale**: Workers matches Pages on everything this site uses (`_redirects`, `_headers`, limits, price). It adds the vendor's recommendation, a secret-free dry run, a local runtime for a pre-merge smoke test, and explicit 404 handling. Its one cost, a Cloudflare-managed zone for the custom domain, is already planned.

### GitHub Actions facts (planning, read 2026-09-30)
**Context**: The deploy must run on the nightly schedule, and must never run on a fork.
**Explored**: GitHub's "Events that trigger workflows": the `schedule` webhook payload is "Not applicable"; schedules run only on the default branch; "In a public repository, scheduled workflows are automatically disabled when no repository activity has occurred in 60 days." E's `design.md` (planned in parallel): jobs `build` and `browser`, per-job concurrency, artifact `site-public`, pins, and its note that `upload-artifact` skips hidden files.
**Decision**: Guard on `github.repository`; `needs: [build, browser, deploy-check]`; download `site-public`; the 60-day rule goes in the README.
**Rationale**: `github.event.repository` is absent on `schedule`. The artifact is the checked tree, and `site/public` has no hidden file.

### Spike findings (section 1, filled in at apply time)
**Context**: Seven facts can be read only from A's and E's merged `main`, or from a running wrangler. They are numbered "finding 1" to "finding 7", never S1 to S7: in this change set, S1-S6 are the source-repo changes.
**Explored**: tasks 1.1 to 1.5, and 1.9.
**Decision**: Record here:
- Finding 1: E's merged `site.yml`: job ids, the artifact name and whether it holds every file of `site/public`, the concurrency placement, the pins and the Task version.
- Finding 2: in a clone of opmodel.dev `main` with no sibling repos, whether A's Taskfile compiles with its `sh:` vars evaluated (`task --dry check`; `--list` evaluates none), task 1.2. Then whether this branch's `deploy:dry-run`, `deploy:smoke` and `deploy:publish` behave there as in the worktree, with the artifact copied in, task 1.9.
- Finding 3: the image builds; `wrangler --version`.
- Finding 4: whether `wrangler deploy --dry-run` runs with no credentials and `--network none`, whether it reads `_headers` and `_redirects`, and whether an invalid line (tried on a scratch copy, never in `site/`) fails it or only warns.
- Finding 5: whether `wrangler dev` applies `_redirects`, `_headers` and `not_found_handling` as decision 6 expects, including the `workers.dev` host rule. Also whether any wrangler call writes `.wrangler/` beside its config on the read-only mount, and so needs decision 6's staging fallback.
- Finding 6: the fingerprinted paths in A's `site/public`, the final immutable rules, the hash pattern, and the file count against 20,000.
- Finding 7: whether `task build` stays green with `_headers` in `site/static/`: the stray-file, planning-comment and supply-chain checks, and `_headers` at the root of `site/public`.
**Rationale**: (record why each decision above held or changed)

## Interface (orchestration.md section 6)

- **Adds:** the tasks `deploy:image`, `deploy:lock`, `deploy:dry-run`, `deploy:smoke` and `deploy:publish`. The env var `OPM_DEPLOY_MAX_FILES`, which is F's own and not part of interface A. The image `opmodel-dev-deploy:<hash>`. `site/static/_headers`, and `site/deploy/`. The `site.yml` jobs `deploy-check` and `deploy`.
- **Relies on:**
  - the tasks `check`, `ci` (`check`, `image`, `build`, `test:site`) and `build`, and E's `ci:lint`;
  - `OPM_SRC_WORKTREE=site-src` for the local gates;
  - the outputs `site/public/` with `_redirects`, the root `index.html` and `404.html`, the per-version `404.html`, `robots.txt` and `build-stamp.json`, and the build summary's file count;
  - static files publishing once at the root (trap 9);
  - checks 7 (stray files, per version), 10 (planning comments, by extension) and 11 (supply chain, HTML, CSS and JS), which must stay green with `_headers` published;
  - E's jobs `build` and `browser`, its artifact `site-public`, its per-job concurrency rule and its pins.
- **Changes:** nothing A or E defines.

## Risks / Trade-offs

- [`_redirects` loses to the `/latest/` stubs on the live host] -> Cloudflare's docs say redirects always win, and the smoke test asserts it under `wrangler dev`. The supervisor's first-deploy curl checks it live. A failure is fixed forward by a new change.
- [`wrangler dev` routes differently from production] -> The first-deploy curl repeats the smoke checks live. If the spike finds a difference, decision 6 says what drops.
- [A later change adds an unhashed file under a long-cached path] -> `check-deploy.sh` fails the `deploy-check` job on that change's own pull request.
- [The file count nears 20,000] -> The check fails at the limit and prints the count on every run. Today's build has a few hundred files. A second version or the generated reference (reservation 1.4) grows it; a Paid plan raises the limit to 100,000.
- [The preview host's absolute links point at the parked apex] -> `baseURL` is `https://opmodel.dev/` (trap 7), so canonical links, sitemaps and Open Graph URLs name a host that is not live yet. Navigation and every redirect are relative, so the preview works. The `noindex` header keeps the preview out of indexes.
- [Nightly deploys stop after 60 days without activity] -> The README says so. The runbook's step 11 says how to re-enable the schedule.
- [A routes or domain edit made in the dashboard is lost] -> The config is the only home of routes (decision 3). The runbook binds the domain through a change.
- [Token scope] -> Account-limited "Edit Cloudflare Workers" token, stored only in the `production` environment, reachable only from `main`. It reaches the container by name. No step runs `set -x`.
- [Docker and the host] (traps 18, 20, 22, 23) -> Every tool runs in the deploy image. Tags come from content hashes, and no container has a fixed name. Preconditions check `site/public` before any mount, and no mount carries `:z`. Nothing runs npm, node or npx on the host; `deploy:lock` runs npm in the pinned base image.
- [A Taskfile that needs sibling repos to load] -> Finding 2 (tasks 1.2 and 1.9). The fallback is E's checkouts in the deploy jobs.
- [wrangler writes `.wrangler/` beside its config, on the read-only mount] -> `wrangler dev` gets `--persist-to /tmp/wrangler-state`. Finding 5 records any other write, and decision 6's staging fallback keeps the mount read-only and the repo clean.
- [workerd on Alpine] -> The image is Debian slim.
- [`upload-artifact` skips hidden files] -> `site/public` has none today. If one ever appears, E's upload step needs `include-hidden-files: true`, and `check-deploy.sh`'s root-file list catches the loss of the files the routing needs.
- [Builds against stale sources] (trap 25) -> Local gates run with `OPM_SRC_WORKTREE=site-src`.
- [Old Astro tasks] (trap 35) -> This change starts after A's cutover. Its tasks have new names.

## Durable decisions

All land in `README.md`, `## Deploy`, in section 2:
- **Host and trigger.** Cloudflare Workers static assets, Worker `opmodel-dev`. It deploys only from the `Site` workflow on `main` (push, nightly, manual), in the environment `production`, after `build`, `browser` and `deploy-check` pass.
- **Local gates.** `task deploy:dry-run` and `task deploy:smoke` need no secret and no network. `task deploy:publish` runs only in Actions.
- **Pins.** wrangler is pinned by `site/deploy/package-lock.json`. Bump it with `task deploy:lock`, never with npm on the host. It must stay at 4.34.0 or newer.
- **Headers.** A long cache only for names with a content hash, and `check-deploy.sh` enforces it. `noindex` applies to `workers.dev` hosts only, and stays after go-live.
- **Routes and the custom domain** live in `site/deploy/wrangler.jsonc`, never in the dashboard.
- **File limit.** 20,000 per version on the Free plan, checked on every run.
- **Schedules** lapse after 60 days without activity.
- **The go-live runbook.**
- **`TODO.md` item 3.2** names the chosen setup (Workers static assets, deployed from the `Site` workflow) and keeps open checkboxes only for the owner's go-live steps, pointing at the runbook. Section 2.
- **Spike findings** stay with the change.

## Open Questions

- Whether `_redirects` wins over the `/latest/` stubs on the live host exactly as in `wrangler dev`. The supervisor's first-deploy curl answers it after the merge; the approach does not change either way (plan-final section 5).
