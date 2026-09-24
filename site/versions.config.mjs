// Site versions, newest first. Each version is built on its own under
// /<name>/ from a snapshot of its content.
//
// `ref` is a git ref of this repository, or null for the working tree.
// `path` is the content directory at that ref; `exclude` lists pages under it
// to leave out. The site's real versions will be read from the five source
// repositories at the tags the CLI pins (0021:OQ15).
//
// No version has been released yet. v0.1 is a demo entry so the version
// switch has something to switch to: the working tree without the two newest
// reference pages. Replace it with the first real release.
export default [
  { name: 'v0.2', ref: null, path: 'site/content', latest: true },
  {
    name: 'v0.1',
    ref: null,
    path: 'site/content',
    exclude: ['docs/reference/catalog-contract.md', 'docs/reference/registry-namespaces.md'],
  },
]
