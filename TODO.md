# TODO - opmodel.dev

Documentation site implementation status and roadmap.

## ✅ Completed (Phase 0: Scaffold)

### Repository & Structure
- [x] Repository created at `open-platform-model/opmodel.dev`
- [x] Go module initialized (`go.mod`)
- [x] Hugo site structure created (`site/`)
- [x] Directory structure for content, layouts, data
- [x] `.gitignore` configured for Hugo and generated files
- [x] `README.md` with architecture overview
- [x] `AGENTS.md` with standards and patterns
- [x] `Taskfile.yml` with build automation

### Documentation Generator Scaffold
- [x] `cmd/docgen/main.go` - CLI with `schema`, `cli`, `all` subcommands (stubs)
- [x] `internal/cuedoc/extractor.go` - Package stub with types defined
- [x] `internal/cobradoc/generator.go` - Package stub
- [x] Cobra dependency added (`github.com/spf13/cobra`)

### Hugo Site Scaffold
- [x] `site/hugo.toml` - Hugo configuration with module support
- [x] Basic content pages:
  - [x] Home page (`_index.md`)
  - [x] Getting Started section
  - [x] Guides section
  - [x] Reference section structure
- [x] Content adapter template (`reference/definitions/_content.gotmpl`) - commented out
- [x] Hugo modules initialized
- [x] Site builds successfully (no layouts yet)

### Known Issues
- [ ] **Docsy theme disabled** - i18n file format incompatibility with Hugo 0.148.1
  - Docsy requires Hugo 0.146.0+ but has YAML format issues
  - Site builds with default Hugo renderer (no layouts)
  - Need to either fix Docsy upstream or switch to Hugo Book theme

---

## 🚧 Phase 1: Core Pipeline (MVP)

**Goal**: Generate basic reference docs from CUE catalog and CLI commands.

### 1.1 - CUE Schema Extraction

#### `internal/cuedoc` Implementation
- [ ] Implement `Extract()` function
  - [ ] Load CUE modules using `load.Instances()`
  - [ ] Walk definitions with `Value.Fields(cue.Definitions(true))`
  - [ ] Extract metadata:
    - [ ] Definition name, kind, FQN
    - [ ] Doc comments via `Value.Doc()`
    - [ ] Field iteration with `Value.Fields(cue.Optional(true))`
    - [ ] Field types via `Value.IncompleteKind()`
    - [ ] Constraints via `Value.Expr()`
    - [ ] Defaults via `Value.Default()`
    - [ ] Required vs optional via `Selector.ConstraintType()`
  - [ ] Handle cross-references:
    - [ ] Trait `appliesTo` references
    - [ ] Blueprint composition references
  - [ ] Output JSON per module to `site/data/schema/`

#### Testing
- [ ] Unit tests for CUE value extraction
- [ ] Test fixtures with sample CUE definitions
- [ ] Integration test with catalog `core/` module

#### Dependencies
- [ ] Add `cuelang.org/go` dependency
- [ ] Add `cuelang.org/go/cue/load` dependency
- [ ] Add `cuelang.org/go/cue/ast` for doc comments

### 1.2 - CLI Documentation Generation

#### `internal/cobradoc` Implementation
- [ ] Implement `Generate()` function
  - [ ] Import CLI root command as dependency
    - [ ] Add `github.com/open-platform-model/cli` to `go.mod`
    - [ ] Import `github.com/open-platform-model/cli/cmd/opm` package
  - [ ] Create Hugo front matter prepender function
  - [ ] Create link handler for cross-references
  - [ ] Call `cobra/doc.GenMarkdownTreeCustom()`
  - [ ] Output to `site/content/reference/cli/`

#### Testing
- [ ] Unit test for front matter generation
- [ ] Integration test with CLI root command

#### Dependencies
- [ ] Add `github.com/spf13/cobra/doc` dependency
- [ ] Add `github.com/open-platform-model/cli` as dependency

### 1.3 - Hugo Content Adapter Activation

- [ ] Uncomment `site/content/reference/definitions/_content.gotmpl`
- [ ] Test content adapter with generated JSON
- [ ] Verify pages are created correctly
- [ ] Add error handling for missing data files

### 1.4 - Theme Selection & Integration

**Option A: Fix Docsy**
- [ ] Investigate Docsy i18n YAML format issue
- [ ] Submit upstream PR or fork with fix
- [ ] Re-enable Docsy in `hugo.toml`

**Option B: Switch to Hugo Book**
- [ ] Replace Docsy with Hugo Book theme
- [ ] Update `hugo.toml` module imports
- [ ] Adjust content front matter for Book theme
- [ ] Create basic layouts for home and list pages

**Option C: Minimal Custom Theme**
- [ ] Create `site/layouts/_default/baseof.html`
- [ ] Create `site/layouts/_default/single.html`
- [ ] Create `site/layouts/_default/list.html`
- [ ] Create `site/layouts/index.html`
- [ ] Add minimal CSS for readability

**Decision**: Recommend **Option B (Hugo Book)** - simplest path to working docs.

### 1.5 - Local Build Verification

