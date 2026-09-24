// Builds every version into dist/<name>/, then adds the root redirect, the
// /latest/ aliases and the 404 page.
//
// Each build is checked against the manifest: the number of pages written
// must equal the number of pages prepared. Astro content loaders can drop
// pages without failing the build, so this check is what catches it.

import { execFileSync } from 'node:child_process'
import { cpSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from 'node:fs'
import { dirname, join, relative, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { stage } from './stage-version.mjs'

const siteDir = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const distDir = join(siteDir, 'dist')

execFileSync('node', [join(siteDir, 'scripts/prepare-versions.mjs')], { stdio: 'inherit' })
const manifest = JSON.parse(readFileSync(join(siteDir, 'src/generated/versions.json'), 'utf8'))

function pagesIn(dir) {
  return readdirSync(dir).flatMap((name) => {
    const path = join(dir, name)
    if (statSync(path).isDirectory()) return name === 'pagefind' || name === '_astro' ? [] : pagesIn(path)
    return name === 'index.html' ? [path] : []
  })
}

function redirect(to) {
  return `<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=${to}"><link rel="canonical" href="${to}"><title>Redirecting</title>`
}

rmSync(distDir, { recursive: true, force: true })
for (const { name, slugs } of manifest.versions) {
  stage(name)
  execFileSync('astro', ['build'], {
    cwd: siteDir,
    stdio: 'inherit',
    env: { ...process.env, OPM_DOCS_VERSION: name },
  })
  const built = pagesIn(join(distDir, name)).length
  if (built !== slugs.length) {
    throw new Error(`${name}: built ${built} pages, prepared ${slugs.length}; a page was dropped or added`)
  }
  console.log(`checked ${name}: ${built} pages`)
}
stage(manifest.latest)

// The root and /latest/ point at the newest version. A host with redirect
// rules should use _redirects instead of the meta-refresh stubs.
writeFileSync(join(distDir, 'index.html'), redirect(`/${manifest.latest}/`))
writeFileSync(join(distDir, '_redirects'), `/latest/* /${manifest.latest}/:splat 302\n/ /${manifest.latest}/ 302\n`)
const latestDir = join(distDir, manifest.latest)
for (const page of pagesIn(latestDir)) {
  const path = relative(latestDir, dirname(page))
  const target = join(distDir, 'latest', path)
  mkdirSync(target, { recursive: true })
  writeFileSync(join(target, 'index.html'), redirect(`/${manifest.latest}/${path ? `${path}/` : ''}`))
}
cpSync(join(latestDir, '404.html'), join(distDir, '404.html'))
console.log(`dist/ ready: ${manifest.versions.map((v) => v.name).join(', ')}; latest is ${manifest.latest}`)
