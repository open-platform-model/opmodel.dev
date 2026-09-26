// Astro + Starlight + Black build of opmodel.dev. One run builds one version,
// named by OPM_DOCS_VERSION (default: the latest), under /<version>/.
// scripts/build-versions.mjs runs it once per version.

import { execFileSync } from 'node:child_process'
import { readFileSync } from 'node:fs'
import { fileURLToPath } from 'node:url'
import starlight from '@astrojs/starlight'
import { defineConfig } from 'astro/config'
import starlightThemeBlack from 'starlight-theme-black'
import { sourceDirs } from './scripts/sources.mjs'
import { stage } from './scripts/stage-version.mjs'
import versions from './versions.config.mjs'

const version = process.env.OPM_DOCS_VERSION ?? versions.find((v) => v.latest).name
const base = `/${version}`
const sidebar = JSON.parse(readFileSync(new URL(`./.versions/${version}/sidebar.json`, import.meta.url), 'utf8'))

// The dev server reads the staged copy in src/content/docs, so an edit under
// content/ or a source repository's docs/site/ re-prepares and re-stages it.
// The sidebar is read once at startup: adding, removing or retitling a page
// needs a server restart.
function restageOnEdit() {
  const contentDir = fileURLToPath(new URL('./content/', import.meta.url))
  const sourceDirsWatched = sourceDirs().map(({ dir }) => `${dir}/`)
  const prepare = fileURLToPath(new URL('./scripts/prepare-versions.mjs', import.meta.url))
  return {
    name: 'opm-restage-on-edit',
    hooks: {
      'astro:server:setup': ({ server }) => {
        server.watcher.add(sourceDirsWatched)
        server.watcher.on('all', (_event, path) => {
          if (![contentDir, ...sourceDirsWatched].some((dir) => path.startsWith(dir))) return
          execFileSync('node', [prepare])
          stage(version)
        })
      },
    },
  }
}

export default defineConfig({
  site: 'https://opmodel.dev',
  base,
  outDir: `./dist/${version}`,
  trailingSlash: 'always',
  // The build image keeps node_modules outside the site (see Dockerfile), so
  // caches live under .astro and the dev server may read the packages there.
  cacheDir: './.astro/cache',
  vite: {
    cacheDir: './.astro/vite',
    server: { fs: { allow: ['.', process.env.NODE_MODULES_DIR].filter(Boolean) } },
  },
  integrations: [
    restageOnEdit(),
    starlight({
      title: 'Open Platform Model',
      description: 'A declarative platform model for describing applications and their infrastructure requirements.',
      social: [{ icon: 'github', label: 'GitHub', href: 'https://github.com/open-platform-model' }],
      components: {
        Banner: './src/components/Banner.astro',
        LanguageSelect: './src/components/LanguageSelect.astro',
      },
      sidebar: [{ label: 'Documentation', items: sidebar }],
      plugins: [
        starlightThemeBlack({
          // Black writes nav links as given, so they carry the base path.
          navLinks: [{ label: 'Docs', link: `${base}/docs/` }],
        }),
      ],
    }),
  ],
})