- [ ] `task build:docgen` succeeds
- [ ] `task generate:schema` produces JSON files in `site/data/schema/`
- [ ] `task generate:cli` produces markdown files in `site/content/reference/cli/`
- [ ] `task build` produces complete site in `public/`
- [ ] Manual verification: browse `public/index.html` locally

---

## 📦 Phase 2: Full Coverage

**Goal**: Process all CUE modules, add rich rendering, write guides.

### 2.1 - Process All CUE Modules

- [ ] Extend `cuedoc` to handle module dependency order
- [ ] Process all 9 catalog modules:
  - [ ] `core` (v0.1.21)
  - [ ] `schemas` (v0.1.5)
  - [ ] `schemas_kubernetes` (v0.0.2)
  - [ ] `resources` (v0.2.15)
  - [ ] `policies` (v0.1.19)
  - [ ] `traits` (v0.1.27)
  - [ ] `blueprints` (v0.1.26)
  - [ ] `providers` (v0.1.36)
  - [ ] `examples` (v0.1.26)
- [ ] Resolve cross-references between modules
- [ ] Generate module dependency graph visualization

### 2.2 - Custom Hugo Shortcodes

Create `site/layouts/shortcodes/`:

- [ ] `def-fields.html` - Definition fields table
  - [ ] Render field name, type, constraint, required/optional, default
  - [ ] Type badge styling (string, int, struct, etc.)
  - [ ] Constraint rendering (disjunctions, bounds)
- [ ] `def-ref.html` - Cross-reference links
  - [ ] Link to related definitions (FQN resolution)
  - [ ] Hover preview with description
- [ ] `cue-source.html` - CUE source view
  - [ ] Link to catalog repository file
  - [ ] Optional inline source display with syntax highlighting

### 2.3 - Enhanced Content Pages

- [ ] Definition reference pages:
  - [ ] Use shortcodes for rich rendering
  - [ ] Add "Used By" section (reverse references)
  - [ ] Add examples from catalog
- [ ] CLI reference pages:
  - [ ] Add usage examples
  - [ ] Add "See Also" links to related commands
  - [ ] Add common workflows

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
    - [ ] Checkout catalog repo (submodule or separate checkout)
    - [ ] Set up Go
    - [ ] Set up Hugo
    - [ ] Build docgen tool
    - [ ] Generate schema docs
    - [ ] Generate CLI docs
    - [ ] Build Hugo site
    - [ ] Upload artifact (public/)

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

### 3.3 - Catalog Data Fetching Strategy

**Current**: Manual `../catalog` sibling directory.

**Production Options**:

- [ ] **Git Submodule**
  - [ ] Add catalog as submodule
  - [ ] Update CI to initialize submodules
  - [ ] Pin to specific catalog version/tag
- [ ] **Clone in CI**
  - [ ] Clone catalog at pinned tag/commit
  - [ ] Pass catalog path to docgen
- [ ] **OCI Registry**
  - [ ] Pull published CUE modules from registry
  - [ ] Requires catalog publishing pipeline
  - [ ] Highest fidelity but most complex

**Decision**: Start with **Git Submodule** for simplicity.

### 3.4 - Versioning

- [ ] Decide on versioning strategy:
  - [ ] Single "latest" version (simplest)
  - [ ] Multi-version (e.g., v0.1, v0.2) using Docsy/Book versioning
- [ ] If multi-version:
  - [ ] Create version selector UI
  - [ ] Build multiple versions in CI
  - [ ] Archive old versions

---

## 🔮 Future Enhancements

### Documentation Quality
- [ ] Search functionality (Algolia, Lunr.js, or built-in)
- [ ] Dark mode support
- [ ] Mobile-responsive layouts
- [ ] Accessibility audit (WCAG 2.1 AA)

### Content
- [ ] Video tutorials
- [ ] Interactive examples (playground)
- [ ] API playground for modules
- [ ] Blog for announcements/updates

### Tooling
- [ ] `docgen validate` - Validate docs coverage
- [ ] `docgen diff` - Show doc changes between catalog versions
- [ ] Link checker in CI
- [ ] Broken reference detection

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
| Docsy i18n format incompatibility | Open | No | Can use Hugo Book instead |
| No Hugo layouts yet | Open | Yes | Blocks Phase 1.4 |
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
1. Implement `internal/cuedoc` CUE extraction (Phase 1.1)
2. Choose and integrate Hugo theme (Phase 1.4)
3. Test with `core` module only

---

## 📚 References

- [RFC-0006: Documentation Generation](https://github.com/open-platform-model/cli/blob/main/docs/rfc/0006-documentation-generation.md)
- [CUE Go API - Walking Schemas](https://cuelang.org/docs/howto/walk-schemas-using-go-api/)
- [Hugo Content Adapters](https://gohugo.io/content-management/content-adapters/)
- [cobra/doc package](https://pkg.go.dev/github.com/spf13/cobra/doc)
- [Hugo Book Theme](https://github.com/alex-shpak/hugo-book)
- [Docsy Theme](https://www.docsy.dev/)
