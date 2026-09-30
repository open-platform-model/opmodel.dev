## Context

`port-site-to-hugo-hextra` (A) lands the Hugo site: Hextra v0.13.0 vendored in `site/themes/hextra`, the neutral skin, the docs layout body in `site/layouts/_partials/opm/docs-main.html`, the Hextra hook `site/layouts/_partials/custom/content-begin.html` (type badge and Pagefind crumbs), the child list `site/layouts/_partials/opm/section-children.html`, the one-tree sidebar `site/layouts/_partials/sidebar.html`, the Pagefind adapter `site/assets/js/opm-pagefind.js`, the landing `site/content/_index.md`, and the CSS split into `site/assets/css/opm/*.css`, concatenated in file-name order by A's `custom/head-end.html`. orchestration.md section 6 gives `typography.css`, `toc.css`, `cards.css` and `landing.css` to this change, and lets it edit `docs-main.html`, `content-begin.html`, `section-children.html`, and `sidebar.html` for fix 8 only.

What the design below rests on, as read in the prototype (`research/docs-site-stacks/hugo-themes/hextra-prototype`, Hextra main 275e2ad, which A re-pins to v0.13.0):
- `docs-main.html` calls `custom/content-begin.html` inside `<div class="content">`, so anything the hook prints is inside Pagefind's root selector `main#content > .content` and is indexed.
- Hextra's `hextra-home.html`, the landing's layout, also calls `custom/content-begin.html` (line 10), inside a `div.hx:flex.hx:flex-col.hx:items-start` and outside any `.content`. So the hook runs on the landing too, unindexed.
- Hextra's prose rules (`.content :where(h2|p|a|ul|...)`) skip anything inside a `not-prose` element. Its `feature-grid` shortcode carries `not-prose` and `hx:w-full`.
- Hextra renders a GitHub alert as `div.hextra-alert[data-alert=note|tip|important|warning|caution]` with `.hextra-alert-title`, `.hextra-alert-icon` and `.hextra-alert-content`. Each type is tinted (blue, green, purple, amber, red) by a `[data-alert=...]` rule at specificity 0,2,0.
- The right-rail TOC is Hextra's `nav.hextra-toc` (`hx:hidden hx:xl:block`, so hidden below 1280 px). `core/toc-scroll.js` gives the active link `hextra-toc-active` and `aria-current="location"`. Hextra's CSS sets only its colour, with `!important`.
- A's sidebar prints the current page's h2 headings as `ul.opm-sb-sub.opm-sb-toc` under its entry. The CSS shows that list only below 48 rem.
- Hextra's `_partials/breadcrumb.html` is a `div` of `div`s with `overflow-hidden` and `whitespace-nowrap`. It has no `nav`, no list and no `aria-current`.
- Hextra's `assets/js/core/sidebar.js` runs `scrollToActiveItem()` on `DOMContentLoaded`. It scrolls `aside.hextra-sidebar-container > .hextra-scrollbar` so the active item sits near the top. The phone drawer is the same element, so the drawer opens past the section root. `scripts/core.html` concatenates every `js/core/*.js`, so a site file at that path replaces the theme's.

These facts come from 275e2ad. Section 1 of `tasks.md` checks them against A's merged tree and v0.13.0 before any fix lands (Research & Decisions, "Spike").

