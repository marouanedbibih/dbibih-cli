#!/bin/bash

# Login to Azure if not already logged in
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "🔑 Logging into Azure..."
  az login --use-device-code
fi

# Get subscription ID
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Get tenant ID
export ARM_TENANT_ID=$(az account show --query tenantId -o tsv)

# Service principal credentials (replace with your app registration name)
APP_NAME="my-terraform-sp"

# Check if service principal exists
SP_APPID=$(az ad sp list --display-name "$APP_NAME" --query "[0].appId" -o tsv)

if [ -z "$SP_APPID" ]; then
  echo "⚙️ Creating service principal $APP_NAME..."
  SP_JSON=$(az ad sp create-for-rbac \
    --name "$APP_NAME" \
    --role="Contributor" \
    --scopes="/subscriptions/$ARM_SUBSCRIPTION_ID" \
    -o json)
else
  echo "✅ Service principal $APP_NAME already exists. Resetting credentials..."
  SP_JSON=$(az ad sp credential reset \
    --name "$SP_APPID" \
    -o json)
fi

# Extract client ID and secret
export ARM_CLIENT_ID=$(echo $SP_JSON | jq -r '.appId')
export ARM_CLIENT_SECRET=$(echo $SP_JSON | jq -r '.password')

# Print summary
echo "===================================="
echo " Azure Authentication Information"
echo "===================================="
echo "export ARM_SUBSCRIPTION_ID=$ARM_SUBSCRIPTION_ID"
echo "export ARM_TENANT_ID=$ARM_TENANT_ID"
echo "export ARM_CLIENT_ID=$ARM_CLIENT_ID"
echo "export ARM_CLIENT_SECRET=$ARM_CLIENT_SECRET"
echo "===================================="
