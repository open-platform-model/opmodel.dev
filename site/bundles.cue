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
registry: "ghcr.io/open-platform-model/docs"
signer: {
	issuer:   "https://token.actions.githubusercontent.com"
	workflow: "https://github.com/open-platform-model/docs-kit/.github/workflows/publish.yml"
	refs: ["refs/tags/v[0-9]*"]
}
tabs: {
	"catalog-opm": {repo: "open-platform-model/catalog_opm", root: "/catalogs/opm/", from: "4.5"}
}
