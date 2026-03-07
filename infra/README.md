# Infrastructure

Lean production infrastructure for the Polder Labs Azure Static Web App.

```bash
az group create -g rg-<project>-prod -l westeurope

az deployment group create \
  --resource-group rg-<project>-prod \
  --template-file infra/main.bicep \
  --parameters \
    name='<swa-name>' \
    environment='prd'
```

Notes:
- This template keeps infra intentionally lean: one Static Web App resource.
- It adds only the basics for a first production version: validated parameters, production tagging, and an explicit SKU parameter.
- Default SKU is `Free`, which fits a low-traffic first release. Move to `Standard` later if you need higher limits or more advanced features.
- Application deployment is handled by [.github/workflows/build-and-deploy.yml](../.github/workflows/build-and-deploy.yml).

## Current production resource

- Resource group: `rg-website-polder-labs-prd`
- Static Web App: `website-polder-labs-prd-260307`
- Default hostname: `witty-mud-06fe47a03.2.azurestaticapps.net`
- Live `www` domain: `www.polder-labs.nl`

## Parameters

- `name`: globally unique Static Web App name
- `environment`: fixed to `prd`
- `skuName`: `Free` by default, optional `Standard`
- `tags`: optional extra Azure tags

## Custom domains

Current setup:

- `www.polder-labs.nl`: bound in Azure Static Web Apps
- `polder-labs.nl`: apex domain validation in progress or managed via DNS mapping

For `www.polder-labs.nl`:

1. At your DNS provider, create a `CNAME` record:
  - Host: `www`
  - Value: `witty-mud-06fe47a03.2.azurestaticapps.net`

2. Wait until DNS resolves.

3. Bind the domain in Azure by running:

```powershell
.\infra\set-custom-domain.ps1
```

This script uses:
- resource group `rg-website-polder-labs-prd`
- Static Web App `website-polder-labs-prd-260307`
- hostname `www.polder-labs.nl`

Optional root-domain behavior:
- redirect `polder-labs.nl` to `https://www.polder-labs.nl` at your DNS/registrar provider
- keep `www` as the primary production hostname

## Security Baseline

Current repository safety settings for `main`:
- Required status check: `validate`
- Pull request review required: **0 approvals** (PR still required)
- Dismiss stale reviews on new commits: **enabled**
- Admin bypass: **disabled** (`enforce_admins: true`)
- Force push: **disabled**
- Branch deletion: **disabled**
- Linear history: **required**
- Conversation resolution before merge: **not required**

Current runtime hardening:
- Security headers are configured in [app/public/staticwebapp.config.json](../app/public/staticwebapp.config.json)
- Custom 404 override is configured and deployed

## Deploy Token Rotation (SWA)

Rotate the Azure Static Web Apps deployment token:

```bash
az staticwebapp secrets reset-api-key \
  --name <swa-name> \
  --resource-group <resource-group>

az staticwebapp secrets list \
  --name <swa-name> \
  --resource-group <resource-group> \
  --query properties.apiKey -o tsv
```

Update GitHub secret with the new token:

```bash
gh secret set AZURE_STATIC_WEB_APPS_API_TOKEN \
  --repo <owner>/<repo> \
  --body "<new-token>"
```

Validation after rotation:
- Trigger a workflow run (push or PR)
- Confirm `Upload to Azure Static Web Apps` succeeds
