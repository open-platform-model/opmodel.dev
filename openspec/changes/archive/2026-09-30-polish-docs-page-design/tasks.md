# Tasks: polish-docs-page-design

Five sections, per design.md § Section plan. Section 1 starts with the spike: design.md was written against Hextra main 275e2ad and the prototype, not against A's merged tree and v0.13.0.

Paths: `WS` is `/var/home/emil/dev/open-platform-model`; `<wt>` is `/var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/polish-docs-page-design`. Every site file below is under `<wt>/site/`.

Gates, as used below (orchestration.md sections 5, 6 and 10):
- **ci**: `OPM_SRC_WORKTREE=site-src task -d <wt> ci`. It runs `check` (Go fmt, vet and test, plus `openspec:check`), `image`, `build` and `test:site`.
- **qa**: `OPM_SRC_WORKTREE=site-src task -d <wt> qa`. It runs the shots, the axe a11y smoke test and the search smoke test. Read the PNGs it writes to `site/.shots/`.
- **before set**: on a clean tree (nothing uncommitted), run qa. Copy `site/.shots/` and `site/.check/v1.0/nav-order.txt` to a scratch directory outside the repo (`<before>`). Write `<before>/site-src.sha` with `git -C WS/<repo>/.claude/worktrees/site-src rev-parse HEAD` for opm, core, catalog_opm, cli, library and opm-operator.
- **compare**: first re-read those six SHAs. If they equal `<before>/site-src.sha`, compare with `<before>`. If not, the supervisor refreshed the sources (orchestration.md section 5), and a difference could come from them alone. Re-take the before set with this section's edits set aside: `git -C <wt> stash push --include-untracked`, the before-set steps, then `git -C <wt> stash pop`. Run qa again, then compare. A before set re-taken this way already holds the earlier sections' changes.

Never build without `OPM_SRC_WORKTREE=site-src`. If you need `task serve` or `task preview`, use `SITE_PORT=1316`.

## 1. Spike, then the page lead, lighter headings, quieter inline code and callouts (fixes 1, 2, 7)

- [x] 1.1 Preconditions. Check four things; if any fails, stop with nothing edited and report the blocker.
  - A is on `origin/main`: `site/themes/hextra/` exists and `site/themes/hextra.COMMIT` names `adf732f8d97cb8e149d4aba232a449d41cd9e38c`.
  - `task -d <wt> --list` shows the final names `build`, `ci` and `qa`, not only `hugo:*`.
  - `WS/<repo>/.claude/worktrees/site-src/docs/site` exists for opm, core, catalog_opm, cli, library and opm-operator.
  - A's archived `design.md` is at `<wt>/openspec/changes/archive/*-port-site-to-hugo-hextra/design.md`.
- [x] 1.2 Baseline. On the untouched branch, run ci and qa; verify both are green. Take the before set (Gates), with its six `site-src` SHAs.
- [x] 1.3 Spike: check SP1 to SP8, SP10 and SP11 of design.md § Research & Decisions, "Spike", on the built tree, and write one line per item under that topic's **Explored** (confirmed, or what differs). Evidence per item:
  - SP1: `ls site/assets/css/opm/`.
  - SP2: `site/public/v1.0/docs/start/quickstart/index.html`, where the badge markup sits inside `main#content > .content`; and whether the landing's layout (`site/themes/hextra/layouts/hextra-home.html`, or A's copy under `site/layouts/`) calls `custom/content-begin.html`.
  - SP3: the same page's two alerts; `grep -o -- '--hx-color-[a-z]*-[0-9]*:' site/themes/hextra/assets/css/compiled/main.css | sort -u` for every variable design.md names.
  - SP4: `site/themes/hextra/layouts/_partials/toc.html` and `site/themes/hextra/assets/js/core/toc-scroll.js`.
  - SP5: `site/layouts/_partials/sidebar.html`, and the file name that holds A's `.opm-sb-toc` rules.
  - SP6: `site/themes/hextra/layouts/_partials/breadcrumb.html`.
  - SP7: `site/themes/hextra/assets/js/core/sidebar.js`.
  - SP8: A's design.md (the comment-stripping mechanism, and so the landing file) and the call site of `opm/section-children.html` (inside `.content` or not).
  - SP10: `site/tests/browser/shots.py`: is the landing shot in all six variants, and does the 9 px check run on every shot page with an SVG, or only on a fixed list?
  - SP11: `site/scripts/check-overrides.sh`: does `--update` re-pin the paths already listed in `site/overrides.sha256`, or a fixed list in the script? Read only; never run `--update`.

  SP9 is checked by the test in 4.3. SP10 and SP11 never stop the change: a missing landing entry is added in 5.3, and a fixed `--update` list goes to the report's `follow-ups` (this change never edits `check-overrides.sh`). Where a finding differs only in a class or file name, adapt the decision in design.md. Where it changes a decision, or needs another change's files, stop and report (orchestration.md section 7, step 5).
