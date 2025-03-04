# Superchain

The contracts in this repository extend the Velodrome superchain XERC20 contracts with the behavior required for OpenUSDT.

## Nomenclature

- The _root_ chain refers to the collateral chain that USDT exists on. This is currently 
Celo.
- The _leaf_ chain refers to any chain that OpenUSDT expands to.

### Miscellaneous

Most contracts in this repository will be deployed via [CREATEX](https://github.com/pcaversaccio/createx).
This is available on many chains already and will be available as a [preinstall](https://github.com/ethereum-optimism/specs/blob/8106c9d8b358aea863cd30d1cccc403466b63bc6/specs/protocol/preinstalls.md?plain=1#L162) on the Superchain.

The following contracts are deployed via CREATE3:

- XERC20
- XERC20Lockbox
- XERC20Factory

As contracts are deployed via CREATE3, the implementation for the leaf chains must be reviewed before 
it is enabled. This is because the code at the address could be different. The expectation is that 
the root chain will run root code (housed in the `root` folder) and the leaf chains will all 
operate the same leaf code. If there are differences in leaf chain code, it may be to support features
not available on other chains (e.g. gas fee sharing).

## XERC20

The XERC20 implementation is a lightly modified version of the XERC20 implementation used by Moonwell,
available [here](https://github.com/moonwell-fi/moonwell-contracts-v2/tree/main/src/xWELL). The
implementation deviates from the standard XERC20 implementation in the following ways:

- Limits are managed by using a two sided buffer.
- The structs used to manage bridge limits have been modified.
- The function `setLimits(bridge, mintingLimit, burningLimit)` is now `setBufferCap(bridge, newBufferCap)`
and `setRateLimitPerSecond(bridge, newRateLimitPerSecond)`.

In addition to the above changes, our XERC20 implementation includes a lockbox and an XERC20Factory, 
that uses CREATE3 to deploy the XERC20 contracts. This ensures the contract has the same address on
all chains.

The XERC20 implementation has also been lightly modified to support [SuperchainERC20](https://github.com/ethereum-optimism/specs/blob/main/specs/interop/token-bridging.md). A sample implementation is available [here](https://github.com/defi-wonderland/optimism/blob/develop/packages/contracts-bedrock/src/L2/SuperchainERC20.sol). This interface is also rate limited as per XERC20.

## XERC20Lockbox

The Lockbox contract includes the `withdrawTo` function from the original XERC20Lockbox implementation. This enables compatibility with Hyperlane's [existing warp route XERC20 lockbox adapter](https://github.com/hyperlane-xyz/hyperlane-monorepo/blob/0f870903b336801579e963042690cee513071aa0/solidity/contracts/token/extensions/HypXERC20Lockbox.sol#L74).
