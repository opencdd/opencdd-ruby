import { defineCollection } from "astro:content";
import { docsLoader } from "@astrojs/starlight/loaders";
import { docsSchema } from "@astrojs/starlight/schema";

// Starlight content collection. The schema is required — without it,
// Astro silently loads nothing.
export const collections = {
  docs: defineCollection({ loader: docsLoader(), schema: docsSchema() }),
};
