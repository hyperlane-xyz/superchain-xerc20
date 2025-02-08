#!/bin/bash

# Usage:
#   hypkey <environment> <role>
# Defaults to mainnet3 deployer.
hypkey() {
  local monorepo="$HOME/hypkey/hyperlane-monorepo"
  # First param or default to mainnet3
  local environment="${1:-mainnet3}"
  # Second param or default to deployer
  local role="${2:-deployer}"

  # get the key
  yarn --cwd $monorepo/typescript/infra --silent run tsx scripts/keys/get-key.ts -e $environment --role $role
}

# Function to read contract addresses from chains
addr() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: addr <chain> <contractName>"
    return 1
  fi

  local registry="$HOME/hypkey/hyperlane-registry"
  local chain=$1
  local contract=$2

  # Assuming addresses are stored in addresses/<chain>.yaml
  if [ -f "${registry}/chains/${chain}/addresses.yaml" ]; then
    cat "${registry}/chains/${chain}/addresses.yaml" | yq -r ".$contract"
  else
    echo "Chain file not found: ${registry}/chains/${chain}/addresses.yaml"
    return 1
  fi
}

# Function to read metadata using dot notation
meta() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: meta <chain> <yaml.key.path>"
    return 1
  fi

  local registry="$HOME/hypkey/hyperlane-registry"
  local chain=$1
  local keypath=$2

  # Handle RPC shortcuts
  if [[ $keypath == "rpc" ]]; then
    keypath="rpcUrls.0.http"
  elif [[ $keypath =~ ^rpc[0-9]+$ ]]; then
    local rpcIndex=${keypath#rpc}  # Remove 'rpc' prefix to get the number
    keypath="rpcUrls.${rpcIndex}.http"
  fi

  # Assuming metadata is stored in metadata/<chain>.json
  if [ -f "${registry}/chains/${chain}/metadata.yaml" ]; then
    cat "${registry}/chains/${chain}/metadata.yaml" | yq -r ".$keypath"
  else
    echo "Metadata file not found: ${registry}/chains/${chain}/metadata.yaml"
    return 1
  fi
}

# Function to read RPC URLs from Google Cloud Secrets
rpc() {
  if [ "$#" -ne 2 ]; then
    echo "Usage: rpc <environment> <chain>"
    return 1
  fi

  # First param or default to mainnet3
  local environment="${1:-mainnet3}"
  local chain=$2
  local secret="${environment}-rpc-endpoints-${chain}"

  # Get the secret value and parse the JSON to extract the RPC URL
  gcloud secrets versions access latest --secret="$secret" | jq -r '.[0]'
}
