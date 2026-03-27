#!/bin/bash
set -euo pipefail

# ── Setup Azure prerequisites for the Customer Support Agent ──
# Creates: resource group, AKS cluster (if it doesn't exist),
# service principal, and registers required resource providers.
# Saves service principal credentials to .azure-sp.env for use by Radius.
#
# Usage:
#   ./scripts/setup-azure.sh                                 # defaults: westus3, customer-support-agent
#   ./scripts/setup-azure.sh --location eastus2              # custom location
#   ./scripts/setup-azure.sh --resource-group my-rg          # custom resource group name
#   ./scripts/setup-azure.sh --cluster-name my-aks           # uses existing cluster or creates one

RESOURCE_GROUP="customer-support-agent"
LOCATION="westus3"
CLUSTER_NAME="customer-support-agent-aks"
SP_NAME="radius-sp"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
  --location)
    LOCATION="$2"
    shift 2
    ;;
  --resource-group)
    RESOURCE_GROUP="$2"
    shift 2
    ;;
  --cluster-name)
    CLUSTER_NAME="$2"
    shift 2
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
  esac
done

# Sanitize variables for cross-platform compatibility (remove CRLF remnants)
sanitize() {
  # remove carriage returns if present
  printf '%s' "$1" | tr -d '\r'
}

RESOURCE_GROUP=$(sanitize "$RESOURCE_GROUP")
LOCATION=$(sanitize "$LOCATION")
CLUSTER_NAME=$(sanitize "$CLUSTER_NAME")
SP_NAME=$(sanitize "$SP_NAME")

# ── 0. Ensure Azure CLI is logged in ─────────────────────
echo "==> Checking Azure CLI login..."
if ! az account show &>/dev/null; then
  echo "    Not logged in. Opening browser for login..."
  az login
fi

SUBSCRIPTION_ID=$(sanitize "$(az account show --query id -o tsv)")
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "AKS Cluster: $CLUSTER_NAME"
echo ""

# ── 1. Register resource providers ──────────────────────────
echo "==> Registering resource providers..."
PROVIDERS=(
  Microsoft.Storage
  Microsoft.DBforPostgreSQL
  Microsoft.ContainerInstance
  Microsoft.OperationalInsights
  Microsoft.Search
  Microsoft.CognitiveServices
)
for provider in "${PROVIDERS[@]}"; do
  az provider register --namespace "$provider" --wait 2>/dev/null || true
  echo "    ✓ $provider"
done

# ── 2. Create resource group ────────────────────────────────
echo ""
echo "==> Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none

# ── 3. Create or connect to AKS cluster ─────────────────────
echo ""
if az aks show --resource-group "$RESOURCE_GROUP" --name "$CLUSTER_NAME" &>/dev/null; then
  echo "==> AKS cluster '$CLUSTER_NAME' already exists, getting credentials..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing
else
  echo "==> Creating AKS cluster '$CLUSTER_NAME' (this takes a few minutes)..."
  az aks create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --generate-ssh-keys \
    --node-count 1 \
    --node-vm-size Standard_D2s_v3

  echo "==> Getting AKS credentials..."
  az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$CLUSTER_NAME" \
    --overwrite-existing
fi

# ── 4. Create service principal ─────────────────────────────
echo ""
echo "==> Creating service principal '$SP_NAME' with Owner role..."
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role Owner \
  --scopes /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP \
  -o json)

CLIENT_ID=$(echo "$SP_OUTPUT" | jq -r '.appId')
CLIENT_SECRET=$(echo "$SP_OUTPUT" | jq -r '.password')
TENANT_ID=$(echo "$SP_OUTPUT" | jq -r '.tenant')

# ── 5. Save credentials to file ─────────────────────────────
ENV_FILE=".azure-sp.env"
cat >"$ENV_FILE" <<EOF
AZURE_CLIENT_ID=$CLIENT_ID
AZURE_CLIENT_SECRET=$CLIENT_SECRET
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
AZURE_RESOURCE_GROUP=$RESOURCE_GROUP
EOF
echo ""
echo "==> Service principal credentials saved to $ENV_FILE"

echo ""
echo "================================================"
echo "  Azure setup complete!"
echo "================================================"
echo ""