Files this change touches under `site/`: `assets/css/opm/{typography,toc,cards,landing}.css`, `layouts/_partials/custom/content-begin.html`, `layouts/_partials/opm/section-children.html`, `assets/js/opm-pagefind.js`, `content/_index.md` (or A's landing layout, see Decision 7), the new copies `layouts/_partials/breadcrumb.html` and `assets/js/core/sidebar.js`, `overrides.sha256`, and `tests/browser/`. The build gains no input: no mount, source repo, vendored file or pinned tool. Published URLs and the version set do not change. **The theme override set grows by two copies** (Decisions 8 and 9), each pinned in `overrides.sha256`.

## Goals / Non-Goals

**Goals:**
- The eight fixes in `research/docs-site-stacks/hugo-themes/README.md` ("Fixes the judges want before shipping") and the breadcrumb `nav` and `aria-current` fix.
- Every check of A stays green; axe stays at 0 WCAG 2.1 A/AA violations in light and dark; the 9 px SVG text floor at 390 px holds on the landing too.

**Non-Goals:**
- The judges' other suggestions: the type badge as an eyebrow above the h1, link and table restyling, a wider sidebar, a distinct colour for CUE `#Definitions`, code language labels and an always-visible copy button, Copy page in the breadcrumb row, keyboard hints and hit colours in the search palette, the figure label letter-spacing, and Pagefind's excerpt window dropping its first word. They are listed as follow-ups in the report, not built here.
- Brand marks (M), new landing copy or a second landing band, per-page OG images, and figure work (C).
- A scrollspy for the 768 to 1279 px sidebar TOC. Only the right rail marks an active item (Risks).
- Which children a section lists. A's child set and its order (`weight`, then title) stay as they are; this change regroups and restyles them.
- Keeping figure SVG labels out of the search index. `port-remaining-figures` (C) raises it as an open question. The fix would sit in `_partials/opm/figure.html`, which C owns, so it is C's follow-up or its own change, not this one.

## Decisions

### 1. The page lead is the description, first under the title, inside the search root

`content-begin.html` prints the description before the type badge (both judges put it there). The same element is the Pagefind `description` metadata. Pagefind's element form (`data-pagefind-meta="description"` with no value) stores the element's text (pagefind.app/docs/metadata), so the lead and the search sub-line cannot drift apart.

```go-html-template
{{- if not .IsHome }}{{ with .Description -}}
  <p class="opm-lead" data-pagefind-meta="description">{{ . }}</p>
{{- end }}{{ end -}}
{{- /* then A's type badge, unchanged; then the crumbs (Decision 6) */ -}}
```

The lead is for docs pages only. Hextra's `hextra-home.html` (line 10 at 275e2ad) also calls `custom/content-begin.html`, and the landing carries a `description`, because A's front-matter check requires one on every page. Without the `.IsHome` guard, the landing would print a lead above the hero badge that repeats the hero subtitle. The guard matches the one on the crumbs. Anything added to this hook reaches the landing unless it is guarded the same way (SP2).

The lead sits inside `.content` and is indexed on purpose. 0018:D7 makes the description the page's index entry and search snippet, so a word that appears only in it should still find the page. Alternatives: `data-pagefind-ignore` on the lead (then a description-only word finds nothing), or a hidden meta span beside a separate lead (the same text twice).

`typography.css`:

```css
.opm-lead { font-size: 1.125rem; line-height: 1.6; color: var(--hx-color-gray-600);
            max-width: 42rem; margin: .25rem 0 1.25rem; text-wrap: pretty; }
html.dark .opm-lead { color: var(--hx-color-gray-400); }
```

### 2. A lighter heading scale

`typography.css`. The selectors (0,1,1) are more specific than Hextra's `.content :where(h2)` (0,1,0), so they win whether or not Hextra's rules sit in a cascade layer. Like Hextra's own prose rules, they skip anything inside a `not-prose` element, so markup that opts out of prose styles (the cards of Decision 5, Hextra's `not-prose` shortcodes) keeps its own sizes. `:where()` adds no specificity.

```css
.content h1:not(:where(.not-prose, .not-prose *)) { font-size: 2.25rem; line-height: 2.5rem;
              font-weight: 650; letter-spacing: -.035em; }
.content h2:not(:where(.not-prose, .not-prose *)) { font-size: 1.5rem; line-height: 2rem;
              font-weight: 600; letter-spacing: -.02em; border-bottom: 0; padding-bottom: 0; margin-top: 3rem; }
.content h3:not(:where(.not-prose, .not-prose *)) { font-size: 1.125rem; line-height: 1.75rem;
              font-weight: 600; margin-top: 2rem; }
```

### 3. Quiet inline code and flat callouts

`typography.css`. The alert selectors match Hextra's 0,2,0, and the file loads after Hextra's CSS, so they win. Only the icon takes the role colour. The title text keeps the body colour, so no text contrast changes. The important alert uses the skin's near-black primary; note stays grey.

Hextra's compiled CSS is purged: it defines only the colour variables Hextra itself uses. At 275e2ad, `--hx-color-green-600` and `--hx-color-amber-600` do not exist, while `--hx-color-red-600`, `-red-400`, `-gray-*` and `-primary-*` do. The tip and warning roles are therefore this file's own tokens, set to Tailwind v4's green and amber values. A `var()` of a missing variable would fail silently and paint nothing.

```css
.content :not(pre) > code { border: 0; background: var(--hx-color-gray-100);
                            padding: .1em .35em; border-radius: .3rem; font-size: .875em; }
html.dark .content :not(pre) > code { background: oklch(100% 0 0 / 8%); }

:root     { --opm-alert-tip: oklch(62.7% .194 149.214); --opm-alert-warning: oklch(66.6% .179 58.318);
            --opm-alert-caution: var(--hx-color-red-600); }
html.dark { --opm-alert-tip: oklch(79.2% .209 151.711); --opm-alert-warning: oklch(82.8% .189 84.429);
            --opm-alert-caution: var(--hx-color-red-400); }

.hextra-alert[data-alert] { --opm-alert: var(--hx-color-gray-500); color: inherit;
  background: color-mix(in oklab, var(--opm-alert) 5%, transparent);
  border: 1px solid var(--hx-color-gray-200); border-inline-start: 2px solid var(--opm-alert); }
.hextra-alert[data-alert="tip"]       { --opm-alert: var(--opm-alert-tip); }
.hextra-alert[data-alert="important"] { --opm-alert: var(--hx-color-primary-600); }
.hextra-alert[data-alert="warning"]   { --opm-alert: var(--opm-alert-warning); }
.hextra-alert[data-alert="caution"]   { --opm-alert: var(--opm-alert-caution); }
html.dark .hextra-alert[data-alert] { border-color: var(--hx-color-neutral-800);
  background: color-mix(in oklab, var(--opm-alert) 8%, transparent); }
.hextra-alert[data-alert] .hextra-alert-icon { color: var(--opm-alert); }
```

