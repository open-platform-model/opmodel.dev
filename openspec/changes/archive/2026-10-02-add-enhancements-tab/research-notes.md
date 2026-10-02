# DESIGN (research agent)

## sourceShape
Repository: /var/home/emil/dev/open-platform-model/enhancements (public on GitHub, 11 MB of history, 372 commits, no CI workflow at all: .github holds only ISSUE_TEMPLATE/idea.yml).

Entries: 27 publishable entries, 18 live under NNNN/ (0004, 0005, 0007, 0008, 0009, 0012, 0013, 0014, 0017, 0018, 0020 to 0027) and 9 closed under archive/NNNN/ (0001, 0002, 0003, 0006, 0010, 0011, 0015, 0016, 0019). 0000/ is the scaffold template and must not be published. An entry moves from NNNN/ to archive/NNNN/ when it closes, so repo paths are not stable and ids are.

Per-entry file set (fixed by README.md and schema.cue): config.yaml (id, slug, title, summary, status, category, affects, core_schema, created/updated, authors, history[], depends_on/amends/supersedes/revives), delivery.yaml (append-only landing log), README.md (lede, bold-claim summary, a mandatory `## How it works` Mermaid diagram, scope, cross-references), then 01-problem.md through 07-questions.md. Optional: schemas/ (target.cue, examples.cue, spec.md), contracts/*.cue, experiments/NN-*/README.md plus code, research/*.md. Some entries add their own folders (0021/policy/ has 10 md files, 0018/drafts/ has 7). Markdown files carry no front matter; the title comes from config.yaml.

Counts: 364 md files in all; 27 READMEs plus 189 numbered documents make 216 core pages, about 400k words. There are also 88 experiment md, 17 research, 13 schemas md, 10 policy and 7 drafts. 1015 .cue files. Archive is 35 MB, and 30 MB of that is archive/0019/experiments. The largest decision files run past 60 KB.

INDEX.md and GRAPH.md are generated (`task index`, `task graph` in Taskfile.yml, using yq and scripts/delivery.sh) and committed. Each carries a `<!-- Generated ... -->` comment. INDEX has two tables (live, then archived) with id, category, affects, status, delivery, title and summary, plus a status legend. GRAPH.md holds 7 Mermaid `graph` blocks: an Overview of categories, then one per category (schema, runtime, distribution, tooling, misc). They use a fixed classDef palette with light fills and `color:#000`, about 100 nodes in all. Nothing checks freshness, and INDEX.md is stale on main today: regenerating it in a scratch copy flips 0021's delivery from not-started to in-progress. GRAPH regenerated identical. A machine-readable delivery TSV exists (`task delivery:data`) but is not committed.

Diagrams: Mermaid only. 36 fences: 7 in GRAPH, 1 in every entry README (27), plus 0018/02-design.md and 0027/02-design.md. There are no image files (no svg, png or jpg). ASCII diagrams sit in ```text or unlabelled fences (12 text fences, 139 unlabelled fences overall). `<br/>` appears inside Mermaid labels (32 hits). NNNN/diagrams/ is gitignored and local-only. A read-in-place build would see it, `git archive` would not.

Links (relative, outside fences): 618 in all. 339 point to .md files, 163 to directories (`../0008/`, `schemas/`, `experiments/03-.../`), 69 to .cue, 28 to .yaml and 9 to .txt. There are also 171 external links (89 to github.com). 14 are broken today:
- 0021/policy/02 and 03 point at experiments/ and research/ relative to policy/.
- archive/0001/01-problem.md points at ../../core/*.cue (workspace paths).
- archive/0015 and archive/0016 READMEs point at ../INDEX.md and ../GRAPH.md, which are off by one level after archiving.
- 1 is a false positive from a regex.

Content risks for publishing:
- 14 files contain HTML comments (spec.md headers, 0018/drafts templates, the INDEX/GRAPH headers).
- No `{{<` shortcode text today.
- config.yaml `authors` holds a personal email address in 0004, 0005 and 0007.
- history[] events quote "User decision" lines.
- Nothing is marked private (the repo is already public).
- .claude/ and .gates/ are tooling, not content.

## siteShape
Read from the local checkout plus origin/main by `gh api`. The local opmodel.dev checkout is behind: PR 11, "build site versions from release lines", merged 2026-10-01 18:22 and is not fetched locally.

Assembly: one Hugo 0.167 build, Hextra v0.13.0 vendored (themes/hextra.COMMIT adf732f), run in the Docker build image with `--network none`. Hugo's versions dimension is used with defaultContentVersionInSubdir = true. scripts/gen-mounts.sh writes config/production/module.toml from the resolved versions:
- site/content mounted into every version (sites.matrix versions = all);
- .gen/<v>/ mounted per version;
- each of the six repos' docs/site mounted at content/docs for its own version.

REPOS is hard-coded as "opm core catalog_opm cli library opm-operator" in build-all.sh, check-pages.sh and gen-mounts.sh. versions.conf (on origin/main) has v1.0 as a line version (cli-line = v1.0, catalog-line = opm-v4), resolved on every build by resolve-versions.sh. materialise.sh runs `git archive` into site/.versions/<v>/ and computes lastmod.tsv on the host. The build stamp records every ref and SHA, and frozen.conf allows a rebuild. Output: /<version>/..., /latest/ stubs, / redirecting to /latest/, and /reference-archive/ reserved for unversioned generated reference (the precedent for an unversioned top-level section).

Navbar: site/config/_default/hugo.toml [menus.main] has Docs (pageRef docs, weight 1), Reference (pageRef docs/reference, weight 2; Reference is just a subsection of docs), Search (3), GitHub (4) and Theme (5). Hextra's navbar puts a pageRef starting with "/" through relLangURL. The version label and switcher sit beside the title (_partials/opm/version-switch.html). The sidebar override roots at the current page's FirstSection, so a new top-level section gets its own tree.

Checks that would object:
- (1) lint-sources.sh, the page dialect, byte-identical to the workspace contract. It covers only <repo>/docs/site. It needs front matter, allows only /docs/... root-absolute links (so a direction note cannot link /enhancements/NNNN/ today), and bans images and shortcodes other than opm/ figures.
- (2) render-link.html resolves every internal link with GetPage in the current version and fails on a miss.
- (3) check-front-matter.html applies the four types (0018:D7) to every page backed by a file.
- (4) check-pages.sh pre/post: A1 collisions, reserved prefixes, Q2 page set and stray files, only under public/<v>/. Its link crawl covers every published HTML and CSS file.
- (5) Check 10: any `<!--` in published HTML, txt, md, xml or json fails, including the Markdown twins.
- (6) Check 11 (supply): every loaded URL must be relative or under BASE_URL, and any jsdelivr, unpkg, cdnjs, googleapis or gstatic string in HTML, JS or CSS fails.
- (7) Mermaid: hugo.toml says a mermaid fence fails the network-less build. Hextra's scripts/mermaid.html calls resources.GetRemote on cdn.jsdelivr mermaid@latest unless params.mermaid.js names a local asset. Hextra supports a local asset: with js set and no base, it uses resources.Get, fingerprints it and adds SRI.
- (8) `task shots` fails figure text below 9 px on a phone.
- (9) Pagefind runs once per version over public/<v>/. opm-pagefind.js loads `.Site.Home.RelPermalink`/pagefind/.

CSP: none today. deploy-site design.md lists a CSP as a possible follow-up, and _headers is planned only for noindex and caching.

CI (.github/workflows/site.yml on origin/main): three jobs (build, browser, sources-main), each checking out opmodel.dev plus six source repos. build and browser use fetch-depth 0. The nightly cron is 03:23. A source merge reaches the site only through the nightly build or a manual `gh workflow run Site`. pages-deploy publishes the interim GitHub Pages build under the /opmodel.dev/ base path.

0018 and 0021 constraints:
- 0018:D3 says future work appears only in a marked direction note on an explanation page, which links its enhancement, and drafts are never presented as forthcoming. One direction note exists in core/docs/site/concepts/application-and-platform-models.md.
- 0018 02-design gives the prose linter "decision numbers" as banned.
- 0018:D2 keeps SPEC.md unpublished partly because readers cannot resolve enhancement decision numbers.
- 0021 02-design says outright that enhancements are not versioned ("not artifacts consumers pin").
- 0021:OQ15's position is that docs follow the cli/operator MAJOR.MINOR, with an unversioned secondary section for per-component reference.

## proposal
Recommendation: one unversioned section at /enhancements/, built in the same Hugo run by a content adapter, with Mermaid vendored and loaded only on the pages that hold a diagram. I verified the two load-bearing Hugo behaviours in the local build image (scratch site under scratchpad/enh/hugotest*):
- a content adapter (_content.gotmpl) can read the enhancements tree mounted under assets/, parse config.yaml with transform.Unmarshal and AddPage the Markdown;
- `url` front matter, also through AddPage, publishes a page at /enhancements/... outside the /<version>/ prefix while it stays in the default version's page tree.

relURL "enhancements/" also comes out unprefixed in every version, so a navbar tab works from all of them. Permalinks config does not escape the version prefix; only `url` does.

1. Tab. Add a menus.main entry named Enhancements, pageRef '/enhancements', weight 3, between Reference and Search (shift the others). Hide the version label and switcher on pages whose FirstSection is enhancements, because those pages belong to no version.

2. URL layout, keyed by id and never by repo path, so archiving keeps URLs:
- /enhancements/ is the landing page: the INDEX, with live entries grouped by status and closed ones separate, and a link to the graph;
- /enhancements/graph/ is GRAPH.md;
- /enhancements/NNNN/ is the entry README, with a header taken from config.yaml (status, category, affects, created and updated, depends_on and amends as links). Archived entries get the same shape;
- /enhancements/NNNN/{problem,design,decisions,graduation,risks,operational,questions}/ are the seven documents, with weights 1 to 7.

Sidebar: one collapsible group per entry. Unversioned, per 0021. The adapter is mounted only into the default version (gen-mounts.sh knows it), so its pages move with the default version and keep their URLs. The section's _index must come from the adapter or a default-only mount, never from site/content, which is mounted into every version and would publish /enhancements/ once per version.

3. Source and freshness. Add the enhancements repo as an eighth, unversioned source. That means one new manifest stanza in versions.conf, for example `[section "enhancements"] ref = origin/main` (the manifest is the only list of build inputs), resolved to a SHA by resolve-versions.sh and recorded in build-stamp.json and frozen.conf. An `override = <sha> <reason>` serves as the escape hatch. materialise.sh runs `git archive` on only INDEX.md, GRAPH.md, */config.yaml, */README.md, */0[1-7]-*.md and the archive equivalents (so not 0019's 30 MB, not 0000/, and not the gitignored diagrams/) into site/.versions/enhancements/. Explicit mode reads OPM_SRC_ENHANCEMENTS in place. Dates come from config.yaml `updated` per entry, not from git per file.

CI: add the checkout to the build, browser and sources-main jobs. Freshness follows the existing model: the nightly build plus a manual dispatch. Later, an enhancements push could dispatch Site (this ties into enhancement 0028).

4. Rendering entries. The adapter:
- strips HTML comments;
- refuses `{{<` in content;
- passes repoPath and id as params;
- renders `authors` not at all (it holds an email) and history only as a collapsed list, or not at all.

An enhancements-only render-link hook maps links as follows:
- sibling NN-*.md goes to the slug page;
- README.md goes to the entry;
- ../NNNN/ and ../archive/NNNN/ go to /enhancements/NNNN/;
- ../INDEX.md and ../GRAPH.md go to the landing and the graph;
- any other path that exists in the archived tree (.cue, .yaml, directories, research/, experiments/) goes to github.com/open-platform-model/enhancements/blob|tree/<built SHA>/<repo path>;
- a target that does not exist fails the build, as Q1 does for docs.

A heading hook gives `### D3: ...` the stable id `d3`, so 0018:D3 can be cited as /enhancements/0018/decisions/#d3. OQ ids (list items, not headings) and auto-linking `NNNN:DN` tokens can come in phase 2.

Every page carries a non-dismissible status banner, marked data-pagefind-ignore. For draft or accepted entries it reads "Design proposal, status draft, delivery not-started: nothing here describes OPM as it works today", with matching wording for delivered, superseded and rejected. This is what keeps the tab within 0018:D3.

5. INDEX and GRAPH. Phase 1 renders the committed INDEX.md tables, wrapped for horizontal scroll and with links rewritten, and GRAPH.md as is. Do not reimplement delivery derivation in templates; it lives in scripts/delivery.sh. Owner-side precondition: an enhancements CI workflow that runs `task vet` and fails when `task index graph` would change the files. INDEX is stale today. Phase 2: the enhancements repo commits a data file (delivery:data plus config) so the landing page can show cards, filters and "2/36 decisions delivered".

6. Mermaid under the no-network and no-CDN rules. Vendor one pinned mermaid 11.x UMD build as site/assets/lib/mermaid/mermaid.min.js, set params.mermaid.js to it, record its version and SHA-256 next to it, and add its MIT licence to site/NOTICE. Hextra then loads it fingerprinted with SRI, only on pages where render-codeblock-mermaid set hasMermaid. That is about 29 pages: the 27 entry pages, 0018/design, 0027/design, plus the graph page.

I checked mermaid 11.17.2's mermaid.min.js: 3.5 MB, MIT, with no jsdelivr, unpkg, cdnjs, googleapis or gstatic string, so check 11 stays green. Hextra's init re-renders on the html.dark class change, so diagrams follow the site's toggle. The GRAPH classDefs force light fills with black text, which stays legible in dark mode.

Add an override of render-codeblock-mermaid.html that errors outside the enhancements section, so the docs keep the hand-drawn figure rule. Wrap diagrams in an overflow-x container with a minimum width for phones. Validate in the QA image: task qa loads every page with a diagram, waits for render, and fails on a Mermaid error SVG. The build image cannot parse Mermaid.

7. Search. A separate Pagefind index: `pagefind --site public/enhancements`, excluding .mermaid and the banner. The search partial picks the enhancements bundle on enhancement pages and the version bundle elsewhere, so docs search never returns draft designs. Keep enhancement pages out of llms.txt (open question).

8. Checks and lint exemptions:
- the enhancements tree is not a dialect source: lint-sources.sh is unchanged and does not scan it, and check-front-matter already skips file-less adapter pages;
- extend check-pages.sh with an enhancements page set (expected = 2 + 8 per entry, listed from the archived tree) and stray-file coverage for public/enhancements/;
- the link crawl and supply checks already cover it;
- add failing fixtures under site/tests/fixtures/ws/enhancements (a broken repo link, a comment leak, mermaid outside the section, a missing entry page), per "checks fail the build";
- exempt diagrams from the 9 px figure check, or apply a looser rule;
- the source/edit link partial needs an enhancement branch: "View source at <sha>" pointing at the repo path.

9. Docs linking into the tab, for the parallel direction-note work. Allow `/enhancements/NNNN/` (optionally with `#dN`) as a root-absolute destination. That is first a change to the workspace dialect contract, then the same change to lint-sources.sh. render-link must special-case /enhancements/ by checking a generated id list rather than GetPage, because older versions' page trees do not contain those pages. Until this ships, direction notes link the GitHub URL.

10. 0018 needs a new decision (it is a draft, so it can be edited in place): "The design record is published as an unversioned Enhancements section, apart from the docs and their search, with a status banner on every page. The docs reach it only through direction notes." The decision-number ban stays in docs prose.

Delivery: one OpenSpec change in opmodel.dev, in sections:
- (a) mermaid vendoring and gating;
- (b) source, manifest and materialise;
- (c) adapter, layouts and hooks;
- (d) search;
- (e) checks and fixtures;
- (f) CI checkouts;
- (g) the tab.

Two upstream prerequisites: enhancements CI (vet, link check, index/graph freshness) and a fix for the 14 broken links. Then a dialect-contract change for direction-note links.

## alternatives
A. Link the tab straight to GitHub (`url = https://github.com/open-platform-model/enhancements/blob/main/INDEX.md`). One line of config, and GitHub already renders Mermaid. You lose on-site styling, search, stable citation anchors, status banners and an on-site target for direction notes. This is the honest baseline: the recommended design is a full OpenSpec change with new checks and a 3.5 MB vendored script, and it is worth that only if direction notes and design citations are meant to stay on opmodel.dev.

B. Mount the enhancements into every version (/v1.0/enhancements/, /v1.1/enhancements/...) by adding one more matrix mount in gen-mounts.sh. This is the simplest wiring. But it duplicates the record once per version, URLs change when the default version changes, it contradicts 0021 ("enhancements are not versioned"), and it mixes drafts into each version's Pagefind index unless excluded. Rejected.

C. A second Hugo build (its own config environment) into public/enhancements/. This isolates it best: its own search, no version machinery, no risk to docs templates. Costs: a second config and menu to keep in sync, a second build pass, and links between the two builds that only the crawl can check (no GetPage across them). A reasonable fallback if the adapter-plus-url approach ever fights Hugo's versions dimension.

D. Convert on the host into dialect-like Markdown files (front matter added, links rewritten by a shell or awk script) under site/.gen/enhancements, mounted as content. This works without an adapter, but it means parsing YAML (folded scalars) and rewriting links in sh or awk, which is brittle. The adapter does the same work inside Hugo with transform.Unmarshal.

Mermaid options:
- M2: render to SVG at build time in the QA image (Chromium). This puts a 3.7 GB image on the build path and breaks "the build image is Hugo, Pagefind and git".
- M3: commit pre-rendered SVGs in the enhancements repo. This adds a Node/Chromium toolchain there and diagram drift.
- M4: draw GRAPH natively as site-engine SVG from config.yaml. This needs a layout algorithm, and it is not worth it for 7 diagrams.
- M5: show the Mermaid source as code with a link to GitHub. This loses the diagrams the user asked for.

Index options: render from config.yaml in templates, which is easy for status, category and title, but delivery state needs delivery.sh's logic, so that would duplicate it. Or regenerate INDEX/GRAPH on the host in materialise. That needs task, yq and bash on the host and in CI (ubuntu has yq), and it hides the upstream staleness instead of fixing it.

## risks
1. Reader confusion, against 0018:D3. A visible tab full of draft designs (0009's lifecycle and workflows, 0012, 0027) on the product site can be read as a roadmap or as features. Mitigations: the status banner, separate search, no enhancement content in docs search or llms.txt, and possibly noindex for draft and accepted entries. Without at least the banner and separate search, this tab undercuts the decision the docs were built on.

2. Build coupling to an ungated repo. The enhancements repo has no CI, so a push with a broken link, a stray HTML comment or a `{{<` turns every site run red: pushes, PRs and the nightly. The deployed site stays at the last good build. Mitigations: upstream CI first, plus the `override` SHA escape hatch. 14 broken links exist today and would fail a strict hook on day one.

3. Stale generated files. INDEX.md is already wrong for 0021 on main. Publishing it amplifies the error to readers until a freshness gate exists.

4. Mermaid: errors are invisible at build time and show only as a client-side error box, so they are caught only by the QA-image check. 3.5 MB of JS on diagram pages. The bigger GRAPH diagrams are hard to read on a phone and fail the spirit of the 9 px rule. A future CSP (the deploy-site follow-up) must allow Mermaid's inline SVG styles and Hextra's inline init script. The vendored file needs a re-pin process like the drift guard has. Bumping Hextra may change the mermaid partial's contract (initialize/run on v11).

5. Hugo behaviour reliance. `url` front matter escaping the version prefix is verified on Hugo 0.167 only. The content adapter, the section-scoped render hooks, and menu active state for a pageRef page in the default version only must be re-verified on each Hugo bump, and also in an older version, where the tab's pageRef page does not exist (test that it renders without a warning under --panicOnWarning).

6. Privacy and tone. config.yaml authors carry a personal email (0004, 0005, 0007) and history[] carries terse internal events. The repo is public, but the site gives them more reach. Do not render authors; render history only on request.

7. Scale. Around 218 pages plus their Markdown twins add build time and Pagefind size. Small, but every check that scales with page count (the link crawl, shots) grows.

8. Citation churn. Slugs (decisions/, questions/) and #dN anchors become public URLs that other repos and direction notes cite. Pick them once.

## openQuestions
- Is an on-site record worth the change (adapter, vendored Mermaid, new checks), or is a navbar link to the GitHub INDEX (alternative A) enough for now?
- Tab name: Enhancements (matches the repo and the `0018:D3` vocabulary), Design, or Proposals? And should it sit between Reference and Search?
- Which entries publish: all 27 (live plus archived), or live only, with archived entries reachable from the index? Rejected and superseded entries included?
- Which files per entry: README plus the seven documents only (216 pages), or also research/*.md, 0021/policy/*.md, schemas/spec.md and experiment READMEs? Everything else would link to GitHub at the built SHA.
- Indexing: should search engines index enhancement pages at all, or should draft and accepted entries carry noindex so a web search never presents a draft as OPM behaviour? Keep them out of llms.txt?
- Search: separate Pagefind index only, or also an opt-in 'include design record' toggle in the docs palette?
- Freshness: is the nightly build plus a manual dispatch enough, or should an enhancements push dispatch the Site workflow (ties into the release-cascade plan, 0028)?
- Do you accept adding enhancements CI (task vet, a relative-link check, INDEX/GRAPH freshness) as a prerequisite, and fixing the 14 broken links (0021/policy, archive/0001, archive/0015 and 0016 INDEX/GRAPH links) first?
- Where does the manifest record the enhancements ref: a new `[section "enhancements"]` stanza in site/versions.conf, or somewhere outside the versions manifest?
- Should the dialect contract allow docs pages (direction notes) to link `/enhancements/NNNN/` and `#dN` anchors? The parallel notes work needs a link target now: GitHub URLs until this ships?
- Stable anchors and auto-linking: should `0018:D3`-style tokens in enhancement prose become links to /enhancements/0018/decisions/#d3 (phase 2), and are the semantic slugs (problem, design, decisions, ...) acceptable as permanent URLs?
- Should 0018 gain a decision recording this section (it is a draft, so editable in place), and does the existing 0018:D2 rationale ('readers cannot resolve decision numbers') need its wording updated once they can?

# SPIKE

## tried
I made a detached spike worktree from the fetched origin/main (6d4a910) at /var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/enhancements-tab-spike. Nothing is committed or pushed, and the worktree is still there. All builds went through `task build`, `task shots` and `task test:site`. The browser checks ran in the QA image with `--network none`. Changes, all marked SPIKE:
- run-in-image.sh mounts the enhancements repo read-only at /src/enhancements. In this spike it is read in place, not materialised.
- gen-mounts.sh mounts /src/enhancements at assets/enhancements, and mounts site/enhancements/ (the content adapter plus a file-backed _index.md) into the first version only.
- site/enhancements/_content.gotmpl adds one page per entry and one per document (01-07), with `url` set to /enhancements/NNNN[/slug]/. It parses config.yaml with transform.Unmarshal.
- layouts/_partials/opm/enh-clean.html strips HTML comments and the leading H1, and refuses `{{<` and `{{%`.
- layouts/enhancements/{list,single}.html render through docs-main.
- Section-scoped hooks in layouts/enhancements/_markup/: render-link (repo path to page, or to GitHub, or broken), render-heading (adds a `dN` anchor and keeps the automatic id), and render-codeblock-mermaid (adds a scroller and a `useMaxWidth:false` init directive).
- A global layouts/_markup/render-codeblock-mermaid.html that fails the build.
- In hugo.toml: the menu entry and `params.mermaid.js`. Mermaid 11.17.2's mermaid.min.js is vendored under assets/lib/mermaid/.
- A status banner and metadata list in content-begin.html, the version label hidden on enhancement pages, and enhancements.css.
- Two check changes: check-front-matter skips adapter pages, and check 10's escaped-text half skips public/enhancements/.
- A browser script, site/tests/browser/enh_spike.py.

I also ran a strict-link build, a two-version build (`OPM_VERSIONS="v1.0=/src v0.9=/src"`), a build with a mermaid fence in a docs page, and the fixture suite.

## results
WHAT WORKED
- The content adapter, `url` front matter and the navbar tab all work on Hugo 0.167. The build publishes 218 pages under public/enhancements/, outside /v1.0/. The whole build passes in about 10 s; the Hugo step takes about 0.6 s.
- The Enhancements tab shows next to Docs and Reference on every page. It is active on every enhancement page (HasMenuCurrent resolves it). In a second version it renders with no warning under --panicOnWarning. The sidebar's FirstSection root gives an entry tree with no changes needed.
- The version label is hidden on enhancement pages, and the status banner renders.
- Mermaid works offline. It is vendored, fingerprinted with SRI, and loaded only on the 30 pages that hold a diagram; no docs page loads it.
- Check 11 (supply/CDN) and the link crawl pass in the full build.
- In the QA image all 36 diagrams on the 30 pages render to SVG at 1280 and 390 px wide. There were no Mermaid error SVGs, no console errors and no failed requests under `--network none`.
- The global mermaid hook fails a docs page with "mermaid fence in .../reference/_index.md: only the enhancements section may hold one". The section-scoped hook overrides it inside the section, as intended.
- The link hook maps 155 links to GitHub blob/tree URLs. In strict mode it lists all 10 broken links on published pages and fails the build:
  - 6 `../../core/*.cue` links in archive/0001/01-problem.md;
  - `../INDEX.md` and `../GRAPH.md` in archive/0015 and archive/0016 READMEs (archiving broke those relative links).
  The repo's other 4 broken links are in files that are not published (0021/policy/*, 0001's regex text).
- `/enhancements/0018/decisions/#d3` resolves, and the GitHub-style automatic anchors are kept too.

WHAT FAILED, AND WHICH CHECKS OBJECT
1. Front-matter check: it fires on every adapter page. Adapter pages DO have a `.File`: the `_content.gotmpl`. The errors were "missing title / description / type".
2. Check 10, the escaped half of the comment check: it fires on 34 pages. Every html-escaped `-->` matches `(--|&ndash;)&gt;`, and that includes Mermaid edges and ASCII arrows in code blocks (0016/design, 0019/problem).
3. Link crawl in the fixture suite: `task test:site` had 43 pass and 11 fail. Every fixture build lacks the enhancements source, so the navbar's `/enhancements` (or `/opm/docs/enhancements` under the subpath fixture) points at nothing. LINK FAIL then stops each fixture build before the check under test runs, so cdn-url, comment-*, raw-aside, redirect-files and supply-* all report "missing" output.
4. Section page: AddPage refuses it with "empty path is reserved for the home page". I fell back to a file-backed _index.md whose body (INDEX.md) is injected in content-begin. As a result the landing has no TOC, and its Markdown twin (Copy page) holds only the title, 16 bytes.
5. Diagram legibility: with Hextra's default `useMaxWidth`, 21 of 36 diagrams render labels under 9 px even on desktop, down to 3.9 px, because the content column is only 672 px. At phone width it is 23 of 36. Injecting `%%{init: {"flowchart":{"useMaxWidth":false}}}%%` brings every label to 16 px; diagrams then reach 2756 px wide inside a scroller.
6. axe (WCAG 2.1 AA):
   - dark mode fails color-contrast on Mermaid edge labels: 58 nodes on the graph page, 8 on 0018;
   - the scroller adds scrollable-region-focusable failures (6 on the graph page, 1 on 0018), so it needs tabindex=0.
   The light-mode landing and the decisions page are clean.
7. Leaks that happen by default:
   - all enhancement pages land in v1.0/llms.txt (190 lines) and in v1.0/sitemap.xml;
   - head-end writes 218 `/latest/enhancements/...` redirect stubs, because `.File` is set;
   - the edit link points at opmodel.dev/edit/main/site/content/enhancements/_content.gotmpl;
   - search on enhancement pages loads the v1.0 docs bundle, and the enhancement pages are in no index.
8. Two-version build: in the non-default version, the mobile sidebar's Enhancements link has an empty `href`. It comes from the site's sidebar override, which falls back to `.URL` when GetPage misses, and the link crawl ignores empty hrefs.
9. The navbar href is `/enhancements` with no trailing slash, because Hextra calls relLangURL on a pageRef with a leading slash.
10. The nav-order.txt in the default version gains `/enhancements/` as its first line.
11. Cosmetic issues:
   - the graph page sorts between 0001 and 0002 (equal weight);
   - a `#d3` jump hides the heading under the sticky navbar (the span has no scroll-margin);
   - the entry lead is missing, because `description` inside params does not set `.Description`;
   - the INDEX table is unusable on a phone: 7 columns that need horizontal scrolling.
12. Checks that stay silent and give no coverage: Q2 and stray-file look only under public/<version>/, so /enhancements/ is unchecked. a11y.py, search.py and shots.py look only at /<version>/ pages. lint-sources is unaffected. Check 9 (`:::`) passed even though GRAPH.md uses `:::class`.

## verdictOnProposal
The proposal is sound: one unversioned section, a content adapter, vendored Mermaid gated per page, and URLs keyed by id. Every load-bearing Hugo behaviour held, and Mermaid renders offline with no supply-check failure.

Three claims are wrong, and several defaults leak in ways the proposal does not cover.
- "check-front-matter already skips file-less adapter pages" is false: adapter pages report the adapter as their file.
- "The link crawl and supply checks already cover it" is half true. Check 10 objects to every diagram page. The link crawl turns the whole fixture suite red through the new tab link.
- The section `_index` cannot come from the adapter: AddPage refuses an empty path.

The default leaks are llms.txt, the sitemap, the /latest/ stubs, the edit link and the search bundle. The proposal names some of these as tasks but treats llms.txt as an open question; it is a must-fix.

The 9 px risk is understated. Without `useMaxWidth:false` most diagrams are unreadable even on desktop. With it, a phone reader sees one fragment of the diagram at a time, and dark-mode edge labels fail WCAG contrast.

None of this blocks the proposal. Section (e) "checks and fixtures" should grow, and "Mermaid gating" should include a sizing and theming rule.

## corrections
1. Section page: do not use the adapter for it. Have materialise.sh (or gen-mounts.sh) generate `_index.md`, with front matter plus the INDEX.md body cleaned of comments, into a default-only mount such as site/.gen-enh/enhancements/. Rendering INDEX through content-begin loses the TOC and the Markdown twin.
2. Front-matter check: add an explicit adapter exemption, `ne .File.BaseFileName "_content"` or FirstSection == enhancements, plus a fixture. Do the same in head-end's /latest/ stub condition, which otherwise publishes 218 stubs. Do the same in opm/source.html: it needs an enhancements branch, because today it emits a wrong opmodel.dev edit URL, not none.
3. Check 10: the escaped-comment regex has to ignore `-->` inside `<pre>` and `<code>`, or exempt public/enhancements/ and rely on the adapter's comment strip plus a source-side check. Add a fixture where a code block holds `-->` and must pass. Docs code blocks would hit the same false positive.
4. Tab link: make it conditional on the section existing. Options: a param written by gen-mounts.sh only when the enhancements source is mounted, or a test fixture that supplies a stub enhancements tree. Without this, every fixture build and any build without the enhancements repo fails the link crawl. Use pageRef `/enhancements/` with the trailing slash. Fix the sidebar override's mobile "extra" list, which emits an empty href when GetPage misses in a non-default version: use relURL of the pageRef. Expect nav-order.txt to change.
5. Exclusions: llms.txt and the sitemap must exclude FirstSection == enhancements, or set `sitemap.disable` per page from the adapter. This is not an open question; it happens by default. The search partial must choose another bundle, because today enhancement pages load the v1.0 docs bundle and no enhancement page is indexed.
6. Mermaid sizing:
   - inject `useMaxWidth:false` (the spike prepends an init directive in the section's codeblock hook; overriding Hextra's scripts/mermaid.html adds a drift-guard pin);
   - use a focusable scroller (tabindex=0, role and label) so axe passes;
   - fix dark-mode edge-label contrast (themeVariables, or force the light theme for diagrams);
   - add a QA rule that measures label px on every enhancement diagram.
   The spike measured 0 of 36 diagrams under 9 px with `useMaxWidth:false`, against 21 of 36 without it. "Exempt diagrams from the 9 px check" does not apply as written: shots.py only measures `figure:has(svg[role=img])`, so Mermaid diagrams are never measured. The rule has to be added, not exempted.
7. NOTICE: the mermaid UMD bundle carries DOMPurify (Apache-2.0 / MPL-2.0), d3 (ISC), lodash, cytoscape, katex, marked and others, not only Mermaid's MIT licence. Record the bundled licences. Also, mermaid 12.0.0 is now `latest` on npm (5.5 MB) and has not been checked against Hextra v0.13's initialize/run init. Pin 11.17.2 deliberately (SHA-256 581ed7d74bd9048d0e3a91363927d72ef22942d7722546b27f7cc29e35390eb8, 3.5 MB) and record the reason.
8. Link hook: refuse a resolved path that climbs out of the repo (a leading `..` after path.Join) before trying resources.Get. Day one shows 10 broken links on published pages, not 14. The `../INDEX.md` and `../GRAPH.md` links in archived READMEs are an archiving bug in the enhancements repo (`task archive` should rewrite them). The other 4 broken links are in files that are never published.
9. Adapter details:
   - pass `description` (the summary) at the top level, not in params, so the lead shows;
   - give the graph page a weight that does not collide with 0001;
   - title the seven documents with their entry, e.g. "0018: Decisions" for llms.txt and search, or carry the entry in breadcrumb metadata;
   - give the `dN` span a scroll-margin-top so `#d3` does not land under the navbar.
10. Phase 1 INDEX: the raw 7-column table is unusable at 390 px. Either drop columns (Affects, Summary) on the landing in phase 1, or bring the cards forward.
11. Coverage: Q2 and stray-file need a public/enhancements/ page set (218 pages here: 27 entries, their documents, and the graph). a11y.py, shots.py and search.py need enhancement pages. The spike's enh_spike.py is a starting point for the "wait for render, fail on error SVG" QA step.

Screenshot paths (the QA image, built from the spike):
- /var/home/emil/dev/open-platform-model/opmodel.dev/.claude/worktrees/enhancements-tab-spike/site/.shots-enh/
- report.json there holds per-diagram px, width, and axe results.

# OWNER DECISIONS 2026-10-01
- Full on-site build (not a GitHub link).
- Publish all 27 entries: 18 live + 9 archived, README + the seven numbered documents each.
- Draft and accepted entries carry noindex and stay out of llms.txt.
- Tab named Enhancements, next to Docs and Reference.
- Direction notes on What OPM does not do (opm) link GitHub now; switch to /enhancements/NNNN/ once the tab ships.