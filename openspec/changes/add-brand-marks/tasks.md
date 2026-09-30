Two sections, one commit each, on branch `feat/add-brand-marks` in `<wt>` = `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/add-brand-marks` (orchestration.md section 7, step 2). Every build reads the supervisor's `site-src` worktrees, so each build or QA command is prefixed with `OPM_SRC_WORKTREE=site-src`. `SITE_PORT=1317` applies only if you serve. Hugo, Chromium and Python run only inside the Taskfile's images; the brand tools run only through `task brand:*`. Record every spike finding in design.md under "Assumptions section 1 verifies"; those edits ride section 1's commit. Do not report or stop after section 1: the owner sees its sheets and shots in the final report (design.md Decision 8).

Throwaway renders (tasks 1.4 and 2.8) run in the QA image with the flags from 1.2 (`--rm --init --network none --user <uid>:<gid>`, no `--name`, no port, no `:z`) and mount only the worktree root at `/work/repo`. The render script and its output go under `site/.shots/brand/`, which `site/.gitignore` ignores. Copy each sheet to your scratch directory as soon as it is written, because a later `task qa` may rewrite `site/.shots/`.

"Resolves" below means: strip the scheme and host from the URL, map the path to a file under `<wt>/site/public/`, and check that the file exists.

## 1. Spike on A's baseline, then the wordmark and mark

- [x] 1.1 Baseline. Check that the six `WS/<repo>/.claude/worktrees/site-src` directories exist (trap 22), then run `OPM_SRC_WORKTREE=site-src task -d <wt> build` on the untouched branch. Verify: it is green and `<wt>/site/public/v1.0/index.html` exists.
- [x] 1.2 A1 and A4 (read only). Record in design.md what `main` holds:
  - the placeholder files under `site/static/` and `site/static/images/`;
  - `params.images`, `params.description` and `[params.navbar]` in `site/config/_default/hugo.toml`;
  - whether `site/tools/og-card.*` exists;
  - `site/static/fonts/Geist-Variable.woff2` and `GeistMono-Variable.woff2`;
  - the class hooks on the title in `site/layouts/_partials/navbar-title.html`;
  - the QA image task and its `docker run` flags in `Taskfile.yml`;
  - that `site/.gitignore` ignores `.shots/`;
  - the favicon set in the vendored `site/themes/hextra/layouts/_partials/favicons.html`, `assets/js/core/favicon.js` and `static/`;
  - that the vendored `layouts/_partials/head.html` calls `twitter_cards.html` and the theme ships no copy of it.

  Verify: design.md names each item. If the title carries no class hook other than Hextra's `hx:` utilities, stop and report under `deviations` (B owns the file).
- [x] 1.3 A2 and A3 (probe). If `main` has no `site/static/favicon.svg`, write a throwaway one (any valid SVG), then build.
  - A2: `cmp <wt>/site/static/favicon.svg <wt>/site/public/favicon.svg` succeeds, so the site's static wins over Hextra's.
  - A3: in `site/public/v1.0/index.html` and `site/public/v1.0/docs/start/what-is-opm/index.html`, each of these resolves: every `rel="icon"`, `rel="apple-touch-icon"` and `rel="manifest"` href; both navbar logo `<img src>` values; the `og:image` content; the `twitter:image` content. `twitter:image` comes from Hugo's embedded template, not Hextra's, so a pass for `og:image` says nothing about it (design.md Context). If `main` renders no `og:image`, make that check in 2.5 instead.

  Delete the throwaway file and record the results in design.md. A failure of A2, or of A3 for a favicon, manifest or logo URL, means stop and report. A failure for `og:image` or `twitter:image` only selects Decision 6's absolute URL.
- [x] 1.4 Draw up to three candidate marks to design.md's mark brief. Render each at 16, 24, 32, 64 and 512 px, in both inks and reversed on the `#0a0a0a` tile, onto one contact-sheet PNG under `site/.shots/brand/`, as the note above the sections says. This also proves A5. Copy the sheet to your scratch directory. Verify:
  - `git -C <wt> status --short --untracked-files=all` lists nothing from the render: only this change's `design.md` and `tasks.md`;
  - `ls -l` shows the sheet owned by your user;
  - read the scratch copy, pick one, and write in design.md (Decision 3) which one and why. Only the chosen candidate enters the repo.
