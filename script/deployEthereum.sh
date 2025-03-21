#!/bin/bash

# Source bashrc if it exists
if [ -f "$HOME/.bashrc" ]; then
    source "$HOME/.bashrc"
fi

# Start from repository root
cd "$(dirname "$0")/.."

# Exit on error
set -e

# Set chain to Ethereum
CHAIN_NAME="ethereum"

# Create deployment parameters directory
mkdir -p ./script/deployParameters/${CHAIN_NAME}

# Copy the Ethereum deployment template
TEMPLATE="./script/deployTemplate/manualLockbox/DeployWithLockbox.sol"
TARGET="./script/deployParameters/${CHAIN_NAME}/DeployWithLockbox.s.sol"
mkdir -p "$(dirname "$TARGET")"
cp "$TEMPLATE" "$TARGET"

# Build contracts
echo "Building contracts..."
forge build

# Get etherscan API key
explorerFamily=$(meta $CHAIN_NAME blockExplorers.0.family)
if [ $explorerFamily == "etherscan" ]; then
    etherscanApiKey=$(gcloud secrets versions access latest --secret="explorer-api-keys" | jq -r ".$CHAIN_NAME")
    if [ ! -z "$etherscanApiKey" ] && [ "$etherscanApiKey" != "null" ] && [ "$etherscanApiKey" != "" ]; then
        export "ETHERSCAN_API_KEY=$etherscanApiKey"
    fi
fi

verifierUrl=$(meta $CHAIN_NAME blockExplorers.0.apiUrl)
verifierType="etherscan"

# Run simulation
echo "Running simulation for Ethereum deployment..."
if ! forge script "$TARGET":"DeployWithLockbox" --slow --rpc-url $(rpc "mainnet3" $CHAIN_NAME) -v; then
    echo "Simulation failed for Ethereum"
    exit 1
fi

# Do actual deployment
echo "Deploying to Ethereum..."
if ! forge script "$TARGET":"DeployWithLockbox" --slow --rpc-url $(rpc "mainnet3" $CHAIN_NAME) --broadcast --verify -v --verifier $verifierType --verifier-url $verifierUrl --private-key $(hypkey mainnet3) --evm-version paris; then
    echo "Deployment failed for Ethereum"
    exit 1
fi

echo "Ethereum deployment completed successfully"
