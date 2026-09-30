# Tasks: publish-interim-github-pages

`<wt>` is `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/publish-interim-github-pages`, on branch `ci/publish-interim-github-pages` from `origin/main` (orchestration.md section 7, step 2). `WS` is `/var/home/emil/dev/open-platform-model`. `<scratch>` is your scratch directory, outside every repo.

There are three implementation sections, then the worker protocol. Section 1 is a spike. It writes findings 1 to 5 into design.md "Spike findings" (never S1 to S5: in this change set, S1-S6 are the source-repo changes). If a finding breaks a decision, stop and report it under `deviations`, unless the task names a fallback.

**Nothing in this change deploys.** Never run a `gh api` call that writes, and never change a repo setting, the Pages site or the `github-pages` environment: those are the owner's. The first deploy happens when the owner merges this change. Build, test and QA only through the Taskfile's Docker tasks. Never run `task serve` or `task preview` unless a task says so; if you must, use `SITE_PORT=1320`, because a stale container holds 1313.

Gates, run on the whole worktree at every section end:
- `task -d <wt> check`
- `OPM_SRC_WORKTREE=site-src task -d <wt> ci`. Leave `OPM_REQUIRE_DATES` unset, except where task 3.3 sets it.
- `git -C <wt> diff --check`
- Section 2 adds `task -d <wt> qa` (the font URLs change), and section 3 adds `task -d <wt> ci:lint` (the workflow changes).

## 1. Spike: the base URL as a build input (Taskfile, site/scripts)

