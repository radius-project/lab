#Requires -Modules Az.Accounts, Az.Resources, Az.Aks

<#
.SYNOPSIS
    Setup Azure prerequisites for the Customer Support Agent.

.DESCRIPTION
    Creates: resource group, AKS cluster (if it doesn't exist),
    service principal, and registers required resource providers.
    Saves service principal credentials to .azure-sp.env for use by Radius.

.PARAMETER Location
    Azure region for resources. Default: westus3

.PARAMETER ResourceGroupName
    Name of the resource group. Default: customer-support-agent

.PARAMETER ClusterName
    Name of the AKS cluster. Default: customer-support-agent-aks

.EXAMPLE
    ./scripts/setup-azure.ps1
    ./scripts/setup-azure.ps1 -Location eastus2
    ./scripts/setup-azure.ps1 -ResourceGroupName my-rg -ClusterName my-aks
#>

[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'customer-support-agent',
    [string]$Location = 'westus3',
    [string]$ClusterName = 'customer-support-agent-aks'
)

$ErrorActionPreference = 'Stop'

$SpName = 'radius-sp'

# ── 0. Ensure Azure PowerShell is logged in ──────────────────
Write-Host '==> Checking Azure PowerShell login...'
$context = Get-AzContext
if (-not $context) {
    Write-Host '    Not logged in. Opening browser for login...'
    Connect-AzAccount
    $context = Get-AzContext
}

$SubscriptionId = $context.Subscription.Id
Write-Host "Subscription: $SubscriptionId"
Write-Host "Resource Group: $ResourceGroupName"
Write-Host "Location: $Location"
Write-Host "AKS Cluster: $ClusterName"
Write-Host ''

# ── 1. Register resource providers ────────────────────────────
Write-Host '==> Registering resource providers...'
$providers = @(
    'Microsoft.Storage'
    'Microsoft.DBforPostgreSQL'
    'Microsoft.ContainerInstance'
    'Microsoft.OperationalInsights'
    'Microsoft.Search'
    'Microsoft.CognitiveServices'
)
foreach ($provider in $providers) {
    Register-AzResourceProvider -ProviderNamespace $provider | Out-Null
    Write-Host "    ✓ $provider"
}

# ── 2. Create resource group ─────────────────────────────────
Write-Host ''
Write-Host "==> Creating resource group '$ResourceGroupName' in '$Location'..."
New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force | Out-Null

# ── 3. Create or connect to AKS cluster ──────────────────────
Write-Host ''
$existingCluster = Get-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $ClusterName -ErrorAction SilentlyContinue
if ($existingCluster) {
    Write-Host "==> AKS cluster '$ClusterName' already exists, getting credentials..."
    Import-AzAksCredential `
        -ResourceGroupName $ResourceGroupName `
        -Name $ClusterName `
        -Force
}
else {
    Write-Host "==> Creating AKS cluster '$ClusterName' (this takes a few minutes)..."
    $sshKey = Join-Path -Path $HOME -ChildPath '.ssh/id_rsa.pub'
    $aksParams = @{
        ResourceGroupName = $ResourceGroupName
        Name              = $ClusterName
        Location          = $Location
        NodeCount         = 1
        NodeVmSize        = 'Standard_D2s_v3'
    }
    if (Test-Path $sshKey) {
        $aksParams['SshKeyValue'] = $sshKey
    }
    else {
        $aksParams['GenerateSshKey'] = $true
    }
    New-AzAksCluster @aksParams

    Write-Host '==> Getting AKS credentials...'
    Import-AzAksCredential `
        -ResourceGroupName $ResourceGroupName `
        -Name $ClusterName `
        -Force
}

# ── 4. Create service principal ──────────────────────────────
Write-Host ''
Write-Host "==> Creating service principal '$SpName' with Owner role..."
$scope = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName"

# Create the AD application and service principal with a password credential
$sp = New-AzADServicePrincipal `
    -DisplayName $SpName `
    -Role 'Owner' `
    -Scope $scope

$ClientId = $sp.AppId
$ClientSecret = $sp.PasswordCredentials.SecretText
$TenantId = $context.Tenant.Id

# ── 5. Save credentials to file ──────────────────────────────
$envFile = '.azure-sp.env'
@"
AZURE_CLIENT_ID=$ClientId
AZURE_CLIENT_SECRET=$ClientSecret
AZURE_TENANT_ID=$TenantId
AZURE_SUBSCRIPTION_ID=$SubscriptionId
AZURE_RESOURCE_GROUP=$ResourceGroupName
"@ | Set-Content -Path $envFile -NoNewline

Write-Host ''
Write-Host "==> Service principal credentials saved to $envFile"

Write-Host ''
Write-Host '================================================'
Write-Host '  Azure setup complete!'
Write-Host '================================================'
Write-Host ''
