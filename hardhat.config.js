require("@nomicfoundation/hardhat-toolbox");
const networks = require("./networks");

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
  networks,
};