- [x] 1.1 Preconditions. If any check fails, stop with nothing edited and report it.
  - `task -d <wt> --list` names `ci`, `ci:lint`, `qa`, `versions:prepare` and `brand:og`.
  - `<wt>/site/versions.conf` exists.
  - `<wt>/.github/workflows/site.yml` has the jobs `build` and `browser`, and `grep -n -i pages <wt>/.github/workflows/site.yml` prints nothing.
  - `git -C WS/<repo>/.claude/worktrees/site-src rev-parse HEAD` prints a SHA for each of opm, core, catalog_opm, cli, library and opm-operator.
  - The audit's faults are still there: `grep -n 'url("/fonts' <wt>/site/assets/css/opm/base.css`, `grep -n '"start_url": "/"' <wt>/site/static/site.webmanifest` and `grep -n 'url=/latest/' <wt>/site/scripts/build-all.sh` each hit.
  - Pages, read-only: `gh api repos/open-platform-model/opmodel.dev/pages --jq '.build_type + " " + .html_url'` prints `workflow https://open-platform-model.github.io/opmodel.dev/`, and `gh api repos/open-platform-model/opmodel.dev/environments/github-pages/deployment-branch-policies --jq '[.branch_policies[].name]'` prints `["main"]`. If either differs, record it for the report's `questions`: it gates the owner's merge, not this work.
- [x] 1.2 Spike, finding 2: the baseline and its noise. Run `OPM_SRC_WORKTREE=site-src task -d <wt> build` on the unchanged tree, and copy `<wt>/site/public` to `<scratch>/public-a`. Build again and copy it to `<scratch>/public-b`. Run `diff -r <scratch>/public-a <scratch>/public-b`. Record finding 2: the two are identical, or which files differ. `public-a` is the baseline for tasks 1.3 and 2.8.
- [x] 1.3 The input (design.md decision 1).
  - `Taskfile.yml`: make the `build` task's command `OPM_BASE_URL={{shellQuote (.OPM_BASE_URL | default "")}} sh site/scripts/run-in-image.sh build`. Do not add `OPM_BASE_URL` to the `&hugo-env` anchor: an `env:` entry loses to an exported variable in Task 3.52.0 (design.md decision 7).
  - `site/scripts/run-in-image.sh`: pass `--env OPM_BASE_URL=<value>` in the `build` case only, and only when it is non-empty. Leave `run()` alone. Document the variable in the header.
  - `site/scripts/build-all.sh`: resolve `BASE_URL`, validate it, pass `--baseURL` only when `OPM_BASE_URL` is set, and export `BASE_URL` and `BASE_PATH`. Document them in the header.
  - Verify: `OPM_SRC_WORKTREE=site-src task -d <wt> build` is green. `diff -r <scratch>/public-a <wt>/site/public` shows nothing beyond finding 2's noise (finding 3, first half).
  - Verify: `OPM_SRC_WORKTREE=site-src OPM_BASE_URL=https://pages.example/opm/docs task -d <wt> build` fails with the base URL message and prints no `== hugo build`.
  - Verify: `grep -n OPM_BASE_URL <wt>/site/scripts/run-in-image.sh` hits only the header and the `build` case.
  - Verify: `OPM_BASE_URL=https://pages.example/opm/docs/ OPM_SRC_WORKTREE=site-src task -d <wt> --dry build` prints a line `OPM_BASE_URL=https://pages.example/opm/docs/ sh site/scripts/run-in-image.sh build`, and `env -u OPM_BASE_URL OPM_SRC_WORKTREE=site-src task -d <wt> --dry build` prints `OPM_BASE_URL='' sh site/scripts/run-in-image.sh build`.
- [x] 1.4 Spike, findings 1 and 4: the real site under the Pages path. Run `OPM_SRC_WORKTREE=site-src OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task -d <wt> build`.
  - It is expected to fail at `check-pages (post)` with `LINK FAIL`, because the crawl does not strip the base path yet. If an earlier step fails, stop and report.
  - Record the time to that point and the file count of `site/public` (finding 4).
  - Then scan `<wt>/site/public` on the host with `grep` and `find` only; nothing there runs. Record finding 1 (design.md lists the four scans):
    - HTML: every root-relative value that does not start with `/opmodel.dev/` (skip `//`) in `href`, `src`, `data-url`, each `srcset` entry, `poster`, `data` and `xlink:href`, and in `url()` inside a `style` attribute or a `<style>` block;
    - CSS: every `url(` followed by `/`, `"/` or `'/`;
    - absolute URLs: in `*.html` (meta `content` included), `*.xml`, `*.txt`, `*.md`, `*.json` and `*.webmanifest` outside `*/pagefind/*`, every `https://`, `http://` or `//` URL on `open-platform-model.github.io` that does not start with `https://open-platform-model.github.io/opmodel.dev/`;
    - JS outside `*/pagefind/*`: string literals starting with `'/`, `"/` or a backtick and `/`, followed by `v[0-9]`, `latest`, `docs`, `pagefind`, `css`, `js`, `fonts` or `images`;
    - `site.webmanifest`: every value that starts with `/`;
    - on one docs page: the robots meta (expected: Hextra's `index, follow` only), `og:url`, canonical, `og:image`, `twitter:image` and `itemprop` `image`; the Pagefind adapter's bundle path; `llms.txt`'s `Site:` line.
  - The expected hits are the five known faults only: the root `index.html` (`/latest/`), the two font URLs, `start_url`, and `twitter:image` and `itemprop` `image` on every page (`https://open-platform-model.github.io/images/og-default.png`). Any other hit is outside the audit and the review. Stop and report it with the file and the template that writes it. A fix in a site-owned layout, hook, asset or config joins section 2 on the supervisor's OK; a fix that needs a new override copy is a scope question. A hit in a source repo's page text is a scope question too.
  - Finally run `OPM_SRC_WORKTREE=site-src task -d <wt> build` again, so that `site/public` holds the default build.
- [x] 1.5 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `git -C <wt> diff --check` green. Stage `Taskfile.yml`, `site/scripts/run-in-image.sh`, `site/scripts/build-all.sh`, `openspec/changes/publish-interim-github-pages/design.md` and `openspec/changes/publish-interim-github-pages/tasks.md`. Then commit `feat(site): take the base url as a build input`.

## 2. A base-path-safe build, its checks and the regression test (site assets, layouts, config, scripts, tests, Taskfile, AGENTS.md, README.md)

- [x] 2.1 The faults (design.md decision 2):
  - `site/assets/css/opm/base.css`: both fonts load from `url("../fonts/...")`;
  - `site/static/site.webmanifest`: `"start_url": "./"`;
  - `site/scripts/build-all.sh`: the root `index.html` refresh and link point at `${BASE_PATH}/latest/`;
  - `site/config/_default/hugo.toml`: `images = ['images/og-default.png']`, with a comment that a leading slash makes Hugo's `absURL` drop the base path from `twitter:image` and `itemprop="image"`;
  - `site/assets/js/opm-pagefind.js`: `pagefind.options({ baseUrl: '{{ .Site.Home.RelPermalink }}', excerptLength: 20 })`, and one line in its header comment on why the base URL is explicit.
  - Verify: `grep -rnE "url\([\"']?/" <wt>/site/assets/css` prints nothing. After `OPM_SRC_WORKTREE=site-src task -d <wt> build`, `grep -o 'url=[^"]*' <wt>/site/public/index.html` prints `url=/latest/`, and `<wt>/site/public/v1.0/docs/index.html` names `https://opmodel.dev/images/og-default.png` for `og:image`, `twitter:image` and `itemprop` `image`.
- [x] 2.2 The crawl and the nav order (decision 3) in `site/scripts/check-pages.sh`, header comment included: the base-path strip and escape rule, check 11's attribute set with `srcset` split into entries, `url()` in HTML and CSS (relative ones resolved, printed as site-root paths), `/latest/` looked up as written (drop the `_redirects` mapping), and, when `BASE_PATH` is set, the absolute-URL rule over every text output, compared with awk `index()`.
  - Extend `site/tests/checks/link-crawl` with `site/assets/css/opm/zz-dead-url.css` and its two expect lines, using the `missing-from-css` names from decision 6.
  - Add `site/tests/checks/base-path-escape` (`env`, a site-owned page, `expect`), as decision 6 describes.
  - Verify: `OPM_SRC_WORKTREE=site-src task -d <wt> build` is green: the wider crawl finds nothing in the default build. If it fails, stop and report the URLs: the crawl must not change the default build's verdict.
  - Verify: `task -d <wt> test:site` reports both cases failing as their expect files say, and every other case as before.
- [x] 2.3 Check 11 (decision 4) in `site/scripts/build-all.sh`: `$BASE_URL` compared as a literal prefix (awk `index()`) in both the tag and the CSS pipelines, never inside a regex. Add `site/tests/checks/base-url-form` and `site/tests/checks/supply-base-url`.
  - Verify: `task -d <wt> test:site` reports `supply-lookalike`, `supply-srcset`, `cdn-url`, `base-url-form` and `supply-base-url` failing as expected.
- [x] 2.4 `noindex` (decision 5): `params.opm.indexedHost` in `site/config/_default/hugo.toml`, and the rule in `site/layouts/_partials/custom/head-end.html`.
  - Verify on the default build: the robots meta tags of `<wt>/site/public/v1.0/docs/index.html` say only `index, follow`.
  - Verify: `git -C <wt> diff --stat -- site/overrides.sha256` is empty, because `head-end.html` is a hook, and the build's drift guard is green.
- [x] 2.5 QA stays on the root build (decision 7).
  - `Taskfile.yml`: `qa` and `shots` call `build` with `vars: {OPM_BASE_URL: ''}`. The `build` command's inline assignment (task 1.3) carries that past an exported value. Never use an `env:` form for this: it loses to the exported variable.
  - `site/scripts/test-site.sh`: unset `OPM_BASE_URL` at its top.
  - Verify: `OPM_BASE_URL=https://pages.example/opm/docs/ OPM_SRC_WORKTREE=site-src task -d <wt> --dry qa` prints `OPM_BASE_URL='' sh site/scripts/run-in-image.sh build`, and so does the same for `shots`. Task 2.10 then proves it with a real `task qa`. If either fails, stop and report.
- [x] 2.6 The regression test (decision 6).
  - Add `site/tests/subpath/env`.
  - Add the `subpath` block, with every assertion in decision 6's table, to `site/scripts/test-site.sh`, and the no-`noindex` assertion to its `fixture` block. Document `tests/subpath/` in its header.
  - Verify: `task -d <wt> test:site` passes, with every `subpath` case `ok`.
  - Prove that it bites, one change at a time, restoring each before the next:
    - put `/fonts/` back in `base.css`: `test:site` fails the `subpath` case at the crawl;
    - drop `${BASE_PATH}` from the root `index.html`: `subpath/root` fails;
    - put the leading slash back in `params.images`: the `subpath` case fails at the crawl's absolute-URL rule, naming `https://pages.example/images/og-default.png`.
    After the three restores, `test:site` is green.
- [x] 2.7 Findings 1 and 4, again. Run `OPM_SRC_WORKTREE=site-src OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task -d <wt> build`. Verify: it is green. Repeat task 1.4's scans: they find nothing outside `/opmodel.dev/`, the docs page carries the `noindex` tag, and its three image URLs are `https://open-platform-model.github.io/opmodel.dev/images/og-default.png`. Add the time and file count to finding 4. Then run `OPM_SRC_WORKTREE=site-src task -d <wt> build` again.
- [x] 2.8 Finding 3, second half: the production output. Copy `<scratch>/public-a` and `<wt>/site/public` to scratch copies. In both, replace the fingerprints and `integrity` values of the OPM stylesheet (`opm.min.<hex>.css`) and of the Pagefind adapter script (the `<version>.<lang>.pagefind` script, whatever finding 3 shows its published name to be) with fixed placeholders, and rename the two files to match. Then `diff -r` the copies. Verify: they differ only in the two font `url()` values of the stylesheet, the adapter's `baseUrl` option, and `site.webmanifest`'s `start_url`, beyond finding 2's noise. The `og:image`, `twitter:image` and `itemprop` `image` values do not change. Anything else: stop and report.
- [x] 2.9 Durable decisions (design.md, "Durable decisions"):
  - `AGENTS.md`:
    - "Durable decisions": the base-path and indexing entries;
    - "Environment Notes": `OPM_BASE_URL`, and that QA, shots and preview serve the root;
    - the Repository Layout tree's `tests/` line: add `subpath/`.
  - `README.md`:
    - one line in the `## Tasks` block, `task build OPM_BASE_URL=<url>`;
    - the `site/tests/` line of "Directory Structure": add the base-path build.
  - Verify: `grep -n -e OPM_BASE_URL -e indexedHost <wt>/AGENTS.md` hits each entry, and `grep -n 'github.io' <wt>/AGENTS.md` prints nothing (design.md decision 11).
- [x] 2.10 Gates.
  - `task -d <wt> check` green.
  - `OPM_SRC_WORKTREE=site-src task -d <wt> ci` green.
  - `OPM_BASE_URL=https://pages.example/opm/docs/ OPM_SRC_WORKTREE=site-src task -d <wt> qa` green, with the variable exported. Then `grep -o 'url=[^"]*' <wt>/site/public/index.html` prints `url=/latest/`: QA built the default base. Read the docs-page screenshots in `site/.shots/`: the text is set in Geist and Geist Mono, not a system fallback.
  - `git -C <wt> diff --check` green.
  - Stage `site/assets/css/opm/base.css`, `site/assets/js/opm-pagefind.js`, `site/static/site.webmanifest`, `site/scripts/build-all.sh`, `site/scripts/check-pages.sh`, `site/scripts/test-site.sh`, `site/config/_default/hugo.toml`, `site/layouts/_partials/custom/head-end.html`, `site/tests/subpath/env`, `site/tests/checks/link-crawl/`, `site/tests/checks/base-path-escape/`, `site/tests/checks/base-url-form/`, `site/tests/checks/supply-base-url/`, `Taskfile.yml`, `AGENTS.md`, `README.md`, `openspec/changes/publish-interim-github-pages/design.md` and `openspec/changes/publish-interim-github-pages/tasks.md`.
  - Then commit `feat(site): build the site under a base path`.

## 3. The interim GitHub Pages deploy (CI, README)

- [x] 3.1 Finding 5: the pins. For `actions/configure-pages`, `actions/upload-pages-artifact` and `actions/deploy-pages`, read the latest release (`gh api repos/actions/<name>/releases/latest --jq .tag_name`) and its commit (`gh api repos/actions/<name>/git/ref/tags/<tag>`). If the ref is an annotated tag, dereference it to the commit. Record finding 5, and update decision 9's table if a release is newer.
- [x] 3.2 `.github/workflows/site.yml` (decisions 8 and 9).
  - Replace the dates comment in the workflow `env`, and add `PAGES_BASE_URL` with its comment.
  - Add the two steps at the end of `build`, after the `build-stamp` upload.
  - Add the job `pages-deploy` after `browser`.
  - Verify: `task -d <wt> ci:lint` is green.
  - Verify: every line `grep -n 'uses:'` prints carries a 40-hex SHA and a `# vX.Y.Z` comment.
  - Verify: `pages: write` and `id-token: write` appear only inside `pages-deploy`, and the top-level `permissions` is still `contents: read`.
  - Verify: there is no workflow-level `concurrency:`, and `grep -n 'OPM_BASE_URL:' <wt>/.github/workflows/site.yml` hits only the Pages build step.
  - Verify: the `upload-pages-artifact` step has no `if:` (it runs on every event), and `pages-deploy` has the `if:` of decision 9.
  - Verify: `git -C <wt> diff origin/main -- .github/workflows/site.yml` changes no existing line of `build` or `browser`. The only existing lines it changes are the dates comment.
- [x] 3.3 The Pages build step, reproduced locally with CI's dates rule: `OPM_REQUIRE_DATES=1 OPM_SRC_WORKTREE=site-src OPM_BASE_URL=https://open-platform-model.github.io/opmodel.dev/ task -d <wt> build` is green. Then run `OPM_SRC_WORKTREE=site-src task -d <wt> build` again.
- [x] 3.4 `README.md`, `## CI` (decision 10).
  - Add a row to the CI table for the Pages build.
  - Add a sentence to the "Summary and artifacts" bullet about the Pages summary line and the `github-pages` artifact.
  - Add `### GitHub Pages (interim)` at the end of `## CI`, with decision 10's five parts.
  - Verify: `grep -n -e 'build_type=workflow' -e 'gh api -X DELETE' -e 'noindex, nofollow' -e 'deployment-branch-policies' -e 'url=/opmodel.dev/latest/' -e 'Go to the docs' <wt>/README.md` hits each term inside the new subsection. Every check there is a literal command with its expected output, and part 2 says that only the HTML pages carry `noindex`.
  - Verify: no `## Deploy` heading is added, and `git -C <wt> diff origin/main -- README.md` touches only `## CI` and the two lines from task 2.9.
- [x] 3.5 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci`, `task -d <wt> ci:lint` and `git -C <wt> diff --check` green. Stage `.github/workflows/site.yml`, `README.md`, `openspec/changes/publish-interim-github-pages/design.md` and `openspec/changes/publish-interim-github-pages/tasks.md`, then commit `ci: deploy the site to github pages for now`.

## 4. Verify, report and archive (orchestration.md section 7, steps 6 and 7)

- [ ] 4.1 Read `<wt>/.claude/skills/openspec-verify-change/SKILL.md` and follow it for `publish-interim-github-pages`. Run each `openspec` command as `cd <wt> && openspec ...`, never through the root `/opsx:verify` router. Verify also:
  - `find <wt>/openspec/changes/publish-interim-github-pages -name enhancement.yaml` prints nothing;
  - `git -C <wt> diff --stat origin/main` touches only the Touches list in proposal.md;
  - `git -C <wt> log origin/main..HEAD` shows the three commits above. Each has only the plain `Co-Authored-By: Claude <noreply@anthropic.com>` trailer and no bare `@name`.
- [ ] 4.2 Report to the supervisor with the block in orchestration.md section 7, step 6.
  - `sections: 3/3`, counting the implementation sections.
  - `surface`: design.md's Interface section.
  - `deviations`: whatever the spike changed.
  - `gates`: every command of 1.5, 2.10 and 3.5.
  - `questions`: the Pages state from 1.1, if it differed, and the owner's acceptance of publishing every page as it is (0018:OQ15, proposal), which the pull request body must record before the merge.
  - Then STOP and wait. The owner reviews and merges this change, and the merge deploys. After it, the supervisor checks the first deploy with README "GitHub Pages (interim)".
- [ ] 4.3 Only on the supervisor's go: tick this box, then run `cd <wt> && openspec archive publish-interim-github-pages --yes --skip-specs`, then `cd <wt> && openspec validate --all --strict --no-interactive`. When both are green, stage `openspec/changes/archive/<date>-publish-interim-github-pages` and the removed `openspec/changes/publish-interim-github-pages` by explicit path, and commit `chore(openspec): archive publish-interim-github-pages`. Pushing and the pull request follow orchestration.md section 7, step 7, outside this file. The pull request title, which becomes the squash commit on `main`, is `ci: deploy the site to github pages for now`.