- [x] 1.4 In `layouts/_partials/custom/content-begin.html`, print the lead first, before A's type badge, guarded by `if not .IsHome` (design.md Decision 1). Verify in the built HTML:
  - `site/public/v1.0/docs/start/quickstart/index.html` holds `<p class="opm-lead" data-pagefind-meta="description">` with the quickstart's description, inside `.content`, before the badge;
  - the site-owned overview `site/public/v1.0/docs/operating/index.html` holds one too;
  - the landing `site/public/v1.0/index.html` holds none, although its front matter has a `description`.
- [x] 1.5 In `assets/css/opm/typography.css`, add the `.opm-lead` rules and the h1-h3 scale, with its `not-prose` guard (Decisions 1 and 2). Create the file if SP1 found it missing.
- [x] 1.6 In `assets/css/opm/typography.css`, add the inline-code and alert rules (Decision 3). Every role colour must be a variable SP3 found defined, or a literal token.
- [x] 1.7 In `README.md`, add a `## Page design` heading holding durable decision 1: the description is the page lead, the card text and the search sub-line, so write it as one plain sentence that stands alone.
- [x] 1.8 Run ci and qa; both must be green. Read these PNGs of `/v1.0/docs/start/quickstart/` in desktop light, dark, both site/OS mismatches, and phone light and dark:
  - the lead sits under the title;
  - h1 is at about 36 px, and h2 is lighter and has no rule;
  - inline code has no border;
  - both alerts are flat, each with a coloured icon and start border.

  axe must report 0 violations, and A's search smoke test must pass unchanged. Then commit `feat(site): lead with the description and lighten the type` (with the design.md spike findings).

## 2. Table of contents: a visible active item, and headings from 768 px (fix 3)

