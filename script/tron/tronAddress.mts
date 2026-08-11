import { TronWeb } from 'tronweb';

// Offline TronWeb instance used purely for address-format conversion.
// No network requests are made by `address.fromHex`.
const formatter = new TronWeb({ fullHost: 'https://api.trongrid.io' });

/**
 * Converts a 0x-prefixed EVM address to its Tron base58 (`T...`) representation.
 *
 * Tron stores the same 20-byte address with a `0x41` version prefix and
 * base58check-encodes it for display.
 */
export function evmToTronBase58(evmAddress: string): string {
  const hex = '41' + evmAddress.replace(/^0x/, '').toLowerCase();
  return formatter.address.fromHex(hex);
}
