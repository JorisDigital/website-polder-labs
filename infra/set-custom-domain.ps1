param(
    [string]$ResourceGroupName = 'rg-website-polder-labs-prd',
    [string]$StaticWebAppName = 'website-polder-labs-prd-260307',
    [string]$Hostname = 'www.polder-labs.nl',
    [ValidateSet('cname-delegation', 'dns-txt-token')]
    [string]$ValidationMethod = 'cname-delegation'
)

$azPath = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd'

if (-not (Test-Path $azPath)) {
    throw "Azure CLI not found at $azPath"
}

Write-Host "Binding custom domain '$Hostname' to '$StaticWebAppName'..."

& $azPath staticwebapp hostname set `
    --resource-group $ResourceGroupName `
    --name $StaticWebAppName `
    --hostname $Hostname `
    --validation-method $ValidationMethod

if ($LASTEXITCODE -ne 0) {
    throw 'Failed to bind custom domain.'
}

Write-Host ''
Write-Host 'Current custom domains:'

& $azPath staticwebapp hostname list `
    --resource-group $ResourceGroupName `
    --name $StaticWebAppName `
    -o table