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

## How We Ship

The production path is intentionally strict:

1. Work from a fresh local `main`.
2. Make your change.
3. Run the release helper from the repo root.
4. Let the PR checks pass.
5. GitHub merges to `main` and the push to `main` deploys to Azure Static Web Apps.

Preferred command:

```powershell
.\scripts\release.ps1 -Title "Refresh homepage copy"
```

What the helper does:

- verifies `git`, `gh`, and `npm` are available
- checks GitHub CLI auth
- fetches `origin/main`
- creates a fresh branch when you start from `main`
- runs `npm run build` in [app](app)
- stages and commits all changes
- pushes the branch to `origin`
- creates or reuses a PR to `main`
- enables auto-merge by default, so deployment starts automatically after checks pass
- warns or fails when an existing branch is stale against `origin/main`
- supports standard PowerShell `-WhatIf` and `-Confirm`

Useful options:

- `-BranchName "feat/custom-name"` to choose the branch name yourself
- `-CommitMessage "Commit message"` to override the commit message
- `-Paths "app","README.md"` to stage only specific paths instead of everything currently changed
- `-AllowStaleBranch` to continue intentionally when your current feature branch is behind `origin/main`
- `-SkipAutoMerge` to open the PR without enabling auto-merge
- `-WhatIf` to preview mutating steps using standard PowerShell behavior
- `-DryRun` remains available as a compatibility alias for `-WhatIf`

Manual fallback if you do not want to use the helper:

```powershell
git switch main
git pull --ff-only origin main
git switch -c feat/short-name
cd app
npm ci
npm run build
cd ..
git add -A
git commit -m "Short release title"
git push -u origin feat/short-name
gh pr create --base main --head feat/short-name --title "Short release title"
gh pr merge --auto --squash --delete-branch
```

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
