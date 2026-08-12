import { expect } from 'chai';

import {
  createTronWallet,
  httpApiHost,
  isHostHonoredBySdk,
  parseCustomHeaders,
} from './wallet.mts';

// A valid secp256k1 private key (well-known Hardhat account #0). Used only to
// derive an address locally; no network I/O happens during these tests.
const PRIVATE_KEY =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

/** Reads the TronWeb HTTP-API host the wallet will broadcast through. */
function tronWebHost(wallet: unknown): string {
  return (wallet as any).tronWeb.fullNode.host;
}

describe('wallet URL handling (unit)', () => {
  describe('parseCustomHeaders', () => {
    it('extracts custom_rpc_header params', () => {
      expect(
        parseCustomHeaders(
          'https://api.trongrid.io/jsonrpc?custom_rpc_header=TRON-PRO-API-KEY:abc',
        ),
      ).to.deep.equal({ 'TRON-PRO-API-KEY': 'abc' });
    });

    it('returns empty when none present', () => {
      expect(parseCustomHeaders('https://host.example.com/jsonrpc')).to.deep.equal(
        {},
      );
    });
  });

  describe('httpApiHost', () => {
    it('strips a trailing /jsonrpc path', () => {
      expect(httpApiHost('https://node.example.com:8090/jsonrpc')).to.equal(
        'https://node.example.com:8090/',
      );
    });

    it('strips custom_rpc_header params', () => {
      expect(
        httpApiHost('https://node.example.com/jsonrpc?custom_rpc_header=k:v'),
      ).to.equal('https://node.example.com/');
    });
  });

  describe('isHostHonoredBySdk', () => {
    it('honors localhost / 127.0.0.1 / trongrid', () => {
      expect(isHostHonoredBySdk('http://127.0.0.1:9090/')).to.equal(true);
      expect(isHostHonoredBySdk('http://localhost:9090/')).to.equal(true);
      expect(isHostHonoredBySdk('https://api.trongrid.io/')).to.equal(true);
    });

    it('does not honor arbitrary private hosts', () => {
      expect(isHostHonoredBySdk('https://my-tron-node.example.com/')).to.equal(
        false,
      );
    });
  });

  describe('createTronWallet', () => {
    it('repoints the TronWeb client at a private RPC host', () => {
      const url = 'https://my-tron-node.example.com:8090/jsonrpc';
      const wallet = createTronWallet(PRIVATE_KEY, url);
      const host = tronWebHost(wallet);
      expect(host).to.contain('my-tron-node.example.com');
      expect(host).to.not.contain('trongrid');
    });

    it('preserves a private host when custom headers are present', () => {
      const url =
        'https://my-tron-node.example.com/jsonrpc?custom_rpc_header=x-api-key:secret';
      const wallet = createTronWallet(PRIVATE_KEY, url);
      expect(tronWebHost(wallet)).to.contain('my-tron-node.example.com');
      expect(tronWebHost(wallet)).to.not.contain('trongrid');
    });

    it('leaves TronGrid hosts untouched', () => {
      const wallet = createTronWallet(
        PRIVATE_KEY,
        'https://api.trongrid.io/jsonrpc',
      );
      expect(tronWebHost(wallet)).to.contain('trongrid');
    });

    it('leaves localhost untouched', () => {
      const wallet = createTronWallet(PRIVATE_KEY, 'http://127.0.0.1:9090/jsonrpc');
      expect(tronWebHost(wallet)).to.contain('127.0.0.1');
    });
  });
});
