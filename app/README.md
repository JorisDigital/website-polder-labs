# App

This folder contains the Astro frontend deployed to Azure Static Web Apps.

## Public asset structure

- Runtime site assets live in `public/`.
- Downloadable brand collateral and copy-paste snippets live in `public/assets/`.
- Avoid duplicating the same logo/icon files in both places; `public/` is the canonical source for files used by the website itself.

## Commands

Run these from the app root.

| Command | Purpose |
| --- | --- |
| `npm ci` | Install exact dependencies from lockfile |
| `npm run dev` | Start local Astro dev server |
| `npm run build` | Build static output to `app/dist` |
| `npm run preview` | Preview built site locally |

## Azure Static Web Apps specifics

- Custom headers and 404 behavior are configured in [public/staticwebapp.config.json](public/staticwebapp.config.json).
- Deployment uploads prebuilt artifacts from `app/dist`.
- Node runtime policy is defined in [package.json](package.json) (`engines.node`).

## Pages

- Home: [src/pages/index.astro](src/pages/index.astro)
- Not found: [src/pages/404.astro](src/pages/404.astro)
