import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

// Docs content collection. Mirrors the sibling browser site's schema
// (title, description, published, updated, order, section). Loaded
// via glob so we can use either .md or .mdx per file.
const docs = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/docs" }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    published: z.coerce.date(),
    updated: z.coerce.date().optional(),
    order: z.number().default(0),
    section: z.string().default("Other"),
    tags: z.array(z.string()).default([]),
  }),
});

export const collections = { docs };
