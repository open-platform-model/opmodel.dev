tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.4"}
}
sections: {
	"enhancements": {repo: "open-platform-model/enhancements", root: "/enhancements/"}
}
docs: {
	"cli":            {repo: "open-platform-model/cli"}
	"core":           {repo: "open-platform-model/core"}
	"library":        {repo: "open-platform-model/library"}
	"opm-controller": {repo: "open-platform-model/opm-controller"}
	"opm":            {repo: "open-platform-model/opm"}
	"catalog-opm-docs": {repo: "open-platform-model/catalog_opm"}
}
versions: "v1.0": {
	anchor: {project: "cli", tag: "1.0"}
	pinned: ["library", "core", "opm-controller"]
	tags: {"opm": "1.0", "catalog-opm-docs": "4"}
}
