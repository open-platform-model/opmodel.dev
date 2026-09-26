// The repositories whose published pages the site assembles (0018:D8). Each
// keeps them under docs/site/, where a page's path is its address under
// /docs/; everything else in a repository stays out of the site.
//
// A version built from the working tree reads them from the workspace
// checkout. The Taskfile mounts the workspace read-only and names it in
// OPM_DOCS_WORKSPACE; outside the container it is the directory holding this
// repository. Tagged versions will read them at the tags the CLI pins
// (0021:OQ15).

import { existsSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

export const sourceRepos = ['opm', 'core', 'catalog_opm', 'cli', 'library', 'opm-operator']

const workspaceDir =
  process.env.OPM_DOCS_WORKSPACE ?? resolve(dirname(fileURLToPath(import.meta.url)), '../../..')

// Returns every source repository that has published pages, with the
// directory holding them.
export function sourceDirs() {
  return sourceRepos
    .map((repo) => ({ repo, dir: join(workspaceDir, repo, 'docs/site') }))
    .filter(({ dir }) => existsSync(dir))
}
