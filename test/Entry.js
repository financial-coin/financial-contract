const { loadFixture, time } = require('@nomicfoundation/hardhat-toolbox/network-helpers');
const { ethers, ignition, network: { config } } = require('hardhat');
const { expect } = require('chai');
const V1 = require("../ignition/modules/V1");

describe('Entry', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployEntryFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, account1] = await ethers.getSigners();

    const { entry, fund } = await ignition.deploy(V1);

    return { owner, account1, entry, fund };
  }

  async function deployTokenFixture() {
    const { owner, account1, entry, fund } = await loadFixture(deployEntryFixture);

    const amount = 10000;
    const property = await fund.getProperty();
    const token = await ethers.getContractAt("TestToken", property.token);
    await token.mint(account1, amount);
    await token.connect(account1).approve(entry, amount);
    await owner.sendTransaction({ to: entry, value: amount });

    const domain = { name: 'entry', version: '1', chainId: config.chainId, verifyingContract: entry.target };
    const types = {
      SwapETH: [
        { name: 'owner', type: 'address' },
        { name: 'token', type: 'address' },
        { name: 'amountIn', type: 'uint256' },
        { name: 'amountOut', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'deadline', type: 'uint256' },
      ],
    };
    const deadline = await time.latest() + 3600;

    const value = {
      owner: account1.address,
      token: token.target,
      amountIn: amount,
      amountOut: amount,
      nonce: 0,
      deadline,
    };
    const signature = await account1.signTypedData(domain, types, value);

    return { owner, account1, entry, token, amount, deadline, signature };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { owner, entry } = await loadFixture(deployEntryFixture);

      expect(await entry.owner()).to.equal(owner.address);
    });

    it('Should set the fund', async function () {
      const { entry, fund } = await loadFixture(deployEntryFixture);

      expect(await entry.fundsLength()).to.equal(1);
      expect(await entry.funds(0)).to.equal(fund.target);
    });

    it('Should set the fund property', async function () {
      const { entry, fund } = await loadFixture(deployEntryFixture);

      const property = await entry.getFundProperty(fund);
      expect(property.entry).to.equal(entry);
      expect(property.value).to.equal(0);
      expect(property.shares).to.equal(0);
      expect(property.maxAPR).to.equal(1400);
    });

    it('Should set the fund account', async function () {
      const { owner, entry, fund } = await loadFixture(deployEntryFixture);

      const [shares, value, cost] = await entry.getFundAccount(fund.target, owner.address);
      expect(shares).to.equal(0);
      expect(value).to.equal(0);
      expect(cost).to.equal(0);
    });

    it('Should set the owner nonce', async function () {
      const { owner, entry } = await loadFixture(deployEntryFixture);

      expect(await entry.nonces(owner)).to.equal(0);
    });
  });

  describe('SwapETH', function () {
    describe('Validations', function () {
      it('Should revert if caller is not admin', async function () {
        const { account1, entry } = await loadFixture(deployEntryFixture);
        await expect(entry.connect(account1).swapETH(account1, ethers.ZeroAddress, 1, 1, 10000000000, '0x')).to.be.reverted;
      });

      it('Should revert with no signature', async function () {
        const { account1, entry } = await loadFixture(deployEntryFixture);
        await expect(entry.swapETH(account1, ethers.ZeroAddress, 1, 1, 10000000000, '0x')).to.be.reverted;
      });

      it('Should not fail with signature', async function () {
        const { account1, entry, token, amount, deadline, signature } = await loadFixture(deployTokenFixture);

        await expect(entry.swapETH(account1, token, amount, amount, deadline, signature)).not.to.be.reverted;
      });
    });

    describe('Events', function () {
      it('Should emit a event', async function () {
        const { account1, entry, token, amount, deadline, signature } = await loadFixture(deployTokenFixture);

        await expect(entry.swapETH(account1, token, amount, amount, deadline, signature))
          .to.emit(entry, 'SwapETH')
          .withArgs(account1, token, amount, amount);
      });
    });
  });
});
