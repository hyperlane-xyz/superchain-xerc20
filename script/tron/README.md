# Tron deployment for oUSDT (XERC20)

This directory deploys the **leaf** oUSDT `XERC20` token to the **Tron** blockchain.

## Why this exists (Tron is not a normal EVM chain)

Every EVM chain in this repo is deployed with Foundry through **CreateX** (at
`0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed`) using **CREATE3** so the
`XERC20Factory` and token land at the same deterministic address everywhere.

That scheme **cannot be reused on Tron**:

- Foundry has no native Tron broadcast backend; Tron's JSON-RPC does not support
  `eth_sendRawTransaction`. Deployment must go through TronWeb.
- Tron's `CREATE2` opcode uses a `0x41` address prefix instead of Ethereum's
  `0xff`, so CreateX's (Ethereum-compiled) address math is wrong on Tron.
- Tron's `CREATE` derives the address from `keccak256(txID ++ owner)` — it
  depends on the transaction hash, so CREATE3's inner proxy deploy is
  non-deterministic.

Net effect: **deterministic, cross-chain-matching addresses are impossible on
Tron.** So this deployer skips CreateX entirely and replicates what
`XERC20Factory.deployXERC20()` does, directly via TronWeb:

1. deploy the `XERC20` implementation (`new XERC20(address(0))` — no lockbox on a leaf), then
2. deploy a `TransparentUpgradeableProxy(impl, tokenAdmin, initialize("OpenUSDT", "oUSDT", tokenAdmin))`.

The token is byte-for-byte the same contract as on EVM chains (same Foundry
artifacts); only the address differs and there is no on-chain factory.

It builds on the [`@hyperlane-xyz/tron-sdk`](https://www.npmjs.com/package/@hyperlane-xyz/tron-sdk)
ethers-v5 adapter (`TronWallet` + `TronContractFactory`), the same library
Hyperlane uses to deploy to Tron.

## Files

- `artifacts.mts` — loads Foundry `out/*.sol/*.json` (ABI + creation bytecode).
- `tronAddress.mts` — EVM `0x…` → Tron base58 `T…` conversion.
- `deployXERC20.mts` — core deploy + post-deploy verification.
- `index.mts` — CLI entry; reads env, deploys, writes `deployment-addresses/<file>.json`.
- `deployXERC20.integration.test.mts` — end-to-end test against a local Tron node.

## Usage

```bash
# from the repo root
forge build   # produces out/*.sol/*.json (evm_version = paris, TVM-safe)
yarn install

TRON_RPC_URL=https://api.trongrid.io \
TRON_PRIVATE_KEY=<hex private key> \
TOKEN_ADMIN=0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba \
OUTPUT_FILENAME=tron.json \
yarn deploy:tron
```

or via the wrapper: `TRON_RPC_URL=… TRON_PRIVATE_KEY=… ./script/deployTron.sh`.

`TOKEN_ADMIN` defaults to the staging admin used by the EVM leaf templates.
The output JSON records both the EVM (`0x…`) and Tron (`T…`) addresses for the
token, its implementation, and the linked library.

### `TRON_RPC_URL` (important)

`TRON_RPC_URL` is used for **both** reads (ethers JSON-RPC) and for
building/signing/**broadcasting** transactions (the Tron HTTP API). It must
therefore point at an endpoint that serves the Tron HTTP API (`/wallet/*`), i.e.
a full node or a provider that proxies one — not a JSON-RPC-only endpoint.

> `@hyperlane-xyz/tron-sdk@23`'s `TronWallet` silently routes broadcasting to the
> **public** `https://api.trongrid.io` for any host that isn't `localhost` or
> `*trongrid*` — which ignores your private RPC and gets rate-limited (429).
> This deployer works around that (`createTronWallet` in `wallet.mts`): the host
> you pass in `TRON_RPC_URL` is the host actually used to broadcast.

Authenticate with an API key (e.g. TronGrid) by appending a `custom_rpc_header`:

```
TRON_RPC_URL='https://api.trongrid.io/jsonrpc?custom_rpc_header=TRON-PRO-API-KEY:<key>'
```

### Resumable & idempotent

A full deployment is three contract creations (library → implementation →
proxy). Progress is persisted to the output file **after each contract**, and on
start the script loads that file and **reuses any contract whose code is still
on-chain**. So:

- **Crash recovery:** if a run dies partway (e.g. the implementation creation
  hits the fee limit), just re-run the same command — already-deployed
  contracts are skipped and only the missing ones are deployed. No TRX is
  wasted redeploying what already exists.
- **Idempotent:** re-running after a successful deployment is a no-op
  (`Already fully deployed (nothing to do)`).
- **Force a fresh deployment:** delete (or point `OUTPUT_FILENAME` away from)
  the existing `deployment-addresses/<file>.json`.

> Addresses are not deterministic on Tron, so "reuse" means reusing the recorded
> address from the previous run, not recomputing it. A stale recorded address
> with no code on-chain is treated as not-deployed and re-created.

> **Cost / energy.** A full deployment is 3 contract creations. Measured energy
> (deterministic for this bytecode):
>
> | contract        | energy    | ~TRX @ 420 SUN/energy |
> | --------------- | --------- | --------------------- |
> | library         | ~129k     | ~54                   |
> | implementation  | ~2.30M    | ~964                  |
> | proxy           | ~695k     | ~292                  |
> | **total**       | **~3.12M**| **~1310**             |
>
> The `deployment cost` integration test asserts and prints these numbers.
>
> ⚠️ The SDK fee-limits **each** creation to **1000 TRX**. At 420 SUN/energy the
> implementation creation (~2.3M energy ≈ **964 TRX**) is already close to that
> cap — if the live energy price is above ~435 SUN/energy, that creation will
> exceed the fee limit and revert. Mitigate by **staking enough energy** on the
> deployer (so TRX isn't burned for energy) before deploying. Check the live
> price via the `wallet/getenergyprices` endpoint.

## Testing

The integration test spins up a real Tron node (`tronbox/tre:dev`) via
[testcontainers] and runs the actual deployment against it, then exercises both
normal and governance usage on the live TVM:

- metadata / owner / decimals / leaf invariants,
- a bridge mint → transfer → burn roundtrip (incl. allowance-based burn),
- owner-only bridge management (add / reconfigure / remove) and non-owner rejection,
- token ownership transfer (former owner loses access, new owner gains it),
- proxy upgrade via `ProxyAdmin.upgradeAndCall` (implementation slot changes, state preserved),
- proxy (ProxyAdmin) ownership transfer and rejection of upgrades from the former admin.

```bash
# requires Docker running
yarn typecheck:tron   # type-check
yarn test:tron        # integration test on a local TRE node
```

[testcontainers]: https://node.testcontainers.org/
