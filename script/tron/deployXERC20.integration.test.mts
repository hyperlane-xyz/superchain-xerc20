import { expect } from 'chai';
import { BigNumber, Contract, constants, utils } from 'ethers';
import { TronWeb } from 'tronweb';

import { TronJsonRpcProvider, type TronWallet } from '@hyperlane-xyz/tron-sdk';
import {
  runTronNode,
  stopTronNode,
  type TronNodeInfo,
  type TronTestChainMetadata,
} from '@hyperlane-xyz/tron-sdk/testing';

import { loadArtifact } from './artifacts.mts';
import { createTronWallet } from './wallet.mts';
import {
  deployLeafXERC20,
  deployXERC20Implementation,
  readImplementation,
  readProxyAdmin,
  TOKEN_DECIMALS,
  TOKEN_NAME,
  TOKEN_SYMBOL,
  type LeafDeployment,
  type ResumeState,
} from './deployXERC20.mts';

const TEST_CHAIN: TronTestChainMetadata = {
  name: 'tron-xerc20-test',
  chainId: 3360022319,
  domainId: 3360022319,
  port: 19191,
};

const ONE_TOKEN = BigNumber.from(10).pow(TOKEN_DECIMALS); // 1 oUSDT (6 decimals)
const XERC20_ABI = loadArtifact('XERC20').abi;
const PROXY_ADMIN_ABI = loadArtifact('ProxyAdmin').abi;

/** A bridge rate-limit config valid for `addBridge`. */
function bridgeConfig(bridge: string) {
  return {
    bufferCap: BigNumber.from(1_000_000).mul(ONE_TOKEN), // 1,000,000 oUSDT
    rateLimitPerSecond: BigNumber.from(10).mul(ONE_TOKEN),
    bridge,
  };
}

/** Asserts that an on-chain action reverts (either at simulation or on-chain). */
async function expectRevert(
  action: () => Promise<any>,
  label: string,
): Promise<void> {
  try {
    const tx = await action();
    if (tx && typeof tx.wait === 'function') {
      const receipt = await tx.wait();
      if (receipt && receipt.status === 0) return;
    }
  } catch {
    return;
  }
  throw new Error(`Expected revert but call succeeded: ${label}`);
}

