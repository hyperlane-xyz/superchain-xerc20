import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { createTronWallet } from './wallet.mts';

import { REPO_ROOT } from './artifacts.mts';
import {
  deployLeafXERC20,
  type ResumeState,
  type DeployedAddress,
} from './deployXERC20.mts';
import { evmToTronBase58 } from './tronAddress.mts';

/**
 * Default token admin / owner. Matches the `tokenAdmin` used by the EVM leaf
 * deploy templates (script/deployTemplate/leaf/DeployBase.s.sol).
 */
const DEFAULT_TOKEN_ADMIN = '0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba';

interface OutputFile {
  leafXERC20?: string;
  leafXERC20Tron?: string;
  leafXERC20Implementation?: string;
  leafXERC20ImplementationTron?: string;
  libraries?: Record<string, DeployedAddress>;
}

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

/** Serializes deployment state (partial or complete) to the output-file shape. */
function toOutputFile(state: ResumeState): OutputFile {
  const out: OutputFile = { libraries: state.libraries ?? {} };
  if (state.implementation) {
    out.leafXERC20Implementation = state.implementation;
    out.leafXERC20ImplementationTron = evmToTronBase58(state.implementation);
  }
  if (state.xerc20) {
    out.leafXERC20 = state.xerc20;
    out.leafXERC20Tron = evmToTronBase58(state.xerc20);
  }
  return out;
}

/** Reads a prior (possibly partial) deployment to resume from. */
function readResumeState(path: string): ResumeState {
  if (!existsSync(path)) return {};
  const file = JSON.parse(readFileSync(path, 'utf8')) as OutputFile;
  return {
    implementation: file.leafXERC20Implementation,
    xerc20: file.leafXERC20,
    libraries: file.libraries ?? {},
  };
}

async function main(): Promise<void> {
  const rpcUrl = requireEnv('TRON_RPC_URL');
  const privateKey = requireEnv('TRON_PRIVATE_KEY');
  const tokenAdmin = process.env.TOKEN_ADMIN ?? DEFAULT_TOKEN_ADMIN;
  const outputFilename = process.env.OUTPUT_FILENAME ?? 'tron.json';

  const wallet = createTronWallet(privateKey, rpcUrl);

  const dirPath = resolve(REPO_ROOT, 'deployment-addresses');
  mkdirSync(dirPath, { recursive: true });
  const outPath = resolve(dirPath, outputFilename);

  const resume = readResumeState(outPath);
  const resuming = !!(resume.xerc20 || resume.implementation || Object.keys(resume.libraries ?? {}).length);

  console.log('=== Tron oUSDT XERC20 leaf deployment ===');
  console.log(`RPC:          ${rpcUrl}`);
  console.log(`Deployer:     ${wallet.address} (${evmToTronBase58(wallet.address)})`);
  console.log(`Token admin:  ${tokenAdmin} (${evmToTronBase58(tokenAdmin)})`);
  console.log(`Output:       ${outPath}`);
  if (resuming) {
    console.log('Resuming from existing output file (deployed contracts will be reused).');
  }
  console.log('');
  console.log(
    'NOTE: the deployer account must hold enough TRX/energy. The SDK caps the ' +
      'fee limit at 1000 TRX per contract creation.',
  );
  console.log('');

  // Persist progress after every contract so a crashed run can be resumed.
  const persist = (state: ResumeState) => {
    writeFileSync(outPath, JSON.stringify(toOutputFile(state), null, 2) + '\n');
  };

  const deployment = await deployLeafXERC20(wallet, tokenAdmin, {
    log: (m) => console.log(m),
    resume,
    onProgress: persist,
  });

  console.log('');
  console.log(
    deployment.transactionHashes.length === 0
      ? '=== Already fully deployed (nothing to do) ==='
      : `=== Deployment complete (${deployment.transactionHashes.length} new contract(s)) ===`,
  );
  console.log(JSON.stringify(toOutputFile(deployment), null, 2));
  console.log(`\nWrote ${outPath}`);
}

main().catch((err) => {
  console.error('Deployment failed:', err);
  process.exitCode = 1;
});