- [x] 2.1 In `assets/css/opm/toc.css`, add the right-rail rules: a reserved bar on every link, and weight plus a `gray-900`/`gray-100` inset bar on `a.hextra-toc-active` (Decision 4). Create the file if SP1 found it missing.
- [x] 2.2 In `assets/css/opm/toc.css`, add the `48rem`-`79.99rem` rule that shows `.opm-sb .opm-sb-sub.opm-sb-toc` (Decision 4). If SP5 found A's sidebar rules in a file that sorts after `toc.css`, raise the selector's specificity instead of renaming A's file.
- [x] 2.3 In `site/tests/browser/`, add a shot extra at 1024 x 768 of `/v1.0/docs/start/quickstart/` (only if A's extras lack one), as its own entry. Verify: qa writes it.
- [x] 2.4 In `README.md` under `## Page design`, record the TOC half of durable decision 2: the right rail from 80 rem, the page's h2 list under its sidebar entry below that.
- [x] 2.5 Run ci and qa; both must be green. Read the PNGs:
  - the 1440 px quickstart shots show the rail with one item bold and barred, in light and dark;
  - the 1024 px shot shows the quickstart's h2 list under its sidebar entry, and no right rail;
  - the phone shots match the before set (Gates, compare), apart from section 1's changes when the before set predates section 1.

  Then commit `feat(site): show the table of contents from 768 px with a visible active item`.

## 3. Section children as cards grouped by type (fix 4)

- [x] 3.1 In `layouts/_partials/opm/section-children.html`, render A's child set in A's order as cards (Decision 5): subsections first with no heading, then Tutorials, How-to guides, Explanations and Reference, with empty groups left out, all inside `<div class="opm-cards not-prose" data-pagefind-ignore>`. Leave the call site where A put it. Verify in the built HTML:
  - `site/public/v1.0/docs/operating/index.html` shows the headings in the order Tutorials, How-to guides, Explanations;
  - each list follows the order of `site/.check/v1.0/nav-order.txt`;
  - `site/public/v1.0/docs/index.html` lists its subsections as cards with no heading;
  - the Q2 page-set check is still green.
- [x] 3.2 In `assets/css/opm/cards.css`, add the grid, card and group-heading rules, each scoped under `.opm-cards`, with the file's own list and link styles (Decision 5). Create the file if SP1 found it missing.
- [x] 3.3 If A's shot set lacks them, add shot extras for `/v1.0/docs/` and `/v1.0/docs/operating/` in `site/tests/browser/`, each as its own entry.
- [x] 3.4 In `README.md` under `## Page design`, record durable decision 3: section indexes list generated cards grouped by type, and nobody writes a child list by hand.
- [x] 3.5 Run ci and qa; both must be green, the search smoke test included. Read the PNGs of `/v1.0/docs/` and `/v1.0/docs/operating/` in light, dark and phone: the cards form a grid, and each shows a title and description; the group headings are small, not page-h2 size; no card list has bullets, and no card link is underlined. Then commit `feat(site): list child pages as cards grouped by type`.

## 4. Descriptions in search results (fix 5)

- [x] 4.1 In `layouts/_partials/custom/content-begin.html`, make the Pagefind crumbs skip home and the page's first section (Decision 6). Verify: the `crumbs:` meta in `site/public/v1.0/docs/start/quickstart/index.html` starts with the start section's title, not the docs root's title.
- [x] 4.2 In `assets/js/opm-pagefind.js`, give the page-level match `meta.description` as its sub-line, and let heading-level matches keep the excerpt (Decision 6). The `window.hextraSearch` shape does not change.
- [x] 4.3 In `site/tests/browser/`, add a separate search smoke function (Decision 10). It queries "Quickstart" and asserts three things:
  - the result whose route ends in `docs/start/quickstart/` shows the built page's `p.opm-lead` text as its page-level sub-line;
  - no result's crumbs start with the docs root's h1;
  - a heading-level match still shows an excerpt.

  This proves SP9. Record the SP9 outcome in design.md's spike list.
- [x] 4.4 In `README.md` under `## Page design`, record durable decision 4:
  - the lead is indexed and is the `description` metadata;
  - the cards are `data-pagefind-ignore`;
  - the crumbs start below the docs root;
  - a DOM change under `main#content > .content` must keep all three true.
- [x] 4.5 Run ci and qa; both must be green, the new search function included. If A's shots include the open search palette, read it: sub-lines show descriptions, and no crumb reads "Documentation". Then commit `feat(site): show descriptions in search results`.

## 5. Landing figure, phone breadcrumb and drawer, breadcrumb a11y (fixes 6, 8)

- [x] 5.1 Rebuild the hero in `site/content/_index.md` (Decision 7): an inner `.opm-hero-main` with two columns, `{{< opm/module-to-cluster >}}` in the right column, and the feature grid still inside `.opm-hero`, below it. The three feature cards lose their `style=` gradients. The copy does not change. If SP8 found the landing markup in a layout or partial, edit that one file instead, and name it in the report. Verify: `site/public/v1.0/index.html` holds one `.opm-hero-figure` with the figure's markup, and `.hextra-feature-grid` is still a descendant of `.opm-hero`.
- [x] 5.2 In `assets/css/opm/landing.css`, add the `.opm-hero-main` two-column grid from 64 rem and the quieter feature-card text (Decision 7). Leave A's `.opm-hero` rules as they are; re-scope them only if A's markup differs (Decision 7, last paragraph).
- [x] 5.3 If SP10 found the landing missing from A's shot set in any of the six variants, or outside the 9 px floor, add a landing extras entry in `site/tests/browser/`, as its own entry: all six variants, with the 9 px check applied. If the check can only reach the landing by editing A's shared code, report that under `deviations` instead. Verify: qa writes six landing PNGs, and a temporary rule in `landing.css` that shrinks the figure's text below 9 px makes qa fail (try once, then remove the rule).
- [x] 5.4 Copy `site/themes/hextra/layouts/_partials/breadcrumb.html` to `site/layouts/_partials/breadcrumb.html`, and edit it to `nav` > `ol` with `aria-current="page"` and the `opm-crumbs` class (Decision 8). Append the upstream file's hash line to `site/overrides.sha256` by hand (`sha256sum` of the vendored file, in the format of A's lines), without re-pinning any other line. Never run `check-overrides.sh --update`. Verify: the drift guard passes, and the built quickstart page holds `<nav aria-label="Breadcrumb"` with exactly one `aria-current="page"`.
- [x] 5.5 In `assets/css/opm/toc.css`, add the `.opm-crumbs` layout and the below-48rem wrap and root-hiding rules (Decision 8).
- [x] 5.6 Copy `site/themes/hextra/assets/js/core/sidebar.js` to `site/assets/js/core/sidebar.js`, and replace `scrollToActiveItem` with Decision 9's rule: no scroll while the active item is in view, upstream's near-top placement when it is not. Append its hash line to `site/overrides.sha256`, as in 5.4. Leave `layouts/_partials/sidebar.html` untouched unless SP5 or SP7 showed a missing selector (fix 8 only). Verify: the drift guard passes, and `site/.check/v1.0/nav-order.txt` is identical to the before set's copy (Gates, compare).
- [x] 5.7 In `site/tests/browser/`, add separate a11y and drawer functions and one shot extra (Decision 10):
  - on `/v1.0/docs/start/quickstart/` at desktop and 390 px, the breadcrumb landmark has one `aria-current="page"` whose text equals the h1;
  - at 390 px no displayed `.opm-crumbs li` is clipped (`scrollWidth > clientWidth`);
  - at 390 px with the drawer open: on the quickstart, `scrollTop` is 0 and the section root's link is in view; on the last page in `nav-order.txt` that has an h2, the active entry is in view, and so is the first link of its `ul.opm-sb-toc` when the box scrolled;
  - a phone shot of the quickstart with the drawer open (only if A's extras lack one).
- [x] 5.8 Draft the upstream Hextra issue as text for the report's `follow-ups`: the breadcrumb is a `div` of `div`s with no `nav`, no list and no `aria-current`, with the markup of 5.4 as the proposed fix. Do not file it; the owner files upstream issues.
- [x] 5.9 In `README.md` under `## Page design`, record the breadcrumb half of durable decision 2 (below 48 rem the crumbs wrap and hide the docs-root crumb) and durable decision 5 (why each of the two override copies exists, and to delete it when upstream fixes it).
- [x] 5.10 Run ci and qa; both must be green, with axe at 0 violations and the 9 px floor passing on the landing. Read the PNGs:
  - landing, desktop light, dark and both mismatches: the figure fills the right half and follows the site toggle, and the feature grid spans the hero's width;
  - landing, phone light and dark: the figure comes after the actions, and no feature card has a glow;
  - quickstart, phone: the crumbs wrap, with nothing clipped;
  - drawer open, phone: the section root is visible.

  Then commit `fix(site): rebuild the landing's right half and fix the mobile breadcrumb and drawer`.

## After section 5 (orchestration.md section 7; not a section, no boxes)

- Verify by following `<wt>/.claude/skills/openspec-verify-change/SKILL.md` for `polish-docs-page-design`, running every `openspec` command as `cd <wt> && openspec ...`. Never use the root `/opsx:verify` router.
- Report with the block in orchestration.md section 7, step 6:
  - `surface` lists what design.md § Interface names;
  - `deviations` lists every spike finding that changed a decision, and the landing file if it is not `site/content/_index.md`;
  - `follow-ups` holds the Hextra issue draft from 5.8, the SP11 finding when `check-overrides.sh --update` re-pins a fixed list (a later re-pin would drop this change's two lines), and the judges' suggestions this change left out (design.md § Non-Goals).

  Then stop and wait. Archive, push and the PR follow only on the supervisor's go (step 7).