Implementation note (section 1): the dark rule's `border-color` shorthand (0,3,1) also overrides the start border's colour from the base rule (0,2,0), so as written above every dark-mode alert would lose its role-coloured start border. `typography.css` adds `border-inline-start-color: var(--opm-alert)` to the dark rule; the computed styles and the section 1 shots confirm the coloured start border in both themes.

The same purge rule holds for every `--hx-color-*` this change names. The spike (SP3) lists which ones the vendored v0.13.0 CSS defines, and any that is missing becomes a literal token here.

A's contrast fix for links inside callouts stays where A put it.

### 4. The table of contents: a visible active item, and headings from 768 px

`toc.css`. Every rail link reserves the bar, so the active change does not shift text. Hextra's `!important` colour stays; the cue is weight plus the bar.

```css
.hextra-toc a { box-shadow: inset 2px 0 0 transparent; padding-inline-start: .5rem; }
.hextra-toc a.hextra-toc-active { font-weight: 600; box-shadow: inset 2px 0 0 var(--hx-color-gray-900); }
html.dark .hextra-toc a.hextra-toc-active { box-shadow: inset 2px 0 0 var(--hx-color-gray-100); }

/* Hextra shows the rail only from 80rem; A's sidebar shows the page's h2 list only below
   48rem. Close the gap. Unlayered site CSS beats the list's hx:md:hidden utility. */
@media (min-width: 48rem) and (max-width: 79.99rem) {
  .opm-sb .opm-sb-sub.opm-sb-toc { display: flex; }
}
```

The media rule has the same specificity as A's `display: none` for that list, so it MUST come later in the concatenation. `toc.css` sorts after any file name that starts with `a` to `s`. If A's sidebar rules sit in a file that sorts after `toc.css`, raise this selector's specificity (for example `aside.opm-sb ...`); never rename A's file.

### 5. Section children as cards grouped by type

`section-children.html` keeps A's child set and A's sort expression, applied within each group. Only the grouping and the markup change. Subsections come first, with no heading. Then pages are grouped by `.Type`, in the order tutorial, how-to guide, explanation, reference (the order of 0018:D7:R2, followed as intent). Empty groups are left out.

```go-html-template
{{- $groups := slice
      (dict "type" "tutorial"    "label" "Tutorials")
      (dict "type" "how-to"      "label" "How-to guides")
      (dict "type" "explanation" "label" "Explanations")
      (dict "type" "reference"   "label" "Reference") -}}
{{- /* $kids: A's child set, sorted as A sorts it (weight, then title) */ -}}
<div class="opm-cards not-prose" data-pagefind-ignore>
  {{- with where $kids "Kind" "section" }}<ul class="opm-cards-list">{{ range . }}{{ template "opm-card" . }}{{ end }}</ul>{{ end -}}
  {{- range $groups -}}{{- $g := . -}}
    {{- with where (where $kids "Kind" "page") "Type" $g.type -}}
      <h2 class="opm-cards-heading" id="opm-cards-{{ $g.type }}">{{ $g.label }}</h2>
      <ul class="opm-cards-list">{{ range . }}{{ template "opm-card" . }}{{ end }}</ul>
    {{- end -}}
  {{- end -}}
</div>
{{- define "opm-card" -}}
  <li><a class="opm-card" href="{{ .RelPermalink }}">
    <span class="opm-card-title">{{ .LinkTitle }}</span>
    {{- with .Description }}<span class="opm-card-desc">{{ . }}</span>{{ end -}}
  </a></li>
{{- end -}}
```

- **Own markup, not Hextra's `cards` partial.** The partial's arguments are an internal API that changed across Hextra releases, and no hash guards it. A list of links is about 20 lines, reads correctly without CSS, and needs no theme copy.
- **`data-pagefind-ignore`.** Without it, every child's title and description would also make the section index a search hit, which doubles results.
- **Headings.** The template's `h2`s do not enter the TOC, which Hugo builds from the Markdown. The `opm-cards-` id prefix cannot collide with a heading id rendered from Markdown.
- **`not-prose` on the wrapper.** The cards most likely render inside `.content` (SP8 confirms where). There, Hextra's prose rules would give the lists bullets and padding and the links an underline and the primary colour, and Decision 2's `.content h2` (0,1,1) would give the group headings the page-h2 size and a 3rem top margin. Hextra's prose rules and Decision 2 all skip `not-prose` subtrees, so the class switches all of that off.

`cards.css` scopes every rule under `.opm-cards` (for example `.opm-cards .opm-cards-heading`, 0,2,0), so the rules also beat `.content h2` if the `not-prose` guard is ever lost, and apply wherever A calls the partial. The file lays the lists out as a responsive grid: one column on a phone, two from 48 rem. It sets its own list and link styles: no bullets, no padding, no underline, inherited text colour. Each card has a 1 px `gray-200` border (`neutral-800` in dark), a `gray-50` hover, a title at 600 weight and the description in `gray-600` at `.875rem`. The group heading is small (1rem, 600), so it does not compete with the page's own h2s. The section 3 PNG read checks the result; the scoping above is the guard.

