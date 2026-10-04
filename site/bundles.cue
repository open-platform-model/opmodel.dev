// The Catalogs tab's docs bundles and their trust policy (docs-kit contract
// C7, schema/pull.cue; the policy is C9). task bundles:pull resolves every
// minor tag at or above `from`, and edge, in `registry`, and accepts a bundle
// only when its Sigstore certificate was issued by `signer.issuer` to
// docs-kit's `signer.workflow` at a ref matching a `signer.refs` glob (a
// docs-kit release tag), for the tab's `repo` at refs/heads/main. It unpacks
// them into site/.bundles/ with lock.json. The policy is written out here
// although it equals the schema's defaults, so a change to it is a reviewed
// change to this file. The tab starts at the first opm release after the
// catalog adopted docs-kit (no backfill; docs-kit DESIGN decision 8,
// 2026-10-03). run-in-image.sh reads the tab names from their quoted keys
// ("catalog-opm": {...}); keep every tab key quoted.
//
// docs (docs-kit C16) names the projects that may be placed in a site
// version's /docs/, each with the only repository allowed to sign it. A site
// version reads a repository from its docs bundle exactly when versions names
// its project for that version (the lock's "docs" entries; site/versions.conf
// mirrors the set as from-bundles); docs without versions pulls nothing.
// run-in-image.sh reads these keys the same way: keep every docs key and
// every site-version key quoted.
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
	"cli":          {repo: "open-platform-model/cli"}
	"core":         {repo: "open-platform-model/core"}
	"library":      {repo: "open-platform-model/library"}
	"opm-operator": {repo: "open-platform-model/opm-operator"}
	"opm":          {repo: "open-platform-model/opm"}
}
// v1.0 follows the cli 1.0 line through its docs bundle: the anchor is the
// newest cli release in 1.0, and library, core and opm-operator are exactly
// what that release pins (docs-kit C16, DESIGN decisions 9 and 10). opm,
// which the cli does not pin, follows its own 1.0 line (its newest release in
// that minor; docs-kit DESIGN decision 21: opm's minor follows the site
// version).
versions: "v1.0": {
	anchor: {project: "cli", tag: "1.0"}
	pinned: ["library", "core", "opm-operator"]
	tags: {"opm": "1.0"}
}
