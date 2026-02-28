# website-polder-labs

A lean Astro + Azure Static Web Apps template for a simple, great webpage.

## Repository structure

- [app](app): Astro frontend
- [infra](infra): minimal Azure infrastructure definition
- [.github/workflows](.github/workflows): build and deploy workflow

## Local development

1. `cd app`
2. `npm ci`
3. `npm run dev`

## Build

- `cd app && npm run build`

## Deployment flow

- Pull requests to `main`: run build validation.
- Pushes to `main`: run build + deploy to Azure Static Web Apps.

## One-time Azure setup

- Create the Static Web App with [infra/main.bicep](infra/main.bicep).
- Add GitHub secret `AZURE_STATIC_WEB_APPS_API_TOKEN`.

## Security notes

- Runtime headers and 404 behavior are defined in [app/public/staticwebapp.config.json](app/public/staticwebapp.config.json).
- Branch protection requires pull requests and status checks.
- SWA deployment token rotation procedure is documented in [infra/README.md](infra/README.md).
