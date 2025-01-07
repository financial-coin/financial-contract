const { Contract, Wallet, JsonRpcProvider, parseUnits, Interface } = require('ethers');
const Entry = require('../ignition/deployments/chain-80002/artifacts/V1#Entry.json');
const Fund = require('../ignition/deployments/chain-80002/artifacts/V1#FundTest.json');
const Address = require('../ignition/deployments/chain-80002/deployed_addresses.json');

const chainId = 80002;
const rpcUrl = 'https://rpc-amoy.polygon.technology';

// 如果要发送交易，不要忘记给账户充钱
// 0xCDbEf108c920BD4334Bb035bb05EbF3dE34f8f87
const prvKey = '0x28ab5768e28c32870efea2c225148c2d346a133228dc846452a2a8c7df728052';

const provider = new JsonRpcProvider(rpcUrl);

const signer = new Wallet(prvKey, provider);

const entry = new Contract(Address['V1#Entry'], Entry.abi, signer);
const fund = new Contract(Address['V1#FundTest'], Fund.abi, signer);

(async () => {
  const { token: tokenAddr } = await fund.getProperty();
  const token = new Contract(tokenAddr, new Interface(['function approve(address spender, uint256 value)']), signer);

  {
    const domain = {
      name: 'entry',
      version: '1',
      chainId: chainId,
      verifyingContract: entry.target,
    };
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

    const amountIn = parseUnits('24', 6);
    const amountOut = parseUnits('0.002', 18);
    const nonce = await entry.nonces(signer.address);
    const deadline = Math.floor(new Date().getTime() / 1000) + 3600;
    const value = {
      owner: signer.address,
      token: token.target,
      amountIn,
      amountOut,
      nonce,
      deadline,
    };
    const signature = await signer.signTypedData(domain, types, value);
    console.log(value);
    console.log(signature);
  }

  const tx = await token.approve.populateTransaction(entry.target, parseUnits('0.001', 18));
  const nonce = await provider.getTransactionCount(signer.address);
  const gasLimit = await provider.estimateGas({ ...tx, from: signer.address });
  // const signedTx = await signer.signTransaction({ ...tx, chainId, nonce, gasLimit, maxPriorityFeePerGas: 25000000000, maxFeePerGas: 25000000000 });
  const signedTx = await signer.signTransaction({
    ...tx,
    type: 0,
    chainId,
    nonce,
    gasLimit,
    gasPrice: 28000000000,
  });

  console.log(signedTx);
})();
