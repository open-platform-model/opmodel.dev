// Version lookups shared by the version switch and the outdated banner.

import manifest from './generated/versions.json'

export interface VersionLink {
  name: string
  href: string
  isLatest: boolean
  isCurrent: boolean
}

// The version being built, taken from the base path (`/v0.2/` gives `v0.2`).
export const currentVersion = import.meta.env.BASE_URL.replace(/^\/|\/$/g, '')
export const latestVersion = manifest.latest

// Links to `slug` in every version. When a version lacks the page, the link
// goes to the nearest parent page that exists there, else to its home.
export function versionLinks(slug: string): VersionLink[] {
  return manifest.versions.map(({ name, slugs }) => {
    let target = slug
    while (target !== '' && !slugs.includes(target)) {
      target = target.includes('/') ? target.slice(0, target.lastIndexOf('/')) : ''
    }
    return {
      name,
      href: `/${name}/${target === '' ? '' : `${target}/`}`,
      isLatest: name === latestVersion,
      isCurrent: name === currentVersion,
    }
  })
}
