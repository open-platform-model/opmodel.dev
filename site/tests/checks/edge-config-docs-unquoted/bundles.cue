// An unquoted docs key would be left out of tags: refused, naming the file.
docs: {
	"cli": {repo: "open-platform-model/cli"}
	core:  {repo: "open-platform-model/core"}
}
versions: "v1.0": {
	anchor: {project: "cli", tag: "1.0"}
	pinned: ["core"]
}
