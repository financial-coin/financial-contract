require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

// 0x394586580ff4170c8a0244837202cbabe9070f66 7bbfec284ee43e328438d46ec803863c8e1367ab46072f7864c07e0a03ba61fd
const PRV_KEY = process.env.PRV_KEY || '7bbfec284ee43e328438d46ec803863c8e1367ab46072f7864c07e0a03ba61fd';

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "localhost",
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
    mainnet: {
      url: `https://api.zan.top/eth-mainnet`,
      accounts: [PRV_KEY],
    },
    /**** test network ****/
    amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [PRV_KEY],
    },
  },

};
