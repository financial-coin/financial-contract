const { loadFixture, time } = require('@nomicfoundation/hardhat-toolbox/network-helpers');
const { ethers, ignition } = require('hardhat');
const { expect } = require('chai');
const V1 = require("../ignition/modules/V1");

describe('Fund', function () {
  async function deployFundFixture() {
    const [owner, account1] = await ethers.getSigners();

    const { entry, fund } = await ignition.deploy(V1);

    const amount = 1000000;
    const property = await fund.getProperty();
    const token = await ethers.getContractAt("TestToken", property.token);

    return { owner, account1, entry, fund, token, amount };
  }

  describe('Deployment', function () {
    it('Should set the fund property', async function () {
      const { entry, fund, token } = await loadFixture(deployFundFixture);

      const property = await fund.getProperty();
      expect(property.entry).to.equal(entry);
      expect(property.token).to.equal(token.target);
      expect(property.value).to.equal(0);
      expect(property.shares).to.equal(0);
      expect(property.provider).to.equal(token.target);
      expect(property.maxAPR).to.equal(1400);
    });

    it('Should set the fund account', async function () {
      const { owner, fund } = await loadFixture(deployFundFixture);

      const [shares, value, cost] = await fund.getAccount(owner.address);
      expect(shares).to.equal(0);
      expect(value).to.equal(0);
      expect(cost).to.equal(0);
    });

    it('Should set the max apr', async function () {
      const { fund } = await loadFixture(deployFundFixture);

      expect(await fund.getMaxAPR()).to.equal(1400);
    });

    it('Should not reinitializer', async function () {
      const { fund } = await loadFixture(deployFundFixture);

      await expect(fund.initialize()).to.be.reverted;
    });
  });

  describe('BuyFund', function () {
    describe('Validations', function () {
      it('Should revert if token invalid', async function () {
        const { account1, entry, fund } = await loadFixture(deployFundFixture);
        await expect(entry.buyFund(fund, account1, ethers.ZeroAddress, 0)).to.be.reverted;
      });

      it('Should not revert with the amount of token is zero', async function () {
        const { account1, entry, fund, token } = await loadFixture(deployFundFixture);
        await expect(entry.buyFund(fund.target, account1, token.target, 0)).not.to.be.reverted;
      });

      it('Should revert with no enough token', async function () {
        const { account1, entry, fund, token } = await loadFixture(deployFundFixture);

        await expect(entry.buyFund(fund.target, account1, token.target, 1)).to.be.reverted;
      });

      it('Buy fund, check fund shares, ', async function () {
        const { owner, account1, entry, fund, token, amount } = await loadFixture(deployFundFixture);

        await token.mint(account1, amount);
        await token.connect(account1).approve(entry, amount);

        await expect(entry.connect(account1).buyFund(fund.target, account1, token.target, amount)).not.to.be.reverted;

        let property = await fund.getProperty();
        expect(property.value).to.equal(amount);
        expect(property.shares).to.equal(amount);

        let [shares, value, cost] = await fund.getAccount(account1.address);
        expect(shares).to.equal(amount);
        expect(value).to.equal(amount);
        expect(cost).to.equal(amount);

        const newValue = amount + 500;
        await time.increase(24 * 3600);
        await token.mint(fund, newValue - amount);
        await fund.updateValue("0x");

        property = await fund.getProperty();
        expect(property.value).to.equal(newValue);

        [shares, value] = await fund.getAccount(account1.address);
        expect(shares).to.equal(amount);
        // (1000000*1400*24*3600) / (10000*365*24*3600) = 383.56
        const maxAddValue = Math.floor((100 * 1400) / 365);
        expect(value).to.equal(amount + maxAddValue);

        await entry.connect(account1).redeemFund(fund.target, account1, amount);

        [shares, value, cost] = await fund.getAccount(account1.address);
        expect(shares).to.equal(0);
        expect(value).to.equal(0);
        expect(cost).to.equal(0);

        await entry.redeemFund(fund.target, owner, 116);
        property = await fund.getProperty();
        expect(property.value).to.equal(0);
        expect(property.shares).to.equal(0);
      });
    });

    describe('Events', function () {
      it('Should emit a event', async function () {
        const { account1, entry, fund, token } = await loadFixture(deployFundFixture);

        await expect(entry.buyFund(fund.target, account1, token.target, 0))
          .to.emit(fund, 'Mint')
          .withArgs(account1, 0, 0);
      });
    });
  });
});
