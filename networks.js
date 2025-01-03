require('dotenv').config();

// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
const PRV_KEY = process.env.PRV_KEY || 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';

/**** chain rpc: https://chainlist.org ****/
module.exports = {
  /**** release network ****/
  mainnet: {
    name: 'mainnet',
    chainId: 1,
    url: 'https://api.zan.top/eth-mainnet',
    accounts: [PRV_KEY],
  },
  /**** test network ****/
  amoy: {
    name: 'amoy',
    chainId: 80002,
    url: 'https://rpc-amoy.polygon.technology',
    accounts: [PRV_KEY],
  },
  localhost: {
    name: 'localhost',
    chainId: 31337,
    url: 'http://127.0.0.1:8545'
  },
};
