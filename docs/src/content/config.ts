import { defineCollection } from "astro:content";
import { docsLoader, i18nLoader } from "@astrojs/starlight/loaders";

// Starlight content collections — required by @astrojs/starlight 0.32+.
// The loaders glob the docs directory automatically.
export const collections = {
  docs: defineCollection(docsLoader()),
  i18n: defineCollection(i18nLoader()),
};