- [x] 1.5 Write `site/static/images/opm-mark.svg` (`#0a0a0a`) and `site/static/images/opm-mark-dark.svg` (`#fafafa`) with the chosen path data. Verify:
  - the two files are identical once both colours are replaced by one token (`sed` and `diff`);
  - `grep -E '<text|<style|<script|href|<!--|xlink|inkscape|sodipodi'` finds nothing in either;
  - each is under 1024 bytes (`wc -c`).
- [x] 1.6 In `site/config/_default/hugo.toml`, set `[params.navbar]` `displayLogo`, `displayTitle` and `[params.navbar.logo]` per design.md Decision 3. Verify, after `OPM_SRC_WORKTREE=site-src task -d <wt> build`, in `site/public/v1.0/index.html` and `site/public/v1.0/docs/start/what-is-opm/index.html`:
  - there are two logo `<img>` elements, each with width and height 24;
  - each `src` resolves, and `cmp` shows the files byte-identical to `site/static/images/opm-mark.svg` and `site/static/images/opm-mark-dark.svg`.
- [x] 1.7 Add `site/assets/css/opm/brand.css` per Decision 4, selecting only the hooks recorded in 1.2. Verify:
  - the fingerprinted stylesheet under `site/public/` carries the rules. It is minified: no space after `:`, `,` or `;`, none around `{`, no final `;` and no leading zero. So with the starting values, `grep -F 'letter-spacing:-.01em'` matches, and so does `grep -F` for each selector `brand.css` uses (for example `.opm-brand .opm-title-long`). If you changed a value, grep for its minified form;
  - `grep -n 'hx\\:' <wt>/site/assets/css/opm/brand.css` prints nothing.
- [x] 1.8 Run `OPM_SRC_WORKTREE=site-src task -d <wt> qa` and read the shots of the landing and one docs page in all six variants. Verify:
  - the mark and wordmark are legible in light and dark;
  - in both site/OS mismatch variants the logo follows the site theme, not the OS;
  - at phone width the header does not overflow;
  - the a11y and search smoke tests pass.
- [x] 1.9 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `OPM_SRC_WORKTREE=site-src task -d <wt> qa` green (PNGs read), then commit `feat(site): add the opm wordmark and mark`

## 2. The favicon set and the Open Graph image

- [ ] 2.1 Write `site/static/favicon.svg` per design.md Decision 2: the chosen path data in `#fafafa` on a `#0a0a0a` rounded tile. Do not add `favicon-dark.svg`. Verify: the hygiene grep and the byte limit of 1.5 pass on it.
- [ ] 2.2 Add `site/tools/favicons.py` per Decisions 2 and 5, plus the task `brand:favicons` in `Taskfile.yml`. The task builds the QA image the way `task qa` does and runs the tool offline with the flags from 1.2.
  - The tool renders `favicon-16x16.png` and `favicon-32x32.png` from `favicon.svg`.
  - It renders `apple-touch-icon.png` (180) and `android-chrome-192x192.png` / `-512x512.png` (opaque, full-bleed) from `images/opm-mark-dark.svg` on the tile colour.
  - It packs `favicon.ico` from 16, 32 and 48 px PNG frames with `struct`.

  Run `task -d <wt> brand:favicons`. Verify:
  - `file` reports each PNG at its exact size, and `favicon.ico` as an icon resource with 3 icons;
  - `ls -l` shows every output owned by your user;
  - `git -C <wt> status --short --untracked-files=all` lists exactly these paths: this change's `tasks.md` (ticked boxes), `Taskfile.yml`, `site/tools/favicons.py`, and under `site/static/` the files `favicon.svg`, `favicon.ico`, `favicon-16x16.png`, `favicon-32x32.png`, `apple-touch-icon.png`, `android-chrome-192x192.png` and `android-chrome-512x512.png`.
