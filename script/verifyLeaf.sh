#!/bin/bash

# Contract Addresses
# Deployed with superchain contracts
LEAF_X_FACTORY=0xB5496C94c019D90B8375E58038Fe4D1DC990e699
LEAF_X_ERC20=0x2ea4bE6722F9D92835F21443C20370682d37c3eE

RATE_LIMIT_LIBRARY=

# V2 Constants
TOKEN_ADMIN="0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba"
ADDRESS_ZERO="0x0000000000000000000000000000000000000000"

# ENV Variables
source .env
ETHERSCAN_API_KEY=
ETHERSCAN_VERIFIER_URL="https://explorer.gobob.xyz/api"
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
    $LEAF_X_ERC20 \
    src/xerc20/XERC20.sol:XERC20 \
    --chain-id $CHAIN_ID \
    --num-of-optimizations 200 \
    --watch \
    --constructor-args $(cast ae "constructor(string,string,address,address)()" "OpenUSDT" "USDT" $TOKEN_ADMIN $ADDRESS_ZERO) \
    --compiler-version "v0.8.27" \
    --verifier blockscout \
    --verifier-url $ETHERSCAN_VERIFIER_URL \
    --libraries src/libraries/rateLimits/RateLimitMidpointCommonLibrary.sol:RateLimitMidpointCommonLibrary:$RATE_LIMIT_LIBRARY