**Supervisor-approved addition (2026-09-30).** catalog_opm 3cb3344 added the Extending how-to pages "Write a resource" and "Write a blueprint". The site-owned overview `site/content/docs/extending/_index.md`, whose description is now its lead, its card text on the docs home and its search sub-line, still named only traits, transformers and catalogs. Its `description` becomes "Add your own resources, traits, blueprints, transformers and catalogs when the built-in ones are not enough." (one line, same voice). Section 3 was committed before the request, so the edit rides section 4's commit, which is also about the description's roles. The file is outside the Touches in proposal.md; the supervisor asked for it.

### 6. Search: the description as the sub-line, crumbs below the docs root

`content-begin.html`, crumbs: skip home and the page's first section (the docs root), so a result reads "Start here" and not "Documentation / Start here". A page at the docs root gets no crumbs. Inline meta runs to the end of the attribute, so a title with a comma is safe.

```go-html-template
{{- if not .IsHome -}}
  {{- $root := .FirstSection -}}{{- $crumbs := slice -}}
  {{- range .Ancestors.Reverse -}}{{- if and (not .IsHome) (ne . $root) -}}
    {{- $crumbs = $crumbs | append (partial "utils/title" .) -}}
  {{- end -}}{{- end -}}
  {{- with $crumbs }}<span hidden data-pagefind-meta="crumbs:{{ delimit . " / " }}"></span>{{ end -}}
{{- end -}}
```

`opm-pagefind.js`: the match that is the page itself (its route equals the page URL, with no fragment), or the single match when there are no sub-results, shows `meta.description` when the page has one. Matches that point at a heading keep the Pagefind excerpt. Pagefind cannot say where a hit landed, so "the page-level match shows the description" is the testable stand-in for "a title hit". The `window.hextraSearch` contract (`preload`, `search`) is unchanged.

```js
const desc = page.meta && page.meta.description;
// in the matches map:
content: desc && sub.url === page.url ? desc : text(sub.excerpt),
```

### 7. Landing: the figure in the right half

The top of the hero becomes two columns from 64 rem: text and actions on the left, `{{< opm/module-to-cluster >}}` on the right. On a phone the figure comes after the actions. The feature grid stays inside `.opm-hero`, below the two columns. The three feature cards lose their inline `style=` gradients, and in `landing.css` their title drops to 1rem/600 and their text to .875rem `gray-600` with `text-wrap: pretty`. The text itself does not change.

```html
<div class="opm-hero">
  <div class="opm-hero-main">
    <div class="opm-hero-text"><!-- badge, headline, subtitle, .opm-hero-actions: unchanged --></div>
    <div class="opm-hero-figure">{{< opm/module-to-cluster >}}</div>
  </div>
  <!-- hextra/feature-grid with the three feature-card shortcodes, no style=: still inside .opm-hero -->
</div>
```

```css
.opm-hero-main { display: grid; gap: 2rem 3rem; }
@media (min-width: 64rem) {
  .opm-hero-main { grid-template-columns: minmax(0, 1fr) minmax(0, 26rem); align-items: center; }
}
.opm-hero-figure .opm-fig { margin: 0 auto; }
```

The two columns live in a new inner `.opm-hero-main`, not on `.opm-hero`. The prototype's hero rules, which A ports into `landing.css`, are `.opm-hero { width: 100%; max-width: 72rem; margin-inline: auto }`, `.opm-hero .hextra-feature-grid { width: 100% }` and `.opm-hero .hextra-feature-card { min-height: 10rem }`. Making `.opm-hero` the grid, or moving the feature grid out of it, would orphan the last two rules. The grid would then lose the card height and stop sharing the hero's 72rem width and centring inside `hextra-home.html`'s `hx:items-start` flex column. With the inner wrapper, all three rules keep applying unchanged. If A's landing markup or rule names differ, keep the feature grid inside whatever wrapper carries A's width and centring, and re-scope the moved rules in `landing.css` to it.

The figure enters through the existing shortcode, as the overlap table in plan-final.md section 1.5 says. Shortcode output bypasses goldmark, so this works under either of A's comment-stripping mechanisms. If A chose goldmark `unsafe = false`, the landing's wrapper markup lives in the one layout or partial A's design.md names. This change then edits that file for fix 6 only, and the report names it. The figure's internals, `figures.css` and the shortcode stay C's.

### 8. Breadcrumb: an override copy with `nav`, a list and `aria-current`

CSS cannot add landmark or list semantics, so this is a copy of Hextra's `_partials/breadcrumb.html`. The copy keeps the upstream `breadcrumbs` front-matter switch and the upstream utility classes for colour. It drops `overflow-hidden` and `whitespace-nowrap` from the wrapper, and adds the `opm-crumbs` class.

```go-html-template
<nav aria-label="Breadcrumb" class="opm-crumbs hx:mt-1.5 hx:text-sm hx:text-gray-500 hx:dark:text-gray-400 hx:contrast-more:text-current">
  <ol>
    {{- range $page.Ancestors.Reverse }}{{ if not .IsHome }}
      <li><a href="{{ .RelPermalink }}">{{ partial "utils/title" . }}</a>{{- /* upstream chevron icon, aria-hidden */ -}}</li>
    {{- end }}{{ end }}
    <li><span aria-current="page">{{ partial "utils/title" $page }}</span></li>
  </ol>
</nav>
```

`toc.css` (the navigation-aids file: TOC, breadcrumb, drawer):

```css
.opm-crumbs ol { display: flex; align-items: center; gap: .25rem; list-style: none; margin: 0; padding: 0; min-width: 0; }
.opm-crumbs li { display: flex; align-items: center; gap: .25rem; min-width: 0; white-space: nowrap; }
.opm-crumbs [aria-current="page"] { font-weight: 500; color: var(--hx-color-gray-700); }
html.dark .opm-crumbs [aria-current="page"] { color: var(--hx-color-gray-100); }
@media (max-width: 47.99rem) {
  .opm-crumbs ol { flex-wrap: wrap; row-gap: .25rem; }
  .opm-crumbs li { white-space: normal; }
  .opm-crumbs li:first-child:not(:last-child) { display: none; }   /* the docs root */
}
```

Below 48 rem the crumbs wrap, so no crumb is ever clipped, and the docs-root crumb is hidden (it is also the sidebar's first row). On the docs root itself the only crumb is the current page, which stays visible. The breadcrumb stays in the page chrome, outside `.content`, so search does not see it.

### 9. Drawer: a copy of `sidebar.js` that scrolls only when the active item is out of view

The copy changes one function. When the active item lies inside the sidebar's visible box, it does not scroll, so the drawer opens at its top with the section root visible. When the item lies outside, it keeps upstream's placement: the item's top one row below the box's top. The item's h2 list (`ul.opm-sb-toc`, shown under it on phones and, from section 2, at 768-1279 px) then stays visible below it. The drawer's closed-state transform moves both boxes equally, so the comparison holds.

```js
function scrollToActiveItem() {
  const box = document.querySelector("aside.hextra-sidebar-container > .hextra-scrollbar");
  const item = Array.from(document.querySelectorAll(".hextra-sidebar-active-item"))
    .find((el) => el.getBoundingClientRect().height > 0);
  if (!box || !item) return;
  const b = box.getBoundingClientRect(), r = item.getBoundingClientRect();
  if (r.top >= b.top && r.bottom <= b.bottom) return;               // in view: keep the section root
  box.scrollTo({ behavior: "instant", top: box.scrollTop + r.top - b.top - item.clientHeight }); // upstream's placement
}
```

The usability judge sketched `scrollIntoView({block: 'nearest'})` for the out-of-view case. That stops with the item on the bottom edge, and hides its h2 list below the fold, so the copy keeps upstream's near-top placement there instead. Trade-off, accepted: an item that fits near the bottom of the first screen does not scroll, so its h2 list may start below the fold; there the section root wins.

Alternatives considered:
- A site script that resets the scroll when the hamburger opens. It would run after Hextra's scroll (a visible jump), and it would join `main.js` through the same `js/core/*.js` glob with no hash guarding it.
- A sticky root row in `sidebar.html`. It keeps one row in view but not the section, and it costs height on a phone.

The copy is guarded like every other override, so an upstream change fails the build until someone diffs it. `sidebar.html` stays untouched unless the spike shows A's markup lacks the two selectors above; then the edit is limited to restoring them (fix 8 only).

### 10. Tests and shots

Each addition is its own test function or extras entry in `site/tests/browser/`, so it does not collide with B's per-version search work.
- **Search smoke.** Query "Quickstart". The result whose route ends in `docs/start/quickstart/` shows, as its page-level sub-line, the text of `p.opm-lead` in the built `site/public/v1.0/docs/start/quickstart/index.html`. No result's crumbs start with the docs root's title (read from the built `/v1.0/docs/` h1). A heading-level match still shows an excerpt.
- **A11y smoke.** On `/v1.0/docs/start/quickstart/` at desktop and 390 px: `nav[aria-label="Breadcrumb"]` holds exactly one `[aria-current="page"]`, whose text equals the h1. At 390 px, no displayed `.opm-crumbs li` has `scrollWidth > clientWidth`. A's axe run still reports 0 violations.
- **Drawer smoke.** At 390 px with the drawer open. On the quickstart, whose entry fits the first screen, the scroll box's `scrollTop` is 0 and the section root's link lies inside its visible rect. On the last page in `site/.check/v1.0/nav-order.txt` that has an h2, the active entry lies inside the visible rect; when the box scrolled (`scrollTop > 0`), the first link of the entry's `ul.opm-sb-toc` does too.
- **Shots.** One extra at 1024 x 768 of `/v1.0/docs/start/quickstart/` (the sidebar TOC), and one phone shot of the same page with the drawer open. Add each only if A's extras lack it.
- **Landing shots.** A's tasks (4.2) plan the landing in all six variants, and the 9 px floor should reach its figure once section 5 adds it. Neither is certain: the prototype's `shots.py` shoots a hard-coded page list, and runs its figure checks on one fixed figure URL. SP10 checks A's merged `shots.py`. If the landing is missing in any variant, or the floor does not run on it, section 5 adds a landing extras entry that does both.

## Research & Decisions

### Which fixes, and from where
**Context**: plan-final.md scopes D as "the eight fixes from `hugo-themes/README.md`, plus the breadcrumb `nav`/`aria-current` a11y fix".
**Explored**: `research/docs-site-stacks/hugo-themes/README.md` (the eight), and the two judges' `fixes_for_winner` in `raw-results.json` (visual: 12 items; usability: 12 items, with CSS and template sketches).
**Decision**: Build the eight plus the breadcrumb semantics. Where a judge's sketch serves one of the eight, take it (lead before the badge, the 80 rem TOC gap, the page-level description sub-line, the drawer scrolling only when the active item is out of view, dropping the landing's glow gradients). The judges' other items are follow-ups (Non-Goals).
**Rationale**: The eight are the agreed list and the 5-9 h budget in plan-final.md. The extras each add a decision the owner has not seen.

### Where the lead sits against Pagefind's root
**Context**: Pagefind indexes only `main#content > .content` (orchestration.md trap 11), and plan-final.md requires the lead to sit "deliberately inside or outside" it.
**Explored**: the prototype's `docs-main.html` (the hook renders inside `.content`), and Pagefind's metadata docs (element form, inline form "captured to the end").
**Decision**: Inside, indexed, and the element is the `description` metadata (Decision 1). The cards are ignored (Decision 5).
**Rationale**: The description is the search snippet by 0018:D7; one element serving both uses cannot drift.

### Drawer scroll mechanism
**Context**: The drawer opens scrolled past the section root (usability judge, `mobile-menu-open-dark.png`).
**Explored**: Hextra's `core/sidebar.js` (`scrollToActiveItem`), `core/menu.js` (the drawer is the sidebar container, moved by transform), and `scripts/core.html` (concatenates `js/core/*.js`).
**Decision**: A hash-guarded copy of `sidebar.js` that scrolls only when the active item is out of view, and then keeps upstream's near-top placement (Decision 9).
**Rationale**: It fixes the scroll where it happens, with no second scroll and no unguarded file. The near-top placement keeps the page's h2 list visible when the item is below the fold.

### Spike (section 1): assumptions to check on A's merged tree and Hextra v0.13.0
**Context**: Everything above was read at Hextra 275e2ad and in the prototype, not in A's merged tree.
**Explored**: Section 1 of tasks.md, on A's merged tree (origin/main e7d07b4) and the built `site/public/`, 2026-09-30. One line per item:
- SP1. Differs in names only. `site/assets/css/opm/` holds `base`, `brand`, `cards`, `chrome`, `figures`, `landing`, `sidebar`, `skin` and `versions.css`. `cards.css` (A's `.opm-children` list) and `landing.css` (A's `.opm-hero` rules, as Decision 7 quotes them) exist; `typography.css` and `toc.css` do not, so this change creates them. Lexical order puts `sidebar.css` and `skin.css` before `toc.css`, and `typography.css` after `chrome.css`.
- SP2. Confirmed. In `v1.0/docs/start/quickstart/index.html` the badge (`div.hextra-badge.opm-type-badge`) and the crumbs span sit inside `main#content > div.content`, after the h1 row. A has no copy of `hextra-home.html`; v0.13.0's calls `custom/content-begin.html` at line 10, inside `div.hx:flex.hx:flex-col.hx:items-start`, outside any `.content`. On the landing the badge dict matches no type and the crumbs are `.IsHome`-guarded, so the hook prints nothing there today.
- SP3. Confirmed. An alert is `div.hextra-alert[data-alert=tip]` > `p.hextra-alert-title` (`svg.hextra-alert-icon`, `span.hextra-alert-title-text`) + `div.hextra-alert-content`. Hextra's component and prose rules are not in a cascade layer (only `theme`, `base` and `utilities` are), so specificity and order decide, as Decisions 2 and 3 assume. Defined: `gray-50`..`900`, `primary-50`..`900`, `red-400/500/600`, `neutral-200`..`900`; missing: `green-600` (green has 100, 200, 900) and `amber-600` (amber has 50, 100, 200, 500, 900, 950). Tip and warning stay literal tokens; every other variable this design names exists.
- SP4. Confirmed. `nav.hextra-toc` carries `hx:hidden hx:xl:block`; `core/toc-scroll.js` sets `hextra-toc-active` and `aria-current="location"`; Hextra's `toc.css` sets only the colour, with `!important`. Rail links are `a.hx:inline-block.hx:w-full` inside `li`.
- SP5. Confirmed. A's `sidebar.html` prints `ul.opm-sb-sub.opm-sb-toc.hx:md:hidden` under the active leaf; its rules are in `sidebar.css` (`display: none`, `flex` below 48 rem), which sorts before `toc.css`, so Decision 4's selector needs no extra specificity.
- SP6. Confirmed. v0.13.0's `_partials/breadcrumb.html` is a `div` of `div`s with `hx:overflow-hidden`, per-crumb `hx:whitespace-nowrap hx:overflow-hidden hx:text-ellipsis`, and no `nav`, list or `aria-current`.
- SP7. Confirmed. v0.13.0's `core/sidebar.js` runs `scrollToActiveItem()` on `DOMContentLoaded` with the selectors `aside.hextra-sidebar-container > .hextra-scrollbar` and `.hextra-sidebar-active-item`; `scripts/core.html` concatenates `resources.Match "js/core/*.js"`, so a site file at that path shadows the theme's.
- SP8. Confirmed. `opm/docs-main.html` calls `opm/section-children.html` on section pages inside `div.content`, after `.Content`. A's list is already `ul.opm-children.not-prose` with `data-pagefind-ignore="all"`; the cards keep that value (it also drops metadata, and the cards carry none). A chose comment-stripping mechanism (b) (`minifyOutput`, goldmark `unsafe = true`), so the landing markup is `site/content/_index.md`.
- SP9 (section 4, by the search smoke test). Confirmed: for "Quickstart" the quickstart's page-level sub-result has the route `/v1.0/docs/start/quickstart/`, with no fragment, and the palette shows the lead as its sub-line. It also found that no page has a heading-level sub-result, for any query: Pagefind builds one only for a heading that carries its own `id`, and Hextra's `_markup/render-heading.html` puts the id on a nested `span` (the scroll offset). Every match is therefore page-level, so every result shows its description and none shows an excerpt. The test's heading clause becomes "every match shows a sub-line, and a heading match (none today) keeps its excerpt". Making headings visible to Pagefind would need a heading render-hook override, outside this change: reported under `follow-ups`.
- SP10. Confirmed, no fallback needed. `shots.py` shoots the landing as an extra in all six variants, and `figure_pages()` scans every `index.html` of the version (the landing's included) for a drawn figure and applies the 9 px floor to each, not to a fixed list. Once the landing draws ModuleToCluster it becomes a figure page too, so task 5.3 adds nothing.
- SP11. Confirmed, no follow-up. A's `check-overrides.sh --update` re-pins `awk 'NF { print $2 }'` of `overrides.sha256`, the paths already listed, so the two lines this change appends survive a later re-pin.
**Decision**: Proceed with Decisions 1-10 as written when every item holds. Adapt within this change when an item differs only in a class or file name. Stop and report when an item differs in a way that changes a decision or touches another change's files (orchestration.md section 7, step 5). SP10 and SP11 name their own fallback (a task in section 5; a line under `follow-ups`), so neither stops the change.
**Rationale**: Section 1 is a spike because these are unverified.
- SP1. The four CSS files exist in `site/assets/css/opm/`. If one is missing, this change creates it; the glob picks it up.
- SP2. `custom/content-begin.html` renders inside `main#content > .content` in the built HTML. Also: whether the landing's layout (Hextra's `hextra-home.html`, or A's copy) calls the hook too. Decision 1's `.IsHome` guard holds either way; the check tells the implementer which pages any later hook addition reaches.
- SP3. v0.13.0 renders alerts as `.hextra-alert[data-alert=...]` with `.hextra-alert-icon`. Also: which of the `--hx-color-*` variables this design names the vendored CSS defines (it is purged; at 275e2ad `green-600` and `amber-600` are missing).
- SP4. `nav.hextra-toc` is still `hx:xl:block`, and `core/toc-scroll.js` still sets `hextra-toc-active`.
- SP5. A's sidebar prints `ul.opm-sb-sub.opm-sb-toc`, and the file holding A's sidebar CSS sorts before `toc.css`.
- SP6. v0.13.0's `_partials/breadcrumb.html` is still a `div` with no `aria-current`.
- SP7. v0.13.0's `core/sidebar.js` still has `scrollToActiveItem`, with the selectors Decision 9 uses.
- SP8. Where A calls `opm/section-children.html` from, and where the landing markup lives (A's comment-stripping mechanism).
- SP9. A Pagefind sub-result for the page's own top section carries the page URL with no fragment.
- SP10. A's `site/tests/browser/shots.py` shoots the landing in all six variants, and applies the 9 px floor to every shot page with an SVG, not to a fixed figure list. If either is missing, task 5.3 adds a landing extras entry.
- SP11. A's `site/scripts/check-overrides.sh --update` re-pins the paths already listed in `site/overrides.sha256`, not a fixed list in the script. The prototype's script rebuilds the file from a fixed list, so a later `--update` would silently drop the two lines this change appends, and leave both copies unguarded. If A kept the fixed list, report it under `follow-ups` for the supervisor. `check-overrides.sh` is not in this change's Touches, so this change never edits it.

## Risks / Trade-offs

- [Pagefind root changes (trap 11): the lead adds indexed text and the cards could double results] -> The lead is indexed on purpose, the cards carry `data-pagefind-ignore`, and the search smoke test runs in every section.
- [Site CSS against Hextra's (trap 12): layers, `!important` and specificity] -> Selectors match or beat Hextra's specificity and load after it. Colour changes use computed `--hx-color-*` values, never `--primary-lightness`. The spike checks computed styles on a built page.
- [Drift guard (trap 14): two new copies] -> Copy the vendored v0.13.0 file, append its upstream hash line to `site/overrides.sha256` by hand, and never re-pin another line or run `check-overrides.sh --update`. If upstream changes either file, the build fails until someone diffs it. SP11 checks that a later `--update` keeps the two lines; if it would drop them, the report says so.
- [Internal contracts (trap 15): `sidebar.js` relies on `.hextra-scrollbar` and `.hextra-sidebar-active-item`; the adapter relies on `window.hextraSearch`] -> Both are hash-guarded, and the QA drawer shot and the search smoke test exercise them. Hextra v0.14 or the #1006 sidebar rewrite is not adopted here.
- [No active item in the 768-1279 px sidebar TOC] -> Accepted. Hextra's scrollspy watches only `.hextra-toc`, and a second scrollspy is new code for a middle width. The list still gives in-page navigation, which was missing entirely.
- [The docs-root crumb is hidden on phones] -> It is also the sidebar's first row and the navbar's Docs link, so nothing becomes unreachable.
- [A `var()` naming a colour Hextra's purged CSS does not define paints nothing, and no check fails] -> The spike (SP3) lists the defined variables, and missing ones become literal tokens (Decision 3). The shots are read for each role colour.
- [Contrast] -> The lead uses `gray-600`/`gray-400`, and alert text keeps the body colour. axe runs light and dark in `task qa`, and must stay at 0 violations.
- [A page body that restates its description now shows it twice] -> A content follow-up in the owning repo; this change edits no source page (Principle I).
- [Wave-2 overlap] -> `content-begin.html` and `docs-main.html` are D's alone. The search smoke file is shared with B, so each change adds its own test functions. `overrides.sha256` is append-only (on a merge conflict, keep every line). README changes stay under D's own heading. Branches update by `git merge origin/main`, never by the forbidden history-rewriting commands (trap 34).
- [The supervisor refreshes the `site-src` worktrees after later source merges (orchestration.md section 5), so a before set taken in an earlier session can differ for source reasons alone] -> The before set records the six `site-src` SHAs. A comparison runs only while they match; otherwise the before set is re-taken on the current sources first (tasks.md, Gates).
- [Builds read stale trees (trap 25) or create a root-owned directory (trap 22)] -> Every build runs with `OPM_SRC_WORKTREE=site-src`, after checking that the six `site-src` worktrees exist.

## Interface (orchestration.md section 6)

- **Relies on.**
  - Tasks: `task check`, `task ci`, `task qa` (shots, a11y and search), `task build`; `OPM_SRC_WORKTREE`; `SITE_PORT` 1316, only if `task serve` or `task preview` is needed.
  - Outputs: `site/public/` and `site/.shots/`; `site/.check/v1.0/nav-order.txt` as a regression observable.
  - CSS: the glob concatenation in `_partials/custom/head-end.html`.
  - Partials: `_partials/opm/docs-main.html`, `_partials/custom/content-begin.html`, `_partials/opm/section-children.html`, `_partials/sidebar.html`.
  - Pagefind: the root selector `main#content > .content`, and the `opm/module-to-cluster` shortcode.
  - Checks: every check in the list, the drift guard among them.
- **Adds.** Two override copies with their `overrides.sha256` lines, the Pagefind `description` metadata, and the classes `opm-lead`, `opm-cards*`, `opm-crumbs` and `opm-hero-*`. None of these is a section-6 interface name, and no section-6 name changes.

## Section plan

| Section | Fixes | Commit |
|---|---|---|
| 1 | spike; 1, 2, 7 | `feat(site): lead with the description and lighten the type` |
| 2 | 3 | `feat(site): show the table of contents from 768 px with a visible active item` |
| 3 | 4 | `feat(site): list child pages as cards grouped by type` |
| 4 | 5 | `feat(site): show descriptions in search results` |
| 5 | 6, 8, breadcrumb a11y | `fix(site): rebuild the landing's right half and fix the mobile breadcrumb and drawer` |

## Durable decisions

Each lands in `README.md` under a new `## Page design` heading, in the section that introduces it.
1. The `description` is shown three times: as the page lead, as the page's card text on its section index, and as its search sub-line. Page authors write it as one plain sentence that stands alone. (Section 1.)
2. The TOC shows as the right rail from 80 rem, and as the page's h2 list under its sidebar entry below that. The breadcrumb wraps and hides the docs-root crumb below 48 rem. (Sections 2 and 5.)
3. Section index pages list their children as generated cards: subsections, then pages grouped by type (tutorial, how-to guide, explanation, reference), each ordered by `weight`, then title. Nobody writes a child list by hand. (Section 3.)
4. Search: the lead is indexed and is the `description` metadata; the cards are `data-pagefind-ignore`; the crumbs start below the docs root. A change to the DOM under `main#content > .content` keeps these three true and keeps the search smoke test green. (Section 4.)
5. The override copies `_partials/breadcrumb.html` (Hextra's breadcrumb has no `nav` or `aria-current`) and `assets/js/core/sidebar.js` (the drawer scrolls only when the active item is out of view) exist for those reasons. Delete each when upstream fixes it. (Section 5.)

## Open Questions

None that change the approach. The spike items above are checks with a stated fallback, not open questions.