- [ ] 2.3 Write `site/static/site.webmanifest` as design.md Decision 7 shows. Verify: it parses as JSON in the QA image (`python3 -m json.tool`).
- [ ] 2.4 Add `site/tools/og-card.html` and `site/tools/og-card.py` per Decision 6: adapted from the prototype (read-only), or edited if A ported them. Add the task `brand:og`, which runs like `brand:favicons`.
  - The card reads `title` and `params.description` from `site/config/_default/hugo.toml` with `tomllib`, and inlines `images/opm-mark-dark.svg`.
  - It has no gradients and no version label.
  - If `params.description` is missing (from 1.2), add it to `hugo.toml` first.

  Run `task -d <wt> brand:og`. Verify: `file site/static/images/og-default.png` reports 1200 x 630; read the PNG.
- [ ] 2.5 Set `params.images` per Decision 6, using the form 1.3 selected. If 1.3 could not check `og:image`, start with the root-relative form and switch to the absolute URL if either check below misses. Verify after a build, in `site/public/v1.0/index.html` and `site/public/v1.0/docs/start/what-is-opm/index.html`:
  - `og:image` and `twitter:image` each name the card and each resolves;
  - `site/public/images/og-default.png` exists.
- [ ] 2.6 Head asset check, over the same two pages. Each of these resolves, and `cmp` shows the file byte-identical to its `site/static/` source, which proves no Hextra copy publishes at that path:
  - every `rel="icon"`, `rel="apple-touch-icon"` and `rel="manifest"` href;
  - both navbar logo `<img src>` values;
  - the `og:image` and `twitter:image` URLs.

  Verify also that `site/public/site.webmanifest` names "Open Platform Model".
- [ ] 2.7 Durable decisions.
  - Add a `## Brand marks` heading to `README.md` that carries every README entry of design.md "Durable decisions":
    - the drawn sources, and the generated files with their two tasks;
    - the mark brief;
    - replacement by same-named files, with no `favicon-dark.svg`;
    - the wordmark in `brand.css` and the hooks it names;
    - when to rerun `task brand:og`.
  - In `AGENTS.md`, add `task brand:favicons` and `task brand:og` under Build And Dev Commands, each naming the files it regenerates and saying they are never hand-edited. If the Repository Layout tree lists `site/` subdirectories, add `site/tools/` to it.

  Verify: each README bullet of that section appears under the heading, and `grep -n 'brand:' <wt>/AGENTS.md` shows both tasks.
- [ ] 2.8 Build the owner's review sheet under `site/.shots/brand/`, as the note above the sections says, then copy it to your scratch directory:
  - the favicon at 16 and 32 px on a light and a dark tab-strip background;
  - the 180, 192 and 512 px icons on a checkerboard, to prove they are opaque;
  - `og-default.png` at full size and at 600x315.

  Verify: read the scratch copy, and `git -C <wt> status --short --untracked-files=all` lists nothing from the render. Keep its scratch path and the contact sheet's from 1.4 for the report.
- [ ] 2.9 `task -d <wt> check`, `OPM_SRC_WORKTREE=site-src task -d <wt> ci` and `OPM_SRC_WORKTREE=site-src task -d <wt> qa` green (PNGs read), then commit `feat(site): add the favicon set and the open graph image`

## After the last section (orchestration.md section 7, steps 6 to 8)

These are not tasks for apply; orchestration.md owns them.
- Verify by following `<wt>/.claude/skills/openspec-verify-change/SKILL.md` for `add-brand-marks`, running each `openspec` command as `cd <wt> && openspec ...`. Never use the root `/opsx:verify` router.
- Report with the section 7 block (`sections: 2/2`).
  - `surface:` lists what design.md "Surface" adds and relies on, including the navbar hooks `brand.css` names.
  - `questions:` carries "owner review of the marks", with the absolute paths of the contact sheet (1.4), the review sheet (2.8), and the landing and docs-page shots from the last `task qa`.
  - Then STOP and wait. The supervisor merges only after E and after the owner approves the marks.
- If the owner asks for a redraw (relayed by the supervisor):
  - edit the three drawn SVGs, then rerun the 1.5 checks on the two mark files and the 2.1 checks on `favicon.svg`;
  - update design.md Decision 3 (which drawing, and why);
  - rerun `task brand:favicons` and `task brand:og`, then 2.6 and 2.8 (new review sheet), and section 2's gates (2.9, PNGs read);
  - commit `fix(site): redraw the opm mark`;
  - rerun verify as above, then report again with the new sheet paths.
- On the supervisor's go: archive, push and open the PR (step 7). After the merge: clean up (step 8).
