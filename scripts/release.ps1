[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$BranchName,

    [string]$CommitMessage,

    [string]$Base = 'main',

    [string]$Body,

    [string[]]$Paths,

    [switch]$AllowStaleBranch,

    [switch]$SkipAutoMerge,

    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step {
    param([string]$Message)

    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-WarningLine {
    param([string]$Message)

    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-External {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$AllowFailure,

        [switch]$Mutating,

        [string]$ActionDescription
    )

    $display = if ($Arguments.Count -gt 0) {
        "$FilePath $($Arguments -join ' ')"
    }
    else {
        $FilePath
    }

    if ($Mutating) {
        $target = if ([string]::IsNullOrWhiteSpace($ActionDescription)) {
            $display
        }
        else {
            $ActionDescription
        }

        if (-not $PSCmdlet.ShouldProcess($target, 'Run command')) {
            return
        }
    }

    Write-Host $display -ForegroundColor DarkGray
    & $FilePath @Arguments
    $exitCode = $LASTEXITCODE

    if (-not $AllowFailure -and $exitCode -ne 0) {
        throw "Command failed with exit code ${exitCode}: $display"
    }
}

function Get-ExternalOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [string[]]$Arguments = @(),

        [switch]$AllowFailure
    )

    $output = @(& $FilePath @Arguments 2>&1)
    $exitCode = $LASTEXITCODE

    if (-not $AllowFailure -and $exitCode -ne 0) {
        $message = ($output | Out-String).Trim()
        throw "Command failed with exit code ${exitCode}: $FilePath $($Arguments -join ' ')`n$message"
    }

    return @($output | ForEach-Object { $_.ToString() })
}

function New-BranchSlug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw 'Unable to derive a branch name from Title. Provide -BranchName explicitly.'
    }

    return "feat/$slug"
}

function Get-AheadBehindCounts {
    param([string]$Reference)

    $countsOutput = (@(Get-ExternalOutput git @('rev-list', '--left-right', '--count', "HEAD...$Reference")))[-1].Trim()
    $parts = $countsOutput -split "\s+"

    return [pscustomobject]@{
        Ahead = [int]$parts[0]
        Behind = [int]$parts[1]
    }
}

function Get-OpenPullRequest {
    param(
        [string]$HeadBranch,
        [string]$BaseBranch
    )

    $prListJson = (Get-ExternalOutput gh @('pr', 'list', '--head', $HeadBranch, '--base', $BaseBranch, '--state', 'open', '--json', 'number,url')) -join "`n"
    if ([string]::IsNullOrWhiteSpace($prListJson)) {
        return $null
    }

    $parsedPrList = $prListJson | ConvertFrom-Json
    $prList = @($parsedPrList)
    if ($prList.Count -eq 0 -or $null -eq $prList[0]) {
        return $null
    }

    return $prList[0]
}

Push-Location $repoRoot

