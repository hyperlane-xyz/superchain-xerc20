import { Contract, ContractFactory, constants, utils } from 'ethers';
import { TronContractFactory, type TronWallet } from '@hyperlane-xyz/tron-sdk';

import {
  libraryNames,
  linkBytecode,
  loadArtifact,
  loadLibraryArtifact,
  type ForgeArtifact,
} from './artifacts.mts';
import { evmToTronBase58 } from './tronAddress.mts';

/**
 * Token metadata. These mirror the `name`/`symbol` constants hardcoded in
 * `XERC20Factory` and the `decimals()` override in `XERC20`, so the Tron
 * deployment produces a token identical to the EVM chains.
 */
export const TOKEN_NAME = 'OpenUSDT';
export const TOKEN_SYMBOL = 'oUSDT';
export const TOKEN_DECIMALS = 6;

/**
 * Tron caps `originEnergyLimit` for contract creation at 10M. We request the
 * maximum so the large XERC20 implementation has enough energy headroom.
 * @see MAX_TRON_ORIGIN_ENERGY_LIMIT in @hyperlane-xyz/tron-sdk
 */
const MAX_ORIGIN_ENERGY_LIMIT = 10_000_000;

export interface DeployedAddress {
  evm: string;
  tron: string;
}

export interface LeafDeployment {
  /** XERC20 logic contract (implementation). */
  implementation: string;
  implementationTron: string;
  /** The canonical XERC20 token: a TransparentUpgradeableProxy over the impl. */
  xerc20: string;
  xerc20Tron: string;
  /** External libraries deployed and linked into the implementation. */
  libraries: Record<string, DeployedAddress>;
  /** Deployment transaction hashes, in order (libraries, impl, proxy). */
  transactionHashes: string[];
}

type Logger = (msg: string) => void;

/**
 * Previously-deployed pieces, used to resume/short-circuit a deployment.
 * Any contract listed here whose code is still present on-chain is reused
 * instead of being redeployed, which makes the deployment idempotent.
 */
export interface ResumeState {
  implementation?: string;
  xerc20?: string;
  /** Libraries keyed by contract short name (e.g. `RateLimitMidpointCommonLibrary`). */
  libraries?: Record<string, DeployedAddress>;
}

export interface DeployOptions {
  log?: Logger;
  /** Addresses from a prior (possibly partial) run to reuse. */
  resume?: ResumeState;
  /** Called after each contract is deployed/reused, for incremental persistence. */
  onProgress?: (state: ResumeState) => void | Promise<void>;
}

/** EIP-1967 storage slot holding the implementation address. */
export const EIP1967_IMPLEMENTATION_SLOT =
  '0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc';
/** EIP-1967 storage slot holding the admin (ProxyAdmin) address. */
export const EIP1967_ADMIN_SLOT =
  '0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103';

/** Deploys a single contract via TronWeb and waits for it to be mined. */
async function deployContract(
  wallet: TronWallet,
  abi: any[],
  bytecode: string,
  args: unknown[],
  label: string,
  log: Logger,
): Promise<{ address: string; txHash: string }> {
  log(`Deploying ${label}...`);
  const factory = new TronContractFactory(
    new ContractFactory(abi, bytecode),
    wallet,
  );
  const contract = await factory.deploy(...args, {
    gasLimit: MAX_ORIGIN_ENERGY_LIMIT,
  });
  await contract.deployTransaction.wait();
  log(`  ${label}: ${contract.address}`);
  return { address: contract.address, txHash: contract.deployTransaction.hash };
}

/** Whether an address currently holds deployed contract code. */
async function hasCode(wallet: TronWallet, address: string): Promise<boolean> {
  try {
    const code = await wallet.provider.getCode(address);
    return !!code && code !== '0x';
  } catch {
    return false;
  }
}

/**
 * Returns `existing` if it still holds code on-chain (reuse); otherwise runs
 * `deploy` and records its transaction hash. This is the idempotency primitive.
 */
async function resolveContract(
  wallet: TronWallet,
  log: Logger,
  existing: string | undefined,
  label: string,
  deploy: () => Promise<{ address: string; txHash: string }>,
  hashes: string[],
): Promise<string> {
  if (existing && (await hasCode(wallet, existing))) {
    log(`Reusing ${label}: ${existing}`);
    return existing;
  }
  const { address, txHash } = await deploy();
  hashes.push(txHash);
  return address;
}

