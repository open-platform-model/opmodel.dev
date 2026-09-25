import { defineCollection } from 'astro:content'
import { z } from 'astro/zod'
import { docsLoader } from '@astrojs/starlight/loaders'
import { docsSchema } from '@astrojs/starlight/schema'

// Every page is one of four types (enhancement 0018:D7). Optional until every
// page declares one; any other value fails the build.
const pageType = z.enum(['tutorial', 'how-to', 'explanation', 'reference'])

export const collections = {
  docs: defineCollection({
    loader: docsLoader(),
    schema: docsSchema({ extend: z.object({ type: pageType.optional() }) }),
  }),
}
