# Polder Labs website

Production repository for the Polder Labs website, built with Astro and deployed to Azure Static Web Apps.

## Repository structure

- [app](app): Astro frontend
- [infra](infra): Azure infrastructure definition and domain helper script
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

## Deployment setup

- Provision the Static Web App with [infra/main.bicep](infra/main.bicep).
- Store the deployment token in the GitHub secret `AZURE_STATIC_WEB_APPS_API_TOKEN`.

The infrastructure is intentionally simple for a first production release:
- one production environment (`prd`)
- Azure tagging and parameter validation
- default `Free` SKU for low traffic, with an easy upgrade path to `Standard`

## Live domains

- [https://www.polder-labs.nl](https://www.polder-labs.nl)
- [https://polder-labs.nl](https://polder-labs.nl) once apex-domain validation finishes

Domain details and Azure resource information are documented in [infra/README.md](infra/README.md).

## Security notes

- Runtime headers and 404 behavior are defined in [app/public/staticwebapp.config.json](app/public/staticwebapp.config.json).
- Branch protection requires pull requests and status checks.
- SWA deployment token rotation procedure is documented in [infra/README.md](infra/README.md).