/**
 * Deploys (or reuses) every external library referenced by `art` and returns
 * both the address map (keyed by short name) and the link map (keyed by
 * fully-qualified name) needed to link `art`'s bytecode.
 */
async function deployLibraries(
  wallet: TronWallet,
  art: ForgeArtifact,
  log: Logger,
  hashes: string[],
  resumeLibraries: Record<string, DeployedAddress> = {},
  onDeployed?: (libraries: Record<string, DeployedAddress>) => void | Promise<void>,
): Promise<{
  libraries: Record<string, DeployedAddress>;
  linkMap: Record<string, string>;
}> {
  const libraries: Record<string, DeployedAddress> = {};
  const linkMap: Record<string, string> = {};
  for (const fqName of libraryNames(art)) {
    const shortName = fqName.split(':')[1];
    const libArt = loadLibraryArtifact(fqName);
    const addr = await resolveContract(
      wallet,
      log,
      resumeLibraries[shortName]?.evm,
      `library ${shortName}`,
      () => deployContract(wallet, libArt.abi, libArt.bytecode, [], `library ${shortName}`, log),
      hashes,
    );
    linkMap[fqName] = addr;
    libraries[shortName] = { evm: addr, tron: evmToTronBase58(addr) };
    await onDeployed?.(libraries);
  }
  return { libraries, linkMap };
}

/**
 * Deploys every external library referenced by XERC20, links them, and deploys
 * the XERC20 implementation (`new XERC20(address(0))` — no lockbox on a leaf).
 * Reused both for the initial deployment and for deploying upgrade targets.
 */
export async function deployXERC20Implementation(
  wallet: TronWallet,
  log: Logger = () => {},
): Promise<{
  implementation: string;
  libraries: Record<string, DeployedAddress>;
  transactionHashes: string[];
}> {
  const xerc20Art = loadArtifact('XERC20');
  const transactionHashes: string[] = [];

  const { libraries, linkMap } = await deployLibraries(
    wallet,
    xerc20Art,
    log,
    transactionHashes,
  );

  const implementation = await resolveContract(
    wallet,
    log,
    undefined,
    'XERC20 implementation',
    () =>
      deployContract(
        wallet,
        xerc20Art.abi,
        linkBytecode(xerc20Art.bytecode, linkMap),
        [constants.AddressZero],
        'XERC20 implementation',
        log,
      ),
    transactionHashes,
  );

  return { implementation, libraries, transactionHashes };
}

/**
 * Reads a 0x-prefixed address stored at a given storage slot of a contract
 * (e.g. an EIP-1967 implementation/admin slot).
 */
export async function readAddressSlot(
  wallet: TronWallet,
  address: string,
  slot: string,
): Promise<string> {
  const raw = await wallet.provider.getStorageAt(address, slot);
  return utils.getAddress('0x' + raw.slice(-40));
}

/** Reads the ProxyAdmin address from a TransparentUpgradeableProxy. */
export function readProxyAdmin(
  wallet: TronWallet,
  proxy: string,
): Promise<string> {
  return readAddressSlot(wallet, proxy, EIP1967_ADMIN_SLOT);
}

/** Reads the current implementation address behind a proxy. */
export function readImplementation(
  wallet: TronWallet,
  proxy: string,
): Promise<string> {
  return readAddressSlot(wallet, proxy, EIP1967_IMPLEMENTATION_SLOT);
}

/**
 * Deploys the oUSDT XERC20 *leaf* token to Tron, replicating
 * `XERC20Factory.deployXERC20()` without CreateX/CREATE3 (unavailable on the
 * TVM). It:
 *   1. deploys + links every external library used by XERC20,
 *   2. deploys the XERC20 implementation (`new XERC20(address(0))` — no lockbox),
 *   3. deploys a TransparentUpgradeableProxy initialized with the token
 *      metadata and `tokenAdmin` as owner.
 *
 * Addresses are NOT deterministic on Tron and will differ from EVM chains.
 *
 * The deployment is resumable and idempotent: any contract present in
 * `opts.resume` whose code still exists on-chain is reused rather than
 * redeployed, and `opts.onProgress` is invoked after each step so partial
 * progress can be persisted and a crashed run continued without waste.
 *
 * @param wallet A funded `TronWallet` (the deployer).
 * @param tokenAdmin Owner of both the proxy admin and the XERC20 token.
 * @param opts Logging, resume state, and progress callback.
 */
