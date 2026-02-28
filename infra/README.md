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

<!-- security-smoke -->
