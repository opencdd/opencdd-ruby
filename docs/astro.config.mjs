import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// Starlight-based documentation site for the opencdd Ruby gem.
//
// Local dev:   cd docs && npm install && npm run dev
// Build:       cd docs && npm run build   (outputs to docs/dist/)
// Production:  https://opencdd.github.io/opencdd-ruby/
//
// Deployment is automated via .github/workflows/deploy-docs.yml —
// every push to main that touches docs/ rebuilds and deploys.
export default defineConfig({
  site: "https://opencdd.github.io",
  base: "/opencdd-ruby",
  trailingSlash: "always",
  integrations: [
    starlight({
      title: "opencdd",
      logo: {
        src: "./src/assets/logo.svg",
        replacesTitle: false,
      },
      description: "Ruby model for the IEC Common Data Dictionary",
      social: {
        github: "https://github.com/opencdd/opencdd-ruby",
      },
      sidebar: [
        {
          label: "Get started",
          items: [
            { label: "Overview", link: "/" },
            { label: "Getting started", slug: "getting-started" },
          ],
        },
        {
          label: "Concepts",
          items: [
            { label: "Four-layer ontology", slug: "ontology" },
            { label: "IRDI identifiers", slug: "concepts/irdi" },
          ],
        },
        {
          label: "Formats",
          items: [
            { label: "YAML persistence", slug: "model/yaml-persistence" },
            { label: "Parcel Excel", slug: "parcel-format" },
            { label: "CDDAL syntax", slug: "cddal-syntax" },
          ],
        },
        {
          label: "Reference",
          items: [
            { label: "Architecture", slug: "architecture" },
            { label: "Feature audit", slug: "reference/features" },
            { label: "Validator rules", slug: "reference/validator-rules" },
            { label: "API", slug: "reference/api" },
          ],
        },
      ],
      editLink: {
        baseUrl: "https://github.com/opencdd/opencdd-ruby/edit/main/docs",
      },
      customCss: ["./src/styles/custom.css"],
    }),
  ],
});
