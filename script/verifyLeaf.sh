#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
LEAF_X_FACTORY=
LEAF_X_ERC20=

RATE_LIMIT_LIBRARY=

# V2 Constants
TOKEN_ADMIN="0x0000000000000000000000000000000000000001"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# ENV Variables
source .env
ETHERSCAN_API_KEY=
ETHERSCAN_VERIFIER_URL=$BOB_ETHERSCAN_VERIFIER_URL
CHAIN_ID=60808

# XERC20Factory
forge verify-contract \
    $LEAF_X_FACTORY \
    src/xerc20/XERC20Factory.sol:XERC20Factory \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(address,address)()" $TOKEN_ADMIN $ADDRESS_ZERO) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY

# XERC20
forge verify-contract \
    $LEAF_X_E \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "Superchain Velodrome" "XVELO" $TOKEN_ADMIN $ADDRESS_ZERO) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY
