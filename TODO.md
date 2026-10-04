# TODO - opmodel.dev

Documentation site implementation status and roadmap.

> **The site is Hugo + Hextra v0.13.0 (neutral skin).** It builds, serves and is tested only in its Docker images (`site/Dockerfile`, `site/tests/browser/Dockerfile`).

## ✅ Completed (Phase 0: Scaffold)

### Repository & Structure
- [x] Repository created at `open-platform-model/opmodel.dev`
- [x] `.gitignore` configured for build output and generated files
- [x] `README.md` with architecture overview
- [x] `AGENTS.md` with standards and patterns
- [x] `Taskfile.yml` with build automation

### Hugo Site
- [x] Hugo + Hextra v0.13.0 (vendored, neutral skin); site-owned pages in `site/content/`, the rest assembled from six source repos' signed docs bundles
- [x] Docker build image; `task serve`, `task build`, `task preview` run in it, builds with no network
- [x] One version, `v1.0` (beta), under `/v1.0/`: `/latest/` alias, per-version Pagefind search, page-set and output checks; the page dialect is linted by `opm-docs pull` (docs-kit C11)

---

## 🚧 Phase 1: Core Pipeline (MVP)

**Goal**: Publish reference generated from source, beside the authored pages.

### 1.1 - Generated reference (in the owning repositories)

Since 2026-10-02 the site generates nothing: each repository generates its reference pages from its own source and commits them under `docs/site/reference/`, with a staleness check there. The removed `docgen` tool read the retired v0 catalog.

- [ ] cli: every `opm` command and flag, at `/docs/reference/cli/`
- [ ] opm-operator: the four operator resources, at `/docs/reference/operator-resources/`
- [x] catalog_opm: one page per abstraction member, now the Catalogs tab, built from signed docs bundles (openspec `add-catalogs-tab`)
- [x] Remove the Catalogs transition (the mount exclusion of catalog_opm's Reference copies of the members, the two-entry legacy link map and the build's listing), 2026-10-03, after catalog_opm#127 deleted the pages and cli#280 and opm#20 replaced the last old links
- [ ] core: the definitions, at `/docs/reference/definitions/`
- [ ] Delete the site's `placeholder: true` pages once every version has its source page

### 1.4 - Theme Selection & Integration

- [x] Hugo + Hextra v0.13.0, neutral skin, chosen 2026-09-30 (it replaced Astro + Starlight with the Black theme, chosen 2026-09-24)

### 1.5 - Local Build Verification

- [x] `task build` produces the complete site in `site/public/`
- [x] Manual verification: `task preview`, browse http://127.0.0.1:1313/

---

## 📦 Phase 2: Full Coverage

**Goal**: Write guides.

### 2.4 - Hand-Written Content

#### Getting Started
- [ ] Installation guide (expand stub)
- [ ] Quick start tutorial
- [ ] Core concepts overview
- [ ] Your first module (step-by-step)

#### Guides
- [ ] Module authoring guide
  - [ ] Components, Resources, Traits
  - [ ] Module structure best practices
  - [ ] Testing modules locally
- [ ] Platform operations guide
  - [ ] Deploying modules
  - [ ] Managing releases
  - [ ] Troubleshooting
- [ ] Blueprint patterns guide
  - [ ] Stateless workloads
  - [ ] Stateful workloads
  - [ ] Databases
  - [ ] Custom blueprints

#### Reference
- [ ] Glossary (import from catalog)
- [ ] Personas (import from AGENTS.md)
- [ ] FAQ

---

## 🚀 Phase 3: CI & Publishing

**Goal**: Automate builds and deploy to production.

### 3.1 - CI Pipeline (GitHub Actions)

- [ ] Create `.github/workflows/build.yml`
  - [ ] Trigger on push to `main`
  - [ ] Trigger on schedule (daily rebuild for catalog changes)
  - [ ] Trigger on workflow_dispatch (manual)
  - [ ] Steps:
    - [ ] Checkout opmodel.dev repo
    - [ ] Build the site image (`task image`)
    - [ ] Build the site (`task build`)
    - [ ] Upload artifact (`site/public/`)

### 3.2 - Deployment

**Option A: GitHub Pages**
- [ ] Create `.github/workflows/deploy.yml`
- [ ] Configure GitHub Pages source (gh-pages branch or docs/)
- [ ] Add CNAME file for `opmodel.dev`
- [ ] Update DNS records

**Option B: Cloudflare Pages**
- [ ] Connect Cloudflare Pages to GitHub repo
- [ ] Configure build command: `task build`
- [ ] Configure publish directory: `public`
- [ ] Add custom domain `opmodel.dev`

**Option C: Netlify**
- [ ] Connect Netlify to GitHub repo
- [ ] Configure build command: `task build`
- [ ] Configure publish directory: `public`
- [ ] Add custom domain `opmodel.dev`

**Decision**: TBD based on infrastructure preferences.

### 3.4 - Versioning

- [x] Every version under `/<version>/`; one version today, `v1.0` (beta), built from each source repo's `main`
  - [x] `/latest/` alias and root redirect, per-version Pagefind search, a version label next to the title
  - [ ] Versions built from release tags, listed in a manifest, with a version switch and an outdated-version banner (change `version-site-from-tags`; how versions map to releases is 0021:OQ15)
  - [ ] Build multiple versions in CI
  - [ ] Component reference archive (every published core and catalog version; `/reference-archive/` is reserved)

---

## 🔮 Future Enhancements

### Documentation Quality
- [x] Search functionality (Pagefind, per version, in Hextra's palette)
- [x] Dark mode support (Hextra's theme toggle)
- [x] Mobile-responsive layouts (checked by the phone-width screenshots)
- [x] Accessibility smoke test (axe-core, WCAG 2.1 A and AA, `task qa`)
- [ ] Full accessibility audit (WCAG 2.1 AA)

### Content
- [ ] Video tutorials
- [ ] Interactive examples (playground)
- [ ] API playground for modules
- [ ] Blog for announcements/updates

### Tooling
- [x] Link checker (internal links fail the build; external links are not checked)
- [x] Broken reference detection (the link render hook fails the build on a missing page)

### Advanced Features
- [ ] Semantic search (vector embeddings)
- [ ] AI-powered question answering
- [ ] Automated changelog generation
- [ ] Module dependency visualizations
- [ ] Interactive CUE schema explorer

---

## 🐛 Known Issues & Blockers

| Issue | Status | Blocker? | Notes |
|-------|--------|----------|-------|
| CUE extraction not implemented | Open | Yes | Blocks Phase 1.1 |
| CLI doc generation not implemented | Open | Yes | Blocks Phase 1.2 |
| Catalog access in CI | Open | No | Submodule strategy for Phase 3 |

---

## 📊 Progress Tracking

- **Phase 0 (Scaffold)**: ✅ 100% complete
- **Phase 1 (MVP)**: ⏳ 0% complete
- **Phase 2 (Full Coverage)**: ⏳ 0% complete
- **Phase 3 (CI/CD)**: ⏳ 0% complete

**Next Immediate Steps**:
1. Generated reference in the owning repositories (Phase 1.1)

---

## 📚 References

- [Hugo content adapters](https://gohugo.io/content-management/content-adapters/)
- [Hugo](https://gohugo.io/)
- [Hextra](https://github.com/imfing/hextra)
