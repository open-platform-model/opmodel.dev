// The Catalogs tab's docs bundles (docs-kit contract C7, schema/pull.cue):
// task bundles:pull resolves every minor tag at or above `from`, and edge,
// verifies each signature (signed by docs-kit's publish.yml at a refs/tags/v*
// ref, for `repo` at refs/heads/main; C9), and unpacks them to site/.bundles/
// with lock.json. The tab starts at the first opm release after the catalog
// adopted docs-kit (no backfill; docs-kit DESIGN decision 8, 2026-10-03).
tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.5"}
}
