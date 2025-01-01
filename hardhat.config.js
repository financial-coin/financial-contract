require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
const PRV_KEY = process.env.PRV_KEY || 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const NETWORK = process.env.NETWORK || 'localhost'

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: NETWORK,
  ignition: {
    requiredConfirmations: 1,
  },
  solidity: {
    compilers: [
      {
        version: '0.8.28',
        settings: {
          optimizer: {
            enabled: true,
            runs: 20000,
          },
        },
      },
    ],
  },
  /**** chain rpc: https://chainlist.org ****/
  networks: {
    /**** release network ****/
    mainnet: {
      chainId: 1,
      url: `https://api.zan.top/eth-mainnet`,
      accounts: [PRV_KEY],
    },

    /**** test network ****/
    localhost: {
      chainId: 31337,
      url: "http://127.0.0.1:8545",
    },
    amoy: {
      chainId: 80002,
      url: "https://rpc-amoy.polygon.technology",
      accounts: [PRV_KEY],
    },
  },

};
