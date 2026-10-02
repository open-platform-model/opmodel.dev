## Why

After A (`port-site-to-hugo-hextra`) and E (`add-site-ci`) merge, the site builds and is tested in CI, but it reaches no reader. `opmodel.dev` is still a parked Namecheap domain, and the repo has no host. The owner chose Cloudflare (O1). The site deploys to Cloudflare's preview host first; the DNS cutover waits for the owner's go (O2).

This change adds that deploy. It is change F of the Hugo migration set (`orchestration.md`). Its first deploy runs when the owner merges it, and the supervisor verifies that deploy by curl.

**Re-gated 2026-09-30.** The owner decided: "I think it would be easier to just publish as a github pages site for now. But only for the moment. The real plan is to use cloudflare, but when i have finish more of the documentation." The change `publish-interim-github-pages` publishes the site to `https://open-platform-model.github.io/opmodel.dev/` in the meantime. So this change starts on the owner's go for Cloudflare, after more of the documentation is written. It also retires the interim GitHub Pages deploy, in a section of its own (design.md decision 11).

## What Changes

- **Product: Cloudflare Workers static assets.** An assets-only Worker named `opmodel-dev` serves `site/public/`. It has no Worker script. Cloudflare Pages was the other option; design.md says why Workers wins (Cloudflare's current advice for new projects, and a dry run that needs no secrets).
- **New `site/deploy/`: a pinned deploy toolchain.**
  - `Dockerfile`: the Debian-slim Node LTS image by digest, with wrangler installed by `npm ci` from a committed lockfile.
  - `package.json` and `package-lock.json`: wrangler at one exact version, with an integrity hash for every package.
  - `wrangler.jsonc`: the Worker's name, the assets directory, `404-page` not-found handling, the `workers.dev` host on, and no routes. The custom domain is not in it.
  - `check-deploy.sh`: fails a `site/public` tree that exceeds Cloudflare's file limits, lacks a root file the routing needs, or long-caches a file whose name carries no content hash. It carries its own failing fixtures (`--self-test`).
  - `smoke.mjs`: serves `site/public` with `wrangler dev` inside the container, with no network and no credentials, and asserts the redirects, the 404 pages and the headers.
- **New `site/static/_headers`.** Hugo copies it to the root of `site/public`.
  - Every `*.workers.dev` host sends `X-Robots-Tag: noindex`. The custom domain never matches that rule.
  - Content-hashed files (Hugo's fingerprinted CSS and JS, Pagefind's hashed chunks) get a one-year `immutable` cache. Everything else keeps Cloudflare's default, which revalidates on every request.
- **`Taskfile.yml`: `deploy:*` tasks only.**
  - `deploy:image` builds the image.
  - `deploy:lock` regenerates the lockfile with npm inside the image's base.
  - `deploy:dry-run` runs `check-deploy.sh`, then `wrangler deploy --dry-run`.
  - `deploy:smoke` runs `smoke.mjs`.
  - `deploy:publish` deploys. It refuses to run outside GitHub Actions, and it names a missing secret before it starts anything.
- **`.github/workflows/site.yml`: two new jobs beside E's `build` and `browser`.**
  - `deploy-check`, on every run, pull requests included: it downloads E's `site-public` artifact and runs `task deploy:dry-run` and `task deploy:smoke`. It needs no secret.
  - `deploy`, only for `push`, `schedule` and `workflow_dispatch` on `refs/heads/main` of `open-platform-model/opmodel.dev`. It runs in the GitHub environment `production`, in its own non-cancelling concurrency group, and needs `build`, `browser` and `deploy-check`. Its first step fails, naming the secret, when `CLOUDFLARE_API_TOKEN` or `CLOUDFLARE_ACCOUNT_ID` is missing. It then deploys the artifact that `build` built and `deploy-check` checked, and writes the file count and the preview URL into the job summary.
- **`README.md`: a new `## Deploy` heading.** It covers how the deploy works, the local gates, the pins, the 60-day schedule rule and the go-live runbook (zone export, nameserver move, custom-domain binding, checks).
- **`TODO.md` item 3.2 (Deployment)**, which A leaves to this change, records the chosen setup in place of its three options and its `Decision: TBD` line.
- **The interim GitHub Pages deploy retires** (`publish-interim-github-pages`, section 3 here).
  - Removed from `site.yml`: the `pages-deploy` job, the Pages build and upload steps at the end of `build`, and the workflow env `PAGES_BASE_URL`.
  - Removed from `README.md`: `### GitHub Pages (interim)` under `## CI`, with its table row.
  - The deploy ships the `site-public` artifact, which is built without `OPM_BASE_URL`, so its base URL is `https://opmodel.dev/`. `hugo.toml`'s `baseURL` never changed.
  - Kept: `OPM_BASE_URL`, the base-path handling and its test, and the indexed-host `noindex` rule. The rule stays correct, because `opmodel.dev` is the indexed host, and the `workers.dev` preview is built for `https://opmodel.dev/` and gets this change's header instead.

Nothing here is **BREAKING**. No URL, page or version changes. Nothing deploys before the owner merges this change.

## Owner prerequisites

These gate the start of this change; the supervisor confirms the names before launching it (`gh secret list --env production`, names only).

- The owner's go for Cloudflare, which waits until more of the documentation is written (owner decision, 2026-09-30).
- A Cloudflare account. The Free plan is enough: requests to static assets are free and unlimited, and a Worker version may hold 20,000 files.
- The account's `workers.dev` subdomain, registered once in the dashboard (Workers & Pages). With Workers there is no project to create: the first deploy creates the Worker `opmodel-dev`.
- An API token from Cloudflare's "Edit Cloudflare Workers" template, limited to that one account, and the account ID. Both are stored as secrets of the GitHub environment `production`, as `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID`.
- The GitHub environment `production` on `open-platform-model/opmodel.dev`, with a deployment branch rule that allows only `main` (repo admin). It has no required reviewers, or every nightly deploy would wait for a click.
- Later, and only for go-live: the nameserver move from Namecheap. Export the zone first, including TXT and MX records. The runbook lists the steps.

## For the owner and the supervisor

The first two points change steps that O1 and plan-final give to the owner, on host and URLs, so the supervisor relays them to the owner for acceptance when it launches this change (orchestration.md section 9). The third and fourth are the supervisor's call.

- **Noindex stays on `workers.dev` after go-live.** O1 says the preview host sends `X-Robots-Tag: noindex` "until go-live". Here the rule matches only `*.workers.dev` hosts, which stay a mirror after go-live. So the rule is never removed, and the custom domain never sends it.
- **The custom domain is bound by a go-live change, not by hand.** Plan-final says "The owner applies it at cutover". Here, on the owner's go, the supervisor launches a small follow-up change that adds the route to `site/deploy/wrangler.jsonc`, and the owner merges it. Its deploy binds the domain. A domain bound in the dashboard could be dropped by the next deploy.
- **The github.io copy stops updating at this merge.** Section 3 removes the Pages job, so the interim site keeps its last deploy until the owner turns Pages off, which the owner does once the first Cloudflare deploy is verified. From then until the DNS go, the `workers.dev` preview is the URL to share. If the owner wants the github.io site kept current until go-live, the supervisor moves section 3 into the go-live change instead. It is a section of its own so that it can move.
- **Scope beyond plan-final.** The `wrangler dev` smoke test, the `deploy-check` job on every pull request, the hash-invariant rule with its self-test in `check-deploy.sh`, and `deploy:lock` (design.md decision 10). The supervisor accepts them explicitly when releasing this change, or moves the smoke test and the `deploy-check` job into a follow-up change. Design.md decision 6 already makes the smoke test droppable.

## Before / After

**Before**

```text
.github/workflows/site.yml    jobs: build, browser                        (E)
                              env PAGES_BASE_URL; build ends with the Pages build and upload;
                              job pages-deploy                            (publish-interim-github-pages)
site/static/                  no _headers                                 (A)
site/deploy/                  none
Taskfile.yml                  no deploy:* tasks
README.md                     no Deploy heading; ## CI holds ### GitHub Pages (interim)
TODO.md                       3.2 Deployment: Options A GitHub Pages, B Cloudflare Pages, C Netlify;
                              **Decision**: TBD
Cloudflare                    nothing; opmodel.dev parked at Namecheap
```

**After**

```text
.github/workflows/site.yml
  env:                        PAGES_BASE_URL removed
  jobs:
    build, browser            unchanged (E), except that build loses the interim Pages build and upload
    pages-deploy              removed
    deploy-check              every run: checkout opmodel.dev -> setup-task -> artifact site-public
                              -> task deploy:dry-run -> task deploy:smoke
    deploy                    if: repo is open-platform-model/opmodel.dev, ref main, event is not pull_request
                              needs: build, browser, deploy-check
                              environment: production
                              concurrency: {group: site-deploy, cancel-in-progress: false}
                              secrets check -> checkout -> setup-task -> artifact site-public
                              -> task deploy:publish -> summary (file count, preview URL)
site/static/_headers          https://:worker.:subdomain.workers.dev/*   X-Robots-Tag: noindex
                              content-hashed paths                       Cache-Control: public, max-age=31536000, immutable
site/deploy/
  Dockerfile                  node LTS (Debian slim) by digest; npm ci; WRANGLER_SEND_METRICS=false
  package.json                {"dependencies": {"wrangler": "<exact 4.x, >= 4.34.0>"}}
  package-lock.json           integrity hashes for every package
  wrangler.jsonc              name opmodel-dev; assets {directory ../public, not_found_handling 404-page,
                              html_handling auto-trailing-slash}; workers_dev true; preview_urls false; no routes
  check-deploy.sh             file count <= 20,000; each file <= 25 MiB; root files; immutable => hashed
  smoke.mjs                   wrangler dev in the container; asserts redirects, 404s, headers
Taskfile.yml                  + deploy:image, deploy:lock, deploy:dry-run, deploy:smoke, deploy:publish
README.md                     + ## Deploy (with the go-live runbook); ### GitHub Pages (interim) removed
TODO.md                       3.2 Deployment: the three options and the TBD line -> the chosen setup;
                              go-live steps left open
Cloudflare (after the merge)  Worker opmodel-dev at https://opmodel-dev.<account subdomain>.workers.dev/
GitHub (owner, after the first Cloudflare deploy is verified)
                              Pages off, environment github-pages deleted; the github.io URL returns 404
```

## Impact

- **Touches.**
  - `.github/workflows/site.yml`: the `deploy-check` and `deploy` jobs. In section 3, the removal of the interim Pages pieces (the `pages-deploy` job, the two Pages steps at the end of `build`, `PAGES_BASE_URL`). E's jobs otherwise stay as they are.
  - `site/static/_headers` (new).
  - `site/deploy/` (new): `Dockerfile`, `package.json`, `package-lock.json`, `wrangler.jsonc`, `check-deploy.sh`, `smoke.mjs`. The plan named "possibly `wrangler.toml`" and "the dry-run image's Dockerfile"; design.md says why the directory holds the rest.
  - `Taskfile.yml`: the `deploy:*` tasks only.
  - `README.md`: its own `## Deploy` heading. In section 3, the removal of `### GitHub Pages (interim)` under `## CI`, with its table row and its "Summary and artifacts" sentence.
  - `TODO.md`: item 3.2 (Deployment) only, which A leaves to this change. Its three options (GitHub Pages, Cloudflare Pages, Netlify) and its `Decision: TBD` line become the chosen setup, and the owner's go-live steps stay open.
  - `openspec/changes/deploy-site/`: task ticks and the spike findings in `design.md`.
- **Build inputs.** The Hugo build gains one static file, `_headers`, published once at the root. It gains no mount, source repo or pinned tool. The deploy adds its own image: Node by digest and wrangler by lockfile.
- **Source repos.** None has to change. The deploy publishes whatever the build of their `main` produced.
- **Published URLs and versions.** After the owner's merge, the preview host serves `/` (302 to `/latest/`), `/latest/*` (302 to `/v1.0/...`) and `/v1.0/...`, exactly as A builds them. `opmodel.dev` itself changes only at the owner's DNS go. Versioning stays 0021:OQ15, an open question this change does not touch.
- **Depends on.**
  - Starts when: E (`add-site-ci`) is merged, `publish-interim-github-pages` is merged (or was dropped; section 3 then has nothing to remove), the owner has given the go for Cloudflare after more of the documentation is written, and the owner prerequisites above exist.
  - Merges when: the verify is green and the owner has reviewed it. The owner merges it. Nothing can deploy before the merge.
  - After the merge: the supervisor verifies the first deploy on the preview host by curl, and reports to the owner. A failure is fixed forward by a new small change, never by hand in Cloudflare.
  - Then the owner turns GitHub Pages off and deletes the `github-pages` environment (repo settings; the README runbook of `publish-interim-github-pages` has the commands, and the supervisor's first-deploy report repeats them, because section 3 removes that runbook). The supervisor confirms that `https://open-platform-model.github.io/opmodel.dev/` returns 404.
  - The DNS cutover is the owner's action, on the owner's go. The supervisor recommends having C, D, M and F merged first. The domain binding rides the go-live change that the supervisor launches on that go; the owner merges it.

## Enhancement

None as a delivery claim. This change carries no `enhancement.yaml`, because no change in this set claims delivery (supervisor ruling O7).

Related decisions, for context only:
- Every page is built and shown while the site is unpublished. The preview host serves that purpose: it is public but sends `noindex`, and nothing links to it.
- What a page must hold before the site is published is still the owner's call. The interim GitHub Pages publication answered it for the interim site only, by the owner's explicit acceptance recorded in that change's pull request. It applies again at the owner's go-live (design.md decision 9, step 1), not to this change, whose preview host is `noindex` and unlinked.
