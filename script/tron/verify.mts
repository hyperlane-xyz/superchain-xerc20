import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

import { Contract } from 'ethers';
import { TronJsonRpcProvider } from '@hyperlane-xyz/tron-sdk';

import { loadArtifact, REPO_ROOT } from './artifacts.mts';
import {
  EIP1967_ADMIN_SLOT,
  EIP1967_IMPLEMENTATION_SLOT,
  TOKEN_DECIMALS,
  TOKEN_NAME,
  TOKEN_SYMBOL,
} from './deployXERC20.mts';
import { evmToTronBase58 } from './tronAddress.mts';

const DEFAULT_TOKEN_ADMIN = '0xa7ECcdb9Be08178f896c26b7BbD8C3D4E844d9Ba';

interface OutputFile {
  leafXERC20?: string;
  leafXERC20Tron?: string;
  leafXERC20Implementation?: string;
  leafXERC20ImplementationTron?: string;
  libraries?: Record<string, { evm: string; tron: string }>;
}

let failures = 0;
function check(label: string, ok: boolean, detail = ''): void {
  const mark = ok ? '✅' : '❌';
  if (!ok) failures++;
  console.log(`  ${mark} ${label}${detail ? `  ${detail}` : ''}`);
}

function addrEq(a?: string, b?: string): boolean {
  return !!a && !!b && a.toLowerCase() === b.toLowerCase();
}

function slotToAddress(raw: string): string {
  return '0x' + raw.slice(-40);
}

async function main(): Promise<void> {
  const rpcUrl = process.env.TRON_RPC_URL ?? 'https://api.trongrid.io/jsonrpc';
  const outputFilename = process.env.OUTPUT_FILENAME ?? 'tron.json';
  const expectedAdmin = process.env.TOKEN_ADMIN ?? DEFAULT_TOKEN_ADMIN;

  const path = resolve(REPO_ROOT, 'deployment-addresses', outputFilename);
  if (!existsSync(path)) throw new Error(`No deployment file at ${path}`);
  const dep = JSON.parse(readFileSync(path, 'utf8')) as OutputFile;

  const provider = new TronJsonRpcProvider(rpcUrl);
  const xerc20Abi = loadArtifact('XERC20').abi;
  const proxyAdminAbi = loadArtifact('ProxyAdmin').abi;

  const library = Object.values(dep.libraries ?? {})[0]?.evm;
  const impl = dep.leafXERC20Implementation;
  const proxy = dep.leafXERC20;

  console.log(`Verifying ${outputFilename} against ${rpcUrl}\n`);

  // 1. Code exists at every recorded address.
  console.log('Bytecode present:');
  const codes: Record<string, string> = {};
  for (const [label, addr] of [
    ['library', library],
    ['implementation', impl],
    ['proxy (xerc20)', proxy],
  ] as const) {
    if (!addr) {
      check(`${label} address recorded`, false, '(missing in file)');
      continue;
    }
    const code = await provider.getCode(addr);
    codes[label] = code;
    check(`${label} has code`, !!code && code !== '0x', addr);
  }

  // 2. Base58 <-> EVM address consistency in the file.
  console.log('\nAddress encoding (file self-consistency):');
  check(
    'xerc20 Tron address matches EVM',
    !!proxy && dep.leafXERC20Tron === evmToTronBase58(proxy),
    dep.leafXERC20Tron,
  );
  check(
    'implementation Tron address matches EVM',
    !!impl && dep.leafXERC20ImplementationTron === evmToTronBase58(impl),
    dep.leafXERC20ImplementationTron,
  );

  // 3. Library is linked into the implementation runtime bytecode.
  if (library && codes['implementation']) {
    const needle = library.replace(/^0x/, '').toLowerCase();
    check(
      'library is linked into implementation bytecode',
      codes['implementation'].toLowerCase().includes(needle),
    );
  }

  // 4. Proxy EIP-1967 wiring.
  console.log('\nProxy wiring (EIP-1967):');
  const implSlot = slotToAddress(
    await provider.getStorageAt(proxy!, EIP1967_IMPLEMENTATION_SLOT),
  );
  check(
    'proxy implementation slot -> recorded implementation',
    addrEq(implSlot, impl),
    implSlot,
  );
  const adminSlot = slotToAddress(
    await provider.getStorageAt(proxy!, EIP1967_ADMIN_SLOT),
  );
  check('proxy has a ProxyAdmin', adminSlot !== '0x' + '0'.repeat(40), adminSlot);

  // 5. Token configuration (read through the proxy).
  console.log('\nToken configuration:');
  const token = new Contract(proxy!, xerc20Abi, provider);
  const [name, symbol, decimals, owner, lockbox] = await Promise.all([
    token.name(),
    token.symbol(),
    token.decimals(),
    token.owner(),
    token.lockbox(),
  ]);
  check(`name == "${TOKEN_NAME}"`, name === TOKEN_NAME, name);
  check(`symbol == "${TOKEN_SYMBOL}"`, symbol === TOKEN_SYMBOL, symbol);
  check(`decimals == ${TOKEN_DECIMALS}`, Number(decimals) === TOKEN_DECIMALS, String(decimals));
  check(
    'lockbox == 0x0 (leaf token)',
    lockbox === '0x0000000000000000000000000000000000000000',
    lockbox,
  );
  check(
    `token owner == token admin`,
    addrEq(owner, expectedAdmin),
    `${owner} (${evmToTronBase58(owner)})`,
  );

  // 6. ProxyAdmin ownership.
  console.log('\nProxyAdmin ownership:');
  const proxyAdmin = new Contract(adminSlot, proxyAdminAbi, provider);
  const paOwner = await proxyAdmin.owner();
  check(
    'ProxyAdmin owner == token admin',
    addrEq(paOwner, expectedAdmin),
    `${paOwner} (${evmToTronBase58(paOwner)})`,
  );

  console.log('');
  if (failures === 0) {
    console.log('All checks passed ✅');
  } else {
    console.log(`${failures} check(s) failed ❌`);
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('Verification error:', err);
  process.exitCode = 1;
});
