const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');
const { ethers, network: { config } } = require('hardhat');
const { expect } = require('chai');

describe('Entry', function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployFixture() {
    // Contracts are deployed using the first signer/account by default
    const [owner, account1] = await ethers.getSigners();

    const Entry = await ethers.getContractFactory('Entry');
    const impl = await Entry.deploy();
    const ERC1967Proxy = await ethers.getContractFactory('ERC1967Proxy');
    const erc1967Proxy = await ERC1967Proxy.deploy(impl, impl.interface.encodeFunctionData('initialize', [owner.address]));
    const entry = await ethers.getContractAt('Entry', erc1967Proxy);

    const TestToken = await ethers.getContractFactory('TestToken');
    const token = await TestToken.deploy();

    await token.mint(owner, 10000);
    await token.approve(entry, 10000);
    await owner.sendTransaction({ to: entry, value: 10000 });

    return { owner, account1, entry, token };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { owner, entry } = await loadFixture(deployFixture);

      expect(await entry.owner()).to.equal(owner.address);
    });
  });

  describe('SwapETH', function () {
    const amountIn = 1000;
    const amountOut = 1000;
    const nonce = 0;
    // eslint-disable-next-line
    const deadline = Math.floor(new Date().getTime() / 1000) + 3600;

    describe('Validations', function () {
      it('Should revert if caller is not admin', async function () {
        const { owner, account1, entry, token } = await loadFixture(deployFixture);

        await expect(entry.connect(account1).swapETH(owner, token, amountIn, amountOut, deadline, '0x')).to.be.reverted;
      });

      it('Should revert with no signature', async function () {
        const { owner, entry, token } = await loadFixture(deployFixture);

        await expect(entry.swapETH(owner, token, amountIn, amountOut, deadline, '0x')).to.be.reverted;
      });

      it('Should not fail with no signature', async function () {
        const { owner, entry, token } = await loadFixture(deployFixture);

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
        const value = {
          owner: owner.address,
          token: token.target,
          amountIn,
          amountOut,
          nonce,
          deadline,
        };
        const signature = await owner.signTypedData(domain, types, value);

        await expect(entry.swapETH(owner, token, amountIn, amountOut, deadline, signature)).not.to.be.reverted;
      });
    });

    describe('Events', function () {
      it('Should emit a event', async function () {
        const { owner, entry, token } = await loadFixture(deployFixture);

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
        const value = {
          owner: owner.address,
          token: token.target,
          amountIn,
          amountOut,
          nonce,
          deadline,
        };
        const signature = await owner.signTypedData(domain, types, value);

        await expect(entry.swapETH(owner, token, amountIn, amountOut, deadline, signature))
          .to.emit(entry, 'SwapETH')
          .withArgs(owner, token, amountIn, amountOut);
      });
    });
  });
});
