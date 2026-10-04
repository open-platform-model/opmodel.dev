// Two site versions, and v1.0's fields split over two declarations (CUE
// unifies them): edge-config.sh drops every top-level versions declaration,
// a comment holding a brace included, and appends the one edge version.
registry: "ghcr.io/open-platform-model/docs"
docs: {
	"cli":          {repo: "open-platform-model/cli"}
	"core":         {repo: "open-platform-model/core"}
	"library":      {repo: "open-platform-model/library"}
	"opm-operator": {repo: "open-platform-model/opm-operator"}
}
versions: "v1.0": anchor: {project: "cli", tag: "1.0"} // the anchor {
versions: "v1.0": {
	pinned: ["library", "core", "opm-operator"]
}
// v1.1, a second site version.
versions: "v1.1": {
	anchor: {project: "cli", tag: "1.1"} // }
	pinned: ["library", "core", "opm-operator"]
}
tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.5"}
}
