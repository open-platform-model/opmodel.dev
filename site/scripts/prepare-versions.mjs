// Materialises every version's content from its source into .versions/<name>/
// and writes the manifest the version switch reads.
//
// A version's pages are this repository's content plus, for a working-tree
// version, every source repository's docs/site/ under docs/ (sources.mjs).
// Two repositories publishing the same address fail the run (0018:D8).
//
// Per version it writes:
//   .versions/<name>/content/**   the version's pages
//   .versions/<name>/sidebar.json
// and once for all versions:
//   src/generated/versions.json   { latest, versions: [{ name, slugs }] }
//
// Root-relative links in pages gain the version's base path, because Astro
// does not rewrite links inside content.

import { execFileSync } from 'node:child_process'
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { parse } from 'yaml'
import versions from '../versions.config.mjs'
import { sourceDirs } from './sources.mjs'

const siteDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const repoDir = resolve(siteDir, '..')
const versionsDir = join(siteDir, '.versions')

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    return statSync(path).isDirectory() ? walk(path) : [path]
  })
}

// Returns a directory holding `path` as it is at `ref`, and a function that
// removes any temporary copy.
function checkout(ref, path) {
  if (ref === null) return { source: join(repoDir, path), cleanup: () => {} }
  const dir = mkdtempSync(join(tmpdir(), 'opm-docs-'))
  const tar = execFileSync('git', ['-C', repoDir, 'archive', '--format=tar', ref, '--', path], { maxBuffer: 1 << 30 })
  execFileSync('tar', ['-x', '-C', dir], { input: tar })
  return { source: join(dir, path), cleanup: () => rmSync(dir, { recursive: true, force: true }) }
}

// Prefixes `](/...)` link targets outside fenced code blocks with `base`.
function rebaseLinks(markdown, base) {
  return markdown
    .split(/(^```[\s\S]*?^```)/m)
    .map((part, i) => (i % 2 === 1 ? part : part.replace(/\]\(\/(?!\/)/g, `](${base}/`)))
    .join('')
}

function frontMatter(text) {
  const match = text.match(/^---\n([\s\S]*?)\n---/)
  return match ? (parse(match[1]) ?? {}) : {}
}

// A directory with an index page and pages under it becomes a group whose
// first link is the index page; any other page becomes a plain link.
function sidebarFor(pages, dir = 'docs') {
  const children = pages
    .filter((p) => p.slug !== dir && dirname(p.slug) === dir)
    .sort((a, b) => a.order - b.order || a.title.localeCompare(b.title))
  return children.map((child) => {
    const nested = sidebarFor(pages, child.slug)
    if (nested.length === 0) return { slug: child.slug }
    return { label: child.title, items: [{ slug: child.slug, label: 'Overview' }, ...nested] }
  })
}

function prepare(version) {
  const { source, cleanup } = checkout(version.ref, version.path)
  const out = join(versionsDir, version.name)
  rmSync(out, { recursive: true, force: true })

  const roots = [{ repo: 'opmodel.dev', dir: source, prefix: '' }]
  if (version.ref === null) roots.push(...sourceDirs().map((s) => ({ ...s, prefix: 'docs' })))

  const owners = new Map()
  const pages = []
  for (const root of roots) {
    for (const file of walk(root.dir)) {
      const rel = join(root.prefix, relative(root.dir, file))
      if (!/\.mdx?$/.test(rel) || (version.exclude ?? []).includes(rel)) continue
      if (owners.has(rel)) {
        throw new Error(`${version.name}: ${rel} is published by both ${owners.get(rel)} and ${root.repo}`)
      }
      owners.set(rel, root.repo)
      const text = readFileSync(file, 'utf8')
      const { title, sidebar } = frontMatter(text)
      mkdirSync(dirname(join(out, 'content', rel)), { recursive: true })
      writeFileSync(join(out, 'content', rel), rebaseLinks(text, `/${version.name}`))
      const slug = rel.replace(/\.mdx?$/, '').replace(/(^|\/)index$/, '')
      pages.push({ slug, title: title ?? slug, order: sidebar?.order ?? Infinity })
    }
  }
  cleanup()

  writeFileSync(join(out, 'sidebar.json'), JSON.stringify(sidebarFor(pages), null, 2))
  return { name: version.name, slugs: pages.map((p) => p.slug).sort() }
}

const manifest = {
  latest: versions.find((v) => v.latest).name,
  versions: versions.map(prepare),
}
mkdirSync(join(siteDir, 'src/generated'), { recursive: true })
writeFileSync(join(siteDir, 'src/generated/versions.json'), JSON.stringify(manifest, null, 2))
for (const v of manifest.versions) console.log(`prepared ${v.name}: ${v.slugs.length} pages`)
