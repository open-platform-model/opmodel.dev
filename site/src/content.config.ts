import { defineCollection } from 'astro:content'
import { z } from 'astro/zod'
import { docsLoader } from '@astrojs/starlight/loaders'
import { docsSchema } from '@astrojs/starlight/schema'
import { ExtendDocsSchema } from 'starlight-theme-black/schema'

// Every page is one of four types (enhancement 0018:D7). Optional until every
// page declares one; any other value fails the build.
const pageType = z.enum(['tutorial', 'how-to', 'explanation', 'reference'])

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    // Black's extension adds hero.layout, hero.announcement and
    // showMarkdownActions. Without it Starlight drops those fields and every
    // hero falls back to media-left.
    schema: docsSchema({ extend: ExtendDocsSchema.extend({ type: pageType.optional() }) }),
  }),
}