try {
    Require-Command git
    Require-Command gh
    Require-Command npm

    if ($DryRun) {
        $WhatIfPreference = $true
    }

    $isPreview = [bool]$WhatIfPreference

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $CommitMessage = $Title
    }

    if ([string]::IsNullOrWhiteSpace($Body)) {
        $Body = @"
## Summary
- $Title

## Validation
- npm run build
"@
    }

    Write-Step 'Checking GitHub CLI authentication'
    Invoke-External gh @('auth', 'status')

    Write-Step 'Fetching the latest base branch from origin'
    Invoke-External git @('fetch', 'origin', $Base)

    $currentBranch = (@(Get-ExternalOutput git @('branch', '--show-current')))[-1].Trim()
    $hasWorkingTreeChanges = (@(Get-ExternalOutput git @('status', '--porcelain'))).Count -gt 0
    $behindBase = [int]((@(Get-ExternalOutput git @('rev-list', '--count', "HEAD..origin/$Base")))[-1].Trim())

    if ($currentBranch -eq $Base) {
        if ($behindBase -gt 0 -and $hasWorkingTreeChanges) {
            throw "Your local '$Base' is behind 'origin/$Base' and you have uncommitted changes. Update '$Base' before editing, or commit on a branch first."
        }

        if ($behindBase -gt 0) {
            Write-Step "Fast-forwarding local $Base"
            Invoke-External git @('pull', '--ff-only', 'origin', $Base) -Mutating -ActionDescription "Fast-forward local $Base from origin/$Base"
        }

        if ([string]::IsNullOrWhiteSpace($BranchName)) {
            $BranchName = New-BranchSlug -Value $Title
        }

        $localBranchExists = $false
        & git show-ref --verify --quiet "refs/heads/$BranchName"
        if ($LASTEXITCODE -eq 0) {
            $localBranchExists = $true
        }

        if ($localBranchExists) {
            throw "Local branch '$BranchName' already exists. Use -BranchName to pick a fresh branch name or switch to that branch first."
        }

        Write-Step "Creating release branch $BranchName"
        Invoke-External git @('switch', '-c', $BranchName) -Mutating -ActionDescription "Create and switch to branch $BranchName"
        $currentBranch = $BranchName
    }
    else {
        if (-not [string]::IsNullOrWhiteSpace($BranchName) -and $BranchName -ne $currentBranch) {
            throw "You are on '$currentBranch'. Either omit -BranchName or switch branches before running the script."
        }

        $BranchName = $currentBranch
        Write-Step "Using existing branch $BranchName"

        $branchCounts = Get-AheadBehindCounts -Reference "origin/$Base"
        if ($branchCounts.Behind -gt 0 -and -not $AllowStaleBranch) {
            throw "Current branch '$BranchName' is behind 'origin/$Base' by $($branchCounts.Behind) commit(s). Update the branch first or pass -AllowStaleBranch to continue intentionally."
        }
        if ($branchCounts.Behind -gt 0) {
            Write-WarningLine "Current branch '$BranchName' is behind 'origin/$Base' by $($branchCounts.Behind) commit(s)."
        }
    }

    Write-Step 'Building the Astro app'
    Push-Location (Join-Path $repoRoot 'app')
    try {
        Invoke-External npm @('run', 'build')
    }
    finally {
        Pop-Location
    }

    $statusLines = @(Get-ExternalOutput git @('status', '--porcelain'))
    $hasChangesToCommit = $statusLines.Count -gt 0

    if ($hasChangesToCommit) {
        Write-Step 'Staging and committing changes'
        Write-Host 'Changed files:' -ForegroundColor DarkGray
        $statusLines | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }

        $selectedPaths = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })

        if ($selectedPaths.Count -gt 0) {
            Invoke-External git (@('add', '-A', '--') + $selectedPaths) -Mutating -ActionDescription "Stage selected paths: $($selectedPaths -join ', ')"
        }
        else {
            Write-WarningLine 'Staging all current changes because -Paths was not provided.'
            Invoke-External git @('add', '-A') -Mutating -ActionDescription 'Stage all current changes'
        }

        if ($isPreview) {
            Write-Host '[whatif] Skipping staged-change verification because no files were actually staged.' -ForegroundColor Yellow
        }
        else {
            $stagedLines = @(Get-ExternalOutput git @('diff', '--cached', '--name-status'))
            if ($stagedLines.Count -eq 0) {
                throw 'No staged changes were found after staging. Use -Paths that match changed files, or make sure there are changes to release.'
            }

            Write-Host 'Staged files:' -ForegroundColor DarkGray
            $stagedLines | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
        }

        Invoke-External git @('commit', '-m', $CommitMessage) -Mutating -ActionDescription "Create commit '$CommitMessage'"
    }
    else {
        $unpushedCommits = 0

        & git rev-parse --verify --quiet "origin/$BranchName" *> $null
        if ($LASTEXITCODE -eq 0) {
            $unpushedCommits = [int]((@(Get-ExternalOutput git @('rev-list', '--count', "origin/$BranchName..HEAD")))[-1].Trim())
        }

        if (-not $DryRun -and $unpushedCommits -eq 0) {
            throw 'No local changes or unpushed commits were found. There is nothing to release.'
        }

        if ($DryRun) {
            Write-Step 'Dry run: skipping no-changes release guard'
        }
        else {
            Write-Step 'No new commit created; using existing local commits on the branch'
        }
    }

    Write-Step 'Pushing the release branch'
    Invoke-External git @('push', '-u', 'origin', $BranchName) -Mutating -ActionDescription "Push branch $BranchName to origin"

    Write-Step 'Checking for an existing pull request'
    $existingPrNumber = $null
    $existingPrUrl = $null
    $existingPr = Get-OpenPullRequest -HeadBranch $BranchName -BaseBranch $Base

    if ($null -ne $existingPr) {
        $existingPrNumber = [string]$existingPr.number
        $existingPrUrl = [string]$existingPr.url
        Write-Host "Reusing PR #${existingPrNumber}: $existingPrUrl" -ForegroundColor Green
    }
    else {
        Invoke-External gh @('pr', 'create', '--base', $Base, '--head', $BranchName, '--title', $Title, '--body', $Body) -Mutating -ActionDescription "Create pull request from $BranchName to $Base"
        if ($isPreview) {
            $existingPrNumber = '<preview>'
            $existingPrUrl = '<created during execution>'
        }
        else {
            $createdPr = Get-OpenPullRequest -HeadBranch $BranchName -BaseBranch $Base
            if ($null -eq $createdPr) {
                throw "Pull request creation completed, but the open PR for branch '$BranchName' could not be retrieved."
            }
            $existingPrNumber = [string]$createdPr.number
            $existingPrUrl = [string]$createdPr.url
        }
        Write-Host "Created PR #${existingPrNumber}: $existingPrUrl" -ForegroundColor Green
    }

    if (-not $SkipAutoMerge) {
        if ($existingPrNumber) {
            Write-Step 'Enabling auto-merge'
            Invoke-External gh @('pr', 'merge', $existingPrNumber, '--auto', '--squash', '--delete-branch') -Mutating -ActionDescription "Enable auto-merge for PR #$existingPrNumber"
        }
    }

    Write-Step 'Release helper completed'
    Write-Host "Branch: $BranchName"
    if ($existingPrUrl) {
        Write-Host "PR: $existingPrUrl"
    }
    if ($SkipAutoMerge) {
        Write-Host 'Auto-merge was skipped. Merge the PR manually once checks pass.'
    }
    else {
        Write-Host 'If branch protection allows auto-merge, GitHub will merge after checks pass and production deployment will start from main.'
    }
}
finally {
    Pop-Location
}