export async function deployLeafXERC20(
  wallet: TronWallet,
  tokenAdmin: string,
  opts: DeployOptions = {},
): Promise<LeafDeployment> {
  if (!utils.isAddress(tokenAdmin) || tokenAdmin === constants.AddressZero) {
    throw new Error(`Invalid tokenAdmin: ${tokenAdmin}`);
  }

  const log = opts.log ?? (() => {});
  const resume = opts.resume ?? {};
  const state: ResumeState = {
    libraries: { ...(resume.libraries ?? {}) },
    implementation: resume.implementation,
    xerc20: resume.xerc20,
  };
  const emit = () => opts.onProgress?.(state);
  const transactionHashes: string[] = [];

  const xerc20Art = loadArtifact('XERC20');
  const proxyArt = loadArtifact('TransparentUpgradeableProxy');

  // 1. Deploy + link the external libraries.
  const { libraries, linkMap } = await deployLibraries(
    wallet,
    xerc20Art,
    log,
    transactionHashes,
    state.libraries,
    async (libs) => {
      state.libraries = libs;
      await emit();
    },
  );
  state.libraries = libraries;

  // 2. Deploy the XERC20 implementation (`new XERC20(address(0))` on a leaf).
  const implementation = await resolveContract(
    wallet,
    log,
    state.implementation,
    'XERC20 implementation',
    () =>
      deployContract(
        wallet,
        xerc20Art.abi,
        linkBytecode(xerc20Art.bytecode, linkMap),
        [constants.AddressZero],
        'XERC20 implementation',
        log,
      ),
    transactionHashes,
  );
  state.implementation = implementation;
  await emit();

  // 3. Deploy the TransparentUpgradeableProxy(logic, initialOwner, data). Its
  //    constructor delegatecalls initialize(name, symbol, owner).
  const initData = new utils.Interface(xerc20Art.abi).encodeFunctionData(
    'initialize',
    [TOKEN_NAME, TOKEN_SYMBOL, tokenAdmin],
  );
  const xerc20 = await resolveContract(
    wallet,
    log,
    state.xerc20,
    'TransparentUpgradeableProxy (XERC20)',
    () =>
      deployContract(
        wallet,
        proxyArt.abi,
        proxyArt.bytecode,
        [implementation, tokenAdmin, initData],
        'TransparentUpgradeableProxy (XERC20)',
        log,
      ),
    transactionHashes,
  );
  state.xerc20 = xerc20;
  await emit();

  // 4. Verify the deployed token reflects the expected configuration.
  await verifyDeployment(wallet, xerc20, tokenAdmin, xerc20Art);

  return {
    implementation,
    implementationTron: evmToTronBase58(implementation),
    xerc20,
    xerc20Tron: evmToTronBase58(xerc20),
    libraries,
    transactionHashes,
  };
}

/**
 * Reads back the deployed token through the proxy and asserts that the
 * initializer ran with the expected metadata, owner, decimals and that no
 * lockbox is wired (leaf deployment).
 */
export async function verifyDeployment(
  wallet: TronWallet,
  xerc20: string,
  tokenAdmin: string,
  xerc20Art: ForgeArtifact = loadArtifact('XERC20'),
): Promise<void> {
  const token = new Contract(xerc20, xerc20Art.abi, wallet);

  const [name, symbol, decimals, owner, lockbox, totalSupply] =
    await Promise.all([
      token.name(),
      token.symbol(),
      token.decimals(),
      token.owner(),
      token.lockbox(),
      token.totalSupply(),
    ]);

  const checks: Array<[string, unknown, unknown]> = [
    ['name', name, TOKEN_NAME],
    ['symbol', symbol, TOKEN_SYMBOL],
    ['decimals', Number(decimals), TOKEN_DECIMALS],
    ['owner', String(owner).toLowerCase(), tokenAdmin.toLowerCase()],
    ['lockbox', String(lockbox), constants.AddressZero],
    ['totalSupply', String(totalSupply), '0'],
  ];

  for (const [field, actual, expected] of checks) {
    if (actual !== expected) {
      throw new Error(
        `Post-deploy verification failed for ${field}: got ${String(
          actual,
        )}, expected ${String(expected)}`,
      );
    }
  }
}
