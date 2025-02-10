#!/bin/bash

# Start from repository root
cd "$(dirname "$0")/.."

# Exit on error
set -e

# Source the helper functions
source ./script/runes.sh

# Check for input arguments
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <base_chain> <leaf_chain1> [<leaf_chain2> ...]"
    exit 1
fi

# Read inputs
BASE_CHAIN=$1
shift
LEAF_CHAINS=("$@")

# Create new folder ./script/deployParameters
mkdir -p ./script/deployParameters

# For base, create a copy of ./script/deployTemplate/base/DeployRootBase.s.sol
# and replace "base.json" with the chain name .json
BASE_TEMPLATE="./script/deployTemplate/base/DeployRootBase.s.sol"
BASE_TARGET="./script/deployParameters/${BASE_CHAIN}/DeployRootBase.s.sol"
mkdir -p "$(dirname "$BASE_TARGET")"
sed "s/base.json/${BASE_CHAIN}.json/g" "$BASE_TEMPLATE" > "$BASE_TARGET"

# For each leaf, copy ./script/deployTemplate/leaf/DeployBase.s.sol
# and replace "leaf.json" with the chain name .json
LEAF_TEMPLATE="./script/deployTemplate/leaf/DeployBase.s.sol"
for LEAF_CHAIN in "${LEAF_CHAINS[@]}"; do
    LEAF_TARGET="./script/deployParameters/${LEAF_CHAIN}/DeployBase.s.sol"
    mkdir -p "$(dirname "$LEAF_TARGET")"
    sed "s/leaf.json/${LEAF_CHAIN}.json/g" "$LEAF_TEMPLATE" > "$LEAF_TARGET"
done

# Build contracts
echo "Building contracts..."
forge build

# Function to deploy a contract
deploy_contract() {
    local chain=$1
    local target=$2
    local contract_name=$3

    # Get etherscan API key for the chain
    local explorerFamily=$(meta $chain blockExplorers.0.family)
    if [ $explorerFamily == "etherscan" ]; then
        local etherscanApiKey=$(gcloud secrets versions access latest --secret="explorer-api-keys" | jq -r ".$chain")
        if [ ! -z "$etherscanApiKey" ] && [ "$etherscanApiKey" != "null" ] && [ "$etherscanApiKey" != "" ]; then
            export "ETHERSCAN_API_KEY=$etherscanApiKey"
        fi
    fi

    local verifierType
    if [ "$explorerFamily" = "blockscout" ]; then
        verifierType="blockscout"
    else
        verifierType="etherscan"
    fi

    local verifierUrl=$(meta $chain blockExplorers.0.apiUrl)

    # First run simulation
    forge script "$target":"$contract_name" --slow --rpc-url $(rpc "mainnet3" $chain) -vvvv
    # Then do actual deployment
    forge script "$target":"$contract_name" --slow --rpc-url $(rpc "mainnet3" $chain) --broadcast --verify -vvvv --verifier $verifierType --verifier-url $verifierUrl --private-key $(hypkey mainnet3) --evm-version paris
}

# Deploy base
deploy_contract "$BASE_CHAIN" "$BASE_TARGET" "DeployRootBase"

# Deploy leaves
for LEAF_CHAIN in "${LEAF_CHAINS[@]}"; do
    LEAF_TARGET="./script/deployParameters/${LEAF_CHAIN}/DeployBase.s.sol"
    deploy_contract "$LEAF_CHAIN" "$LEAF_TARGET" "DeployBase"
done
