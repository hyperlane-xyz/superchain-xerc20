# Velodrome Superchain Contracts

Core smart contracts for the Velodrome Superchain. This includes the Superchain
specific contracts (message passing, xERC20, etc) as well as the base v2 contracts.

For information on specific contracts, see `SPECIFICATION.md.`. Integrators should
refer to the integrators section below.

## Installation

This repository depends on:

node v20 (recommend managing node versions using nvm)
foundry
yarn

To install & run:

```
yarn install
forge b

forge t -vv
```

This repository uses `forge fmt` to format code and bulloak for test layouts.

## Deployment

Populate `foundry.toml` with the environment variables required for RPC and contract verification.

Run the following commands to check that the CreateX factory has the correct code. See [here](https://github.com/pcaversaccio/createx/blob/43adf407f1313c5975c7db106092c3b636323ef6/README.md?plain=1#L844) for more information. This is now done in the script, but feel free to check.

```
[[ $(cast keccak $(cast code 0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed --rpc-url {RPC_URL})) == "0xbd8a7ea8cfca7b4e5f5041d7d4b17bc317c5ce42cfbc42066a00cf26b43eb53f" ]] && echo "Hash Matches" || echo "Hash Does Not Match"
```

Deploy Root contracts first:

```
forge script script/deployParameters/optimism/DeployRootBase.s.sol:DeployRootBase --slow --rpc-url optimism -vvvv
forge script script/deployParameters/optimism/DeployRootBase.s.sol:DeployRootBase --slow --rpc-url optimism --broadcast --verify -vvvv
```

Deploy Leaf contracts next:

Replace `leaf` with the chain you are deploying to.

```
forge script script/deployParameters/leaf/DeployBase.s.sol:DeployBase --slow --rpc-url leaf -vvvv
forge script script/deployParameters/leaf/DeployBase.s.sol:DeployBase --slow --rpc-url leaf --broadcast --verify -vvvv
```

If there is a verification failure, simply remove `--broadcast` and add `--resume`.

## Verification

For verifications, fill out the verifier config in `foundry.toml`.

For blockscout verifications, append `--verifier blockscout` after `--verify`

## xERC20

The xERC20 implementation in this repository has been modified lightly from 
the moonwell xERC20 implementation to support native Superchain interop in the future.

## Licensing

This project follows the [Apache Foundation](https://infra.apache.org/licensing-howto.html)
guideline for licensing. See LICENSE and NOTICE files.

## Deployments

| Chain      | Addresses          | 
|------------|--------------------|
| Arbitrum   |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/arbitrum.json) |
| Base       |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/base.json) |
| Bob        |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/bob.json) |
| Celo       |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/celo.json) |
| Fraxtal    |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/fraxtal.json) |
| Ink        |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/ink.json) |
| Lisk       |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/lisk.json) |
| Mantle     |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/mantle.json) |
| Metal      |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/metal.json) |
| Mode       |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/mode.json) |
| Optimism   |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/optimism.json) |
| Polygon    |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/polygon.json) |
| Soneium    |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/soneium.json) |
| Superseed  |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/superseed.json) |
| Unichain   |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/unichain.json) |
| Worldchain |[Addresses](https://github.com/hyperlane-xyz/superchain-xerc20/blob/main/deployment-addresses/worldchain.json) |

Optimism contains the root deployment contracts, and these factory addresses are 
used by all leaf chains.
