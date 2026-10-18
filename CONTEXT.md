# opmodel.dev: where do I go?

Router only. Facts and rules are in `AGENTS.md`.

| Task | Read first | Then |
| --- | --- | --- |
| Pull or pin a docs bundle, change the trust policy, bump `opm-docs`, recover from a bad bundle, add a site version or a catalog tab, or work on the edge build | `references/site-bundles.md` | `site/` |
| Work on the Catalogs or Enhancements section: its adapter, its data or its fixtures | `references/site-bundles.md` | `site/catalogs/`, `site/enhancements/` |
| Change a published URL, a redirect, the base path, `noindex` or the sitemap | `references/site-urls.md` | `site/layouts/` |
| Change an image, a Docker run flag, the network rule, git dates or a host requirement; or regenerate brand rasters or run the comment rule | `references/build-environment.md` | `site/scripts/` |
| Change a Hextra override or a vendored file, or add a check | `AGENTS.md` | `site/themes/`, `site/tests/` |
| Change a layout, partial, shortcode or style | `AGENTS.md` | `site/layouts/`, `site/assets/` |
| Change a site-owned page (landing, section overview) | `README.md` | `site/content/` |
| Fix a bundle page, a generated reference page or a link in a source page | `AGENTS.md` | the source repository's `docs/site/` |
| Edit a workflow | `.github/workflows/` | `Taskfile.yml` |
| Start a feature change, or write a durable decision | `openspec/config.yaml` | `CONSTITUTION.md` |
| A `task check` or `openspec` failure | `openspec/config.yaml` | `.tasks/` |
| Choose a commit or PR type | `openspec/config.yaml` | |
| Deliver or cite an enhancement | `references/enhancements.md` at the workspace root | |
| Commit, open a PR or write GitHub text | `references/git-text.md` at the workspace root | |
| Look up a registry mapping or a CUE resolution problem | `references/registry.md` at the workspace root | |
