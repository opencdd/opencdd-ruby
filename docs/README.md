# opencdd docs site

This directory holds the Astro + Starlight documentation site for the
`opencdd` Ruby gem. The site is published at
**<https://opencdd.github.io/opencdd-ruby/>**.

## Local development

```bash
cd docs
npm install
npm run dev
```

Serves at <http://localhost:4321/opencdd-ruby/>.

## Build

```bash
npm run build
```

Outputs static HTML to `docs/dist/`. Preview with:

```bash
npm run preview
```

## Deployment

Automated via [`.github/workflows/deploy-docs.yml`](../.github/workflows/deploy-docs.yml).
Every push to `main` that touches `docs/` rebuilds and deploys to
GitHub Pages. No manual steps required.

## Structure

```
docs/
├── astro.config.mjs           # Astro + Starlight config
├── package.json               # Node deps
├── tsconfig.json
├── public/                    # static assets
├── src/
│   ├── assets/                # logo, images
│   ├── styles/custom.css      # Starlight overrides
│   └── content/
│       └── docs/              # ← markdown source of truth
│           ├── index.mdx      # landing page
│           ├── getting-started.md
│           ├── ontology.md
│           ├── cddal-syntax.md
│           ├── parcel-format.md
│           ├── architecture.md
│           ├── concepts/
│           │   └── irdi.md
│           └── reference/
│               ├── api.md
│               └── validator-rules.md
```

## Editing docs

Edit the Markdown files in `src/content/docs/`. The sidebar and
navigation are configured in `astro.config.mjs`. New pages require a
sidebar entry to be discoverable.

The Markdown source is the single source of truth — GitHub renders
these files inline, and the Starlight build publishes them as a
styled site.
