// A bundles.cue as phase 3 will have it: opm and catalog-opm-docs under docs,
// their own tags in v1.0, and a sections block after versions. edge-config.sh
// keeps every line but the versions block, then appends the edge one.
registry: "ghcr.io/open-platform-model/docs"
signer: {
	issuer:   "https://token.actions.githubusercontent.com"
	workflow: "https://github.com/open-platform-model/docs-kit/.github/workflows/publish.yml"
	refs: ["refs/tags/v[0-9]*"]
}
tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.5"}
}
docs: {
	"cli":              {repo: "open-platform-model/cli"}
	"core":             {repo: "open-platform-model/core"}
	"library":          {repo: "open-platform-model/library"}
	"opm-operator":     {repo: "open-platform-model/opm-operator"}
	"opm":              {repo: "open-platform-model/opm"}
	"catalog-opm-docs": {repo: "open-platform-model/catalog_opm"}
}
// v1.0 follows the cli 1.0 line.
// The Enhancements section, after versions.
sections: {
	"enhancements": {repo: "open-platform-model/enhancements", root: "/enhancements/"}
}
// The edge build (task build:edge, CI's sources-main), written by
// site/scripts/edge-config.sh in place of bundles.cue's versions: every
// docs project at its edge bundle, the cli as the anchor.
versions: "v1.0": {
	anchor: {project: "cli", tag: "edge"}
	tags: {"core": "edge", "library": "edge", "opm-operator": "edge", "opm": "edge", "catalog-opm-docs": "edge"}
}
