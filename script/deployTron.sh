#!/bin/bash

# Deploys the oUSDT XERC20 leaf token to Tron.
#
# Tron's TVM cannot run the CreateX / CREATE3 deterministic-deployment scheme
# used on EVM chains (CREATE2 uses a 0x41 prefix and CREATE depends on the tx
# hash). This script instead replicates XERC20Factory.deployXERC20() directly:
# it deploys the XERC20 implementation and a TransparentUpgradeableProxy via the
# @hyperlane-xyz/tron-sdk TronWeb adapter. The resulting token is functionally
# identical to the EVM chains, but its address is NOT deterministic.
#
# Required environment variables:
#   TRON_RPC_URL      Tron full-node host or JSON-RPC endpoint
#                     (e.g. https://api.trongrid.io)
#   TRON_PRIVATE_KEY  Deployer private key (hex, with or without 0x)
# Optional:
#   TOKEN_ADMIN       Owner of the token + proxy admin
#                     (default: the staging admin used on EVM chains)
#   OUTPUT_FILENAME   Output file under deployment-addresses/ (default: tron.json)

set -e

# Start from repository root
cd "$(dirname "$0")/.."

if [ -z "$TRON_RPC_URL" ] || [ -z "$TRON_PRIVATE_KEY" ]; then
    echo "Usage: TRON_RPC_URL=<url> TRON_PRIVATE_KEY=<hex> [TOKEN_ADMIN=<0x..>] [OUTPUT_FILENAME=<name.json>] $0"
    exit 1
fi

# Build contracts (foundry.toml pins evm_version = paris, which is TVM-safe: no PUSH0).
echo "Building contracts..."
forge build

# Install JS deps if needed.
if [ ! -d "node_modules/@hyperlane-xyz/tron-sdk" ]; then
    echo "Installing JS dependencies..."
    yarn install
fi

# Deploy.
yarn deploy:tron
