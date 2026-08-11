import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { utils } from 'ethers';

const here = dirname(fileURLToPath(import.meta.url));

/** Repository root (script/tron -> repo root is two levels up). */
export const REPO_ROOT = resolve(here, '..', '..');

/**
 * Solidity link references: file -> contract -> positions, exactly as emitted
 * by Foundry in `bytecode.linkReferences`.
 */
export type LinkReferences = Record<
  string,
  Record<string, Array<{ start: number; length: number }>>
>;

/** Minimal shape of a Foundry (`forge build`) JSON artifact. */
export interface ForgeArtifact {
  abi: any[];
  /** Creation bytecode, 0x-prefixed. May contain unlinked library placeholders. */
  bytecode: string;
  /** Unresolved external library references, if any. */
  linkReferences: LinkReferences;
}

/**
 * Loads a Foundry artifact from `out/<file>.sol/<contract>.json`.
 *
 * @param contract The contract name (e.g. `XERC20`).
 * @param file The `.sol` file name without extension. Defaults to `contract`.
 */
export function loadArtifact(contract: string, file = contract): ForgeArtifact {
  const path = resolve(REPO_ROOT, 'out', `${file}.sol`, `${contract}.json`);
  let raw: string;
  try {
    raw = readFileSync(path, 'utf8');
  } catch {
    throw new Error(
      `Artifact not found at ${path}. Run \`forge build\` from the repo root first.`,
    );
  }
  const json = JSON.parse(raw);
  const bytecode: string | undefined = json?.bytecode?.object;
  if (!bytecode || bytecode === '0x') {
    throw new Error(`Artifact ${path} has no creation bytecode`);
  }
  return {
    abi: json.abi,
    bytecode,
    linkReferences: json?.bytecode?.linkReferences ?? {},
  };
}

/**
 * Fully-qualified library names (`path/File.sol:LibName`) referenced by an
 * artifact's bytecode.
 */
export function libraryNames(art: ForgeArtifact): string[] {
  const names: string[] = [];
  for (const [file, contracts] of Object.entries(art.linkReferences)) {
    for (const name of Object.keys(contracts)) {
      names.push(`${file}:${name}`);
    }
  }
  return names;
}

/** Loads the artifact for a fully-qualified library name. */
export function loadLibraryArtifact(fqName: string): ForgeArtifact {
  const [solPath, name] = fqName.split(':');
  const file = solPath.split('/').pop()!.replace(/\.sol$/, '');
  return loadArtifact(name, file);
}

/** The solc placeholder (`__$<hash>$__`) for a fully-qualified library name. */
export function libraryPlaceholder(fqName: string): string {
  const hash = utils.keccak256(utils.toUtf8Bytes(fqName)).slice(2, 2 + 34);
  return `__$${hash}$__`;
}

/**
 * Links external libraries into creation bytecode by substituting each
 * `__$<hash>$__` placeholder with the deployed library address.
 *
 * @param bytecode 0x-prefixed creation bytecode containing placeholders.
 * @param libraries Map of fully-qualified library name -> deployed address.
 */
export function linkBytecode(
  bytecode: string,
  libraries: Record<string, string>,
): string {
  let linked = bytecode;
  for (const [fqName, address] of Object.entries(libraries)) {
    const placeholder = libraryPlaceholder(fqName);
    const hex = address.replace(/^0x/, '').toLowerCase();
    if (hex.length !== 40) {
      throw new Error(`Invalid library address for ${fqName}: ${address}`);
    }
    if (!linked.includes(placeholder)) {
      throw new Error(`Placeholder ${placeholder} for ${fqName} not found`);
    }
    linked = linked.split(placeholder).join(hex);
  }
  const remaining = linked.match(/__\$[0-9a-fA-F]{34}\$__/);
  if (remaining) {
    throw new Error(`Unlinked library placeholder remains: ${remaining[0]}`);
  }
  return linked;
}
