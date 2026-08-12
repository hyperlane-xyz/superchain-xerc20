import { TronWallet, TronTransactionBuilder } from '@hyperlane-xyz/tron-sdk';
import { TronWeb } from 'tronweb';

/**
 * Parses `custom_rpc_header=Key:Value` query params into a headers object,
 * mirroring tron-sdk's internal `parseCustomHeaders` (which is not exported).
 */
export function parseCustomHeaders(url: string): Record<string, string> {
  const headers: Record<string, string> = {};
  try {
    const parsed = new URL(url);
    for (const [key, value] of parsed.searchParams) {
      if (key !== 'custom_rpc_header') continue;
      const i = value.indexOf(':');
      if (i > 0) headers[value.slice(0, i)] = value.slice(i + 1);
    }
  } catch {
    // not a URL; no headers
  }
  return headers;
}

/**
 * Derives the Tron HTTP-API base host from an RPC URL: drops any
 * `custom_rpc_header` params and a trailing `/jsonrpc` path.
 */
export function httpApiHost(url: string): string {
  const parsed = new URL(url);
  parsed.searchParams.delete('custom_rpc_header');
  if (parsed.pathname.endsWith('/jsonrpc')) {
    parsed.pathname = parsed.pathname.slice(0, -'/jsonrpc'.length);
  }
  return parsed.toString();
}

/** Whether tron-sdk keeps a host for TronWeb instead of forcing public TronGrid. */
export function isHostHonoredBySdk(host: string): boolean {
  return /^https?:\/\/(localhost|127\.0\.0\.1|[^/]*trongrid)/.test(host);
}

/**
 * Creates a `TronWallet` whose TronWeb client — used to build, sign and
 * **broadcast** transactions — is guaranteed to target the provided RPC URL.
 *
 * Works around a limitation in `@hyperlane-xyz/tron-sdk@23`: its `TronWallet`
 * forces the TronWeb client to the public `https://api.trongrid.io` for any
 * host that is not `localhost`/`127.0.0.1` or contains `trongrid`. That
 * silently ignores a private RPC for broadcasting and gets rate-limited (429).
 *
 * The ethers JSON-RPC provider already uses the supplied URL; here we repoint
 * the TronWeb HTTP-API client (and the transaction builder) at the same host.
 *
 * API keys are still supported via the `?custom_rpc_header=Key:Value` syntax.
 */
export function createTronWallet(
  privateKey: string,
  rpcUrl: string,
): TronWallet {
  const wallet = new TronWallet(privateKey, rpcUrl);

  const host = httpApiHost(rpcUrl);
  // If the SDK already honors this host, its TronWeb client is correct.
  if (isHostHonoredBySdk(host)) return wallet;

  const internals = wallet as unknown as {
    tronWeb?: TronWeb;
    txBuilder?: unknown;
    tronAddress?: string;
  };
  if (!internals.tronWeb || !internals.txBuilder || !internals.tronAddress) {
    throw new Error(
      'Cannot redirect TronWeb to the provided RPC: unexpected ' +
        '@hyperlane-xyz/tron-sdk internals (expected v23). Pin the SDK to ^23, ' +
        'or use a TronGrid URL with an API key, e.g. ' +
        'https://api.trongrid.io/jsonrpc?custom_rpc_header=TRON-PRO-API-KEY:<key>',
    );
  }

  const headers = parseCustomHeaders(rpcUrl);
  const cleanKey = privateKey.replace(/^0x/, '');

  const tronWeb = new TronWeb({ fullHost: host, headers });
  tronWeb.setPrivateKey(cleanKey);
  tronWeb.setAddress(internals.tronAddress);

  internals.tronWeb = tronWeb;
  internals.txBuilder = new TronTransactionBuilder(
    host,
    internals.tronAddress,
    rpcUrl,
    headers,
  );

  return wallet;
}
