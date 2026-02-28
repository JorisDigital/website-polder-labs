# Infrastructure

Deploy the Azure Static Web App resource:

```bash
az group create -g rg-<project>-prod -l westeurope

az deployment group create \
  --resource-group rg-<project>-prod \
  --template-file infra/main.bicep \
  --parameters \
    name='<swa-name>' \
    repositoryUrl='https://github.com/<user>/<repo>' \
    repositoryToken='<github-pat>'
```

Notes:
- `repositoryToken` is required by the Static Web App resource when linking a GitHub repository.
- For scaffolding phase, custom domain is intentionally deferred.

## GitHub Actions Provisioning

A manual provisioning workflow is available at [.github/workflows/provision-infra.yml](../.github/workflows/provision-infra.yml).

Required GitHub secrets:
- `AZURE_CREDENTIALS` (service principal JSON for `azure/login`)
- `REPOSITORY_TOKEN` (GitHub PAT used by the SWA ARM/Bicep resource)

Run it from GitHub: **Actions** → **Provision Azure Infrastructure** → **Run workflow**.

## Security Baseline

Current repository safety settings for `main`:
- Required status check: `build_and_deploy`
- Pull request review required: **1 approval**
- Dismiss stale reviews on new commits: **enabled**
- Admin bypass: **disabled** (`enforce_admins: true`)
- Force push: **disabled**
- Branch deletion: **disabled**
- Linear history: **required**
- Conversation resolution before merge: **required**

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
