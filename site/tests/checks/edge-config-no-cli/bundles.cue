// No "cli" under docs: the edge build has no anchor, so edge-config.sh
// refuses the file, naming it.
docs: {
	"core":    {repo: "open-platform-model/core"}
	"library": {repo: "open-platform-model/library"}
}
versions: "v1.0": {
	anchor: {project: "core", tag: "2.0"}
}
