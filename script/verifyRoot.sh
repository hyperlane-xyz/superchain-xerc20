#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
ROOT_X_FACTORY=
ROOT_X_ERC20=
ROOT_X_LOCKBOX=

RATE_LIMIT_LIBRARY=

# V2 Constants
USDT="0x48065fbbe25f71c9282ddf5e1cd6d6a887483d5e"
TOKEN_ADMIN="0x0000000000000000000000000000000000000001"

# ENV Variables
source .env
ETHERSCAN_API_KEY=$CELO_ETHERSCAN_API_KEY
ETHERSCAN_VERIFIER_URL=$CELO_ETHERSCAN_VERIFIER_URL
CHAIN_ID=42220

# XERC20Factory
forge verify-contract \
    $ROOT_X_FACTORY \
    src/xerc20/XERC20Factory.sol:XERC20Factory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $TOKEN_ADMIN $USDT) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20
forge verify-contract \
    $ROOT_X_ERC20 \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "Super USDT" "XUSDT" $TOKEN_ADMIN $ROOT_X_LOCKBOX) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20LockBox
forge verify-contract \
    $ROOT_X_LOCKBOX \
    src/xerc20/XERC20Lockbox.sol:XERC20Lockbox \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $ROOT_X_ERC20 $USDT) \
    --compiler-version "v0.8.27" \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --verifier-url $ETHERSCAN_VERIFIER_URL
