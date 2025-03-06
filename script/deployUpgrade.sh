#!/bin/bash

source ~/.bashrc

# set -x 

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file.yaml>"
    exit 1
fi

file="$1"  # YAML file passed as an argument
chain_names=$(yq '.tokens[].chainName' "$file")
echo "chains: ${chain_names}"


for chain_name in $chain_names; do
    address=$(yq ".tokens[] | select(.chainName == \"${chain_name}\") | .addressOrDenom" "$file")

    # Check if address was found
    if [ -z "$address" ]; then
        echo "No address found for chain: $chain_name"
        continue
    fi

    WARP_ROUTE=$address  XERC20=0x1217bfe6c773eec6cc4a38b5dc45b92292b6e189 forge script script/xerc20/UpgradeXERC20.s.sol --fork-url $(rpc mainnet3 $chain_name) --broadcast --sender 0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba --tc UpgradeXERC20    

done