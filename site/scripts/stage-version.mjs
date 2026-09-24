// Copies one prepared version into src/content/docs, where Starlight reads
// it. Usage: node scripts/stage-version.mjs [version]; defaults to the
// latest version. Run prepare-versions.mjs first.

import { cpSync, rmSync } from 'node:fs'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import versions from '../versions.config.mjs'

const siteDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')

export function stage(name) {
  const contentDir = join(siteDir, 'src/content/docs')
  rmSync(contentDir, { recursive: true, force: true })
  cpSync(join(siteDir, '.versions', name, 'content'), contentDir, { recursive: true })
}

if (import.meta.url === `file://${process.argv[1]}`) {
  stage(process.argv[2] ?? versions.find((v) => v.latest).name)
}