describe('Tron oUSDT XERC20 leaf deployment', function () {
  this.timeout(600_000); // container pull + startup + deploys

  let node: TronNodeInfo;
  let wallet: TronWallet; // deployer / initial admin
  let other: TronWallet; // a second funded account
  let tokenAdmin: string;

  before(async () => {
    node = await runTronNode(TEST_CHAIN);
    const tronUrl = `http://127.0.0.1:${TEST_CHAIN.port}/jsonrpc`;
    wallet = createTronWallet(node.privateKeys[0], tronUrl);
    other = createTronWallet(node.privateKeys[1], tronUrl);
    tokenAdmin = wallet.address;
  });

  after(async () => {
    for (const w of [wallet, other]) {
      if (w?.provider instanceof TronJsonRpcProvider) {
        w.provider.removeAllListeners();
      }
    }
    if (node) await stopTronNode(node);
  });

  describe('deployment & normal usage', () => {
    let deployment: LeafDeployment;
    let token: Contract;

    before(async () => {
      deployment = await deployLeafXERC20(wallet, tokenAdmin, {
        // eslint-disable-next-line no-console
        log: (m) => console.log(`  ${m}`),
      });
      token = new Contract(deployment.xerc20, XERC20_ABI, wallet);
    });

    it('returns valid, distinct EVM and Tron addresses', () => {
      expect(deployment.implementation).to.match(/^0x[0-9a-fA-F]{40}$/);
      expect(deployment.xerc20).to.match(/^0x[0-9a-fA-F]{40}$/);
      expect(deployment.implementation).to.not.equal(deployment.xerc20);
      expect(deployment.implementation).to.not.equal(constants.AddressZero);
      expect(deployment.xerc20).to.not.equal(constants.AddressZero);
      expect(deployment.xerc20Tron).to.match(/^T[1-9A-HJ-NP-Za-km-z]{33}$/);
      expect(deployment.implementationTron).to.match(
        /^T[1-9A-HJ-NP-Za-km-z]{33}$/,
      );
    });

    it('initializes token metadata (name, symbol, decimals)', async () => {
      expect(await token.name()).to.equal(TOKEN_NAME);
      expect(await token.symbol()).to.equal(TOKEN_SYMBOL);
      expect(await token.decimals()).to.equal(TOKEN_DECIMALS);
    });

    it('sets the owner to the token admin', async () => {
      expect((await token.owner()).toLowerCase()).to.equal(
        tokenAdmin.toLowerCase(),
      );
    });

    it('is a leaf token: no lockbox and zero initial supply', async () => {
      expect(await token.lockbox()).to.equal(constants.AddressZero);
      expect((await token.totalSupply()).toString()).to.equal('0');
    });

    it('lets a bridge mint, transfer, and burn tokens', async () => {
      // Register the deployer as a bridge with a mint/burn limit.
      await (await token.addBridge(bridgeConfig(wallet.address))).wait();
      expect(
        (await token.mintingMaxLimitOf(wallet.address)).toString(),
      ).to.equal(bridgeConfig(wallet.address).bufferCap.toString());

      // Mint 1,000 oUSDT to the deployer.
      const minted = BigNumber.from(1_000).mul(ONE_TOKEN);
      await (await token.mint(wallet.address, minted)).wait();
      expect((await token.balanceOf(wallet.address)).toString()).to.equal(
        minted.toString(),
      );
      expect((await token.totalSupply()).toString()).to.equal(
        minted.toString(),
      );

      // Transfer 400 oUSDT to another address.
      const sent = BigNumber.from(400).mul(ONE_TOKEN);
      await (await token.transfer(other.address, sent)).wait();
      expect((await token.balanceOf(other.address)).toString()).to.equal(
        sent.toString(),
      );
      expect((await token.balanceOf(wallet.address)).toString()).to.equal(
        minted.sub(sent).toString(),
      );

      // The recipient approves the bridge, which burns their balance.
      const tokenAsOther = new Contract(deployment.xerc20, XERC20_ABI, other);
      await (await tokenAsOther.approve(wallet.address, sent)).wait();
      await (await token.burn(other.address, sent)).wait();
      // The bridge burns its own remaining balance.
      await (await token.burn(wallet.address, minted.sub(sent))).wait();

      expect((await token.balanceOf(wallet.address)).toString()).to.equal('0');
      expect((await token.balanceOf(other.address)).toString()).to.equal('0');
      expect((await token.totalSupply()).toString()).to.equal('0');
    });

    it('lets the owner manage bridges (add, reconfigure, remove)', async () => {
      const bridge = other.address;
      await (await token.addBridge(bridgeConfig(bridge))).wait();
      expect((await token.mintingMaxLimitOf(bridge)).toString()).to.not.equal(
        '0',
      );

      const newCap = BigNumber.from(2_000_000).mul(ONE_TOKEN);
      await (await token.setBufferCap(bridge, newCap)).wait();
      expect((await token.mintingMaxLimitOf(bridge)).toString()).to.equal(
        newCap.toString(),
      );

      await (await token.removeBridge(bridge)).wait();
      expect((await token.mintingMaxLimitOf(bridge)).toString()).to.equal('0');
    });

    it('rejects bridge management from a non-owner', async () => {
      const tokenAsOther = new Contract(deployment.xerc20, XERC20_ABI, other);
      await expectRevert(
        () => tokenAsOther.addBridge(bridgeConfig(other.address)),
        'addBridge by non-owner',
      );
    });

    it('routes non-admin reads through the implementation (proxy works)', async () => {
      const reader = new Contract(deployment.xerc20, XERC20_ABI, wallet.provider);
      expect(await reader.symbol()).to.equal(TOKEN_SYMBOL);
      expect(utils.isAddress(await reader.owner())).to.equal(true);
    });
  });

  describe('governance', () => {
    let gov: LeafDeployment;
    let token: Contract;
    let proxyAdmin: Contract;

    before(async () => {
      // Fresh deployment so destructive ownership changes don't affect other tests.
      gov = await deployLeafXERC20(wallet, wallet.address);
      token = new Contract(gov.xerc20, XERC20_ABI, wallet);
      const proxyAdminAddress = await readProxyAdmin(wallet, gov.xerc20);
      proxyAdmin = new Contract(proxyAdminAddress, PROXY_ADMIN_ABI, wallet);
    });

    it('transfers ownership of the XERC20 token', async () => {
      expect((await token.owner()).toLowerCase()).to.equal(
        wallet.address.toLowerCase(),
      );

      await (await token.transferOwnership(other.address)).wait();
      expect((await token.owner()).toLowerCase()).to.equal(
        other.address.toLowerCase(),
      );

      // The previous owner can no longer perform owner-only actions.
      await expectRevert(
        () => token.addBridge(bridgeConfig(wallet.address)),
        'addBridge by former owner',
      );

      // The new owner can.
      const tokenAsOther = new Contract(gov.xerc20, XERC20_ABI, other);
      await (await tokenAsOther.addBridge(bridgeConfig(wallet.address))).wait();
      expect(
        (await token.mintingMaxLimitOf(wallet.address)).toString(),
      ).to.not.equal('0');
    });

    it('upgrades the proxy to a new implementation via ProxyAdmin', async () => {
      // The ProxyAdmin is owned by the deployer.
      expect((await proxyAdmin.owner()).toLowerCase()).to.equal(
        wallet.address.toLowerCase(),
      );
      expect((await readImplementation(wallet, gov.xerc20)).toLowerCase()).to.equal(
        gov.implementation.toLowerCase(),
      );

      // Deploy a new implementation and upgrade to it.
      const { implementation: newImpl } =
        await deployXERC20Implementation(wallet);
      expect(newImpl.toLowerCase()).to.not.equal(gov.implementation.toLowerCase());

      await (await proxyAdmin.upgradeAndCall(gov.xerc20, newImpl, '0x')).wait();

      expect((await readImplementation(wallet, gov.xerc20)).toLowerCase()).to.equal(
        newImpl.toLowerCase(),
      );
      // Storage (and therefore token state) is preserved across the upgrade.
      expect(await token.name()).to.equal(TOKEN_NAME);
      expect(await token.symbol()).to.equal(TOKEN_SYMBOL);
    });

    it('transfers ownership of the proxy (ProxyAdmin)', async () => {
      await (await proxyAdmin.transferOwnership(other.address)).wait();
      expect((await proxyAdmin.owner()).toLowerCase()).to.equal(
        other.address.toLowerCase(),
      );

      // The former ProxyAdmin owner can no longer upgrade.
      await expectRevert(
        () => proxyAdmin.upgradeAndCall(gov.xerc20, gov.implementation, '0x'),
        'upgrade by former proxy admin owner',
      );
    });
  });

  describe('deployment cost', () => {
    // Current TRON mainnet energy unit price (SUN per energy). Adjust to the
    // live value from `wallet/getenergyprices` when estimating real cost.
    const MAINNET_ENERGY_PRICE_SUN = 420;

    async function getTxInfo(tronWeb: TronWeb, txHash: string): Promise<any> {
      const id = txHash.replace(/^0x/, '');
      for (let i = 0; i < 30; i++) {
        const info = await tronWeb.trx.getTransactionInfo(id);
        if (info && Object.keys(info).length > 0) return info;
        await new Promise((r) => setTimeout(r, 500));
      }
      throw new Error(`No transaction info for ${txHash}`);
    }

    it('measures the TRX required for a full deployment', async () => {
      const tronWeb = new TronWeb({
        fullHost: `http://127.0.0.1:${TEST_CHAIN.port}`,
      });

      // Measure the deployer balance delta across a full, fresh deployment.
      const before = await wallet.provider.getBalance(wallet.address);
      const dep = await deployLeafXERC20(wallet, wallet.address);
      const after = await wallet.provider.getBalance(wallet.address);

      // A full leaf deployment is exactly 3 contract creations.
      expect(dep.transactionHashes.length).to.equal(3);

      // Per-transaction energy + fee breakdown from the Tron HTTP API.
      let totalEnergy = 0;
      let totalFeeSun = 0;
      const labels = ['library', 'implementation', 'proxy'];
      for (let i = 0; i < dep.transactionHashes.length; i++) {
        const info = await getTxInfo(tronWeb, dep.transactionHashes[i]);
        const energy = info?.receipt?.energy_usage_total ?? 0;
        const fee = info?.fee ?? 0;
        totalEnergy += energy;
        totalFeeSun += fee;
        // eslint-disable-next-line no-console
        console.log(
          `  ${labels[i].padEnd(14)} energy=${energy} fee=${fee} SUN`,
        );
      }

      const estMainnetTrx =
        (totalEnergy * MAINNET_ENERGY_PRICE_SUN) / 1_000_000;
      const balanceDeltaTrx = Number(utils.formatUnits(before.sub(after), 6));

      // eslint-disable-next-line no-console
      console.log(
        `\nFull deployment cost (${dep.transactionHashes.length} contract creations):\n` +
          `  total energy:            ${totalEnergy}\n` +
          `  balance delta on TRE:    ${balanceDeltaTrx} TRX\n` +
          `  est. mainnet energy cost: ${estMainnetTrx.toFixed(2)} TRX ` +
          `(@ ${MAINNET_ENERGY_PRICE_SUN} SUN/energy)`,
      );

      // Every contract creation consumes energy.
      expect(totalEnergy).to.be.greaterThan(0);
      // The SDK fee-limits each creation to 1000 TRX, so 3 creations stay well
      // under 3000 TRX both in real fees and in the mainnet energy estimate.
      expect(estMainnetTrx).to.be.lessThan(3000);
      expect(totalFeeSun / 1_000_000).to.be.lessThan(3000);
    });
  });

  describe('resumability & idempotency', () => {
    let first: LeafDeployment;

    before(async () => {
      first = await deployLeafXERC20(wallet, wallet.address);
    });

    it('reuses all contracts when resumed from a complete state (no-op)', async () => {
      const resume: ResumeState = {
        implementation: first.implementation,
        xerc20: first.xerc20,
        libraries: first.libraries,
      };
      const again = await deployLeafXERC20(wallet, wallet.address, { resume });

      // Nothing was redeployed and the addresses are unchanged.
      expect(again.transactionHashes).to.have.length(0);
      expect(again.xerc20).to.equal(first.xerc20);
      expect(again.implementation).to.equal(first.implementation);
      expect(again.libraries).to.deep.equal(first.libraries);
    });

    it('resumes a partial deployment, reusing libraries and deploying the rest', async () => {
      // Simulate a run that got as far as deploying the libraries only.
      const resume: ResumeState = { libraries: first.libraries };
      const resumed = await deployLeafXERC20(wallet, wallet.address, { resume });

      // Libraries reused (same addresses); impl + proxy freshly deployed.
      expect(resumed.libraries).to.deep.equal(first.libraries);
      expect(resumed.transactionHashes).to.have.length(2);
      expect(resumed.implementation).to.not.equal(first.implementation);
      expect(resumed.xerc20).to.not.equal(first.xerc20);
    });

    it('ignores stale resume addresses with no code on-chain', async () => {
      // A recorded address that was never actually deployed must be redeployed.
      const resume: ResumeState = {
        libraries: first.libraries,
        implementation: '0x000000000000000000000000000000000000dEaD',
        xerc20: '0x000000000000000000000000000000000000bEEF',
      };
      const redeployed = await deployLeafXERC20(wallet, wallet.address, {
        resume,
      });

      expect(redeployed.transactionHashes).to.have.length(2);
      expect(redeployed.implementation).to.not.equal(resume.implementation);
      expect(redeployed.xerc20).to.not.equal(resume.xerc20);
      // The freshly deployed token is valid.
      const token = new Contract(redeployed.xerc20, XERC20_ABI, wallet);
      expect(await token.symbol()).to.equal(TOKEN_SYMBOL);
    });
  });
});
