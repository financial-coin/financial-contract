const axios = require('axios');
const { JsonRpcProvider, Wallet, Contract, parseUnits, Interface, AbiCoder } = require('ethers');
const networks = require('../networks');

// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
const HARDHAT_KEY = 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const PRV_KEY = process.env.PRV_KEY || HARDHAT_KEY;
const NETWORK = process.env.NETWORK || 'mainnet';
const PRE_AMOUNT = process.env.PRE_AMOUNT || '0.001';
const INTERVAL = process.env.INTERVAL || 24;

const network = networks[NETWORK];
const { chainId, url } = network;
const provider = new JsonRpcProvider(url);
const signer = NETWORK === 'localhost' ? new Wallet(HARDHAT_KEY, provider) : new Wallet(PRV_KEY, provider);

const contracts = (() => {
  try {
    const prefix = `../ignition/deployments/chain-${chainId}/`;
    const addresses = require(prefix + 'deployed_addresses.json');
    const { buildInfo } = require(prefix + 'artifacts/V1#Entry.dbg.json');
    const { output } = require(prefix + 'artifacts/' + buildInfo);
    const EntryABI = output.contracts['contracts/Entry.sol']['Entry']['abi'];
    const IFundABI = output.contracts['contracts/interfaces/IFund.sol']['IFund']['abi'];
    const IERC20ABI = output.contracts['@openzeppelin/contracts/token/ERC20/IERC20.sol']['IERC20']['abi'];

    const USDT = chainId === 1 ? '0xdAC17F958D2ee523a2206206994597C13D831ec7' : '0xf98BC3483c618b82B16367B606Cc3467E049B865';
    const USDC = chainId === 1 ? '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' : '0xf98BC3483c618b82B16367B606Cc3467E049B865';
    const BTU = chainId === 1 ? '' : '0xf98BC3483c618b82B16367B606Cc3467E049B865';

    return {
      addresses: {
        Entry: addresses['V1#Entry'],
        USDT: USDT,
        USDC: USDC,
        BTU: BTU,
      },
      abis: {
        Entry: EntryABI,
        IFund: IFundABI,
        IERC20: IERC20ABI,
      },
    };
  } catch {
    return {};
  }
})();

const swapQuote = () => {
  return {
    entry: contracts.addresses.Entry,
    tokenOut: '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE',
    amountOut: parseUnits('0.002', 18).toString(),
    decimals: 18,
    price: '4000',
    fee: parseUnits('0.004', 18).toString(),
    tokens: {
      BTU: {
        address: contracts.addresses.BTU,
        amountIn: parseUnits('24', 6).toString(),
        decimals: 6,
        price: '1',
      },
      USDT: {
        address: contracts.addresses.USDT,
        amountIn: parseUnits('24', 6).toString(),
        decimals: 6,
        price: '1',
      },
      USDC: {
        address: contracts.addresses.USDC,
        amountIn: parseUnits('24', 6).toString(),
        decimals: 6,
        price: '1',
      },
    },
  };
};

const checkAndSwapETH = async (owner, token, amountIn, amountOut, deadline, signature, approve) => {
  // todo: 检查价格
  if (amountIn !== parseUnits('24', 6)) {
    throw new Error('amountIn error!');
  }
  if (amountOut !== parseUnits('0.002', 18)) {
    throw new Error('amountOut error!');
  }
  if (Object.values(swapQuote().tokens).findIndex(({ address }) => address === token) < 0) {
    throw new Error('not support token!');
  }
  if (deadline < Math.floor(new Date().getTime() / 1000) + 600) {
    throw new Error('deadline too short!');
  }

  const entry = new Contract(contracts.addresses.Entry, contracts.abis.Entry, signer);
  const erc20 = new Contract(token, contracts.abis.IERC20, provider);
  const allowance = await erc20.allowance(owner, entry.target);
  if (allowance < amountIn) {
    if (approve.from !== owner) {
      throw new Error('approve from is not owner!');
    }
    if (approve.to !== token) {
      throw new Error('approve contract is not match!');
    }
    const nonce = await provider.getTransactionCount(owner);
    if (approve.nonce !== nonce) {
      throw new Error('approve amount is too small!');
    }
    const [spender, amount] = erc20.interface.decodeFunctionData('approve', approve.data);
    if (spender !== entry.target) {
      throw new Error('approve spender is not entry!');
    }
    if (amount < amountIn) {
      throw new Error('approve amount is too small!');
    }

    const balance = await provider.getBalance(owner);
    if (balance < parseUnits(PRE_AMOUNT, 18)) {
      await signer.sendTransaction({
        to: owner,
        value: parseUnits(PRE_AMOUNT, 18),
        blockTag: 'pending',
      });
    }
    await provider.broadcastTransaction(approve.serialized);
  }

  return await entry['swapETH(address,address,uint256,uint256,uint256,bytes)'](owner, token, amountIn, amountOut, deadline, signature, {
    blockTag: 'pending',
  });
};

const startUpdateNetValue = async () => {
  let fromBlock = 0;
  const funds = [];
  const entry = new Contract(contracts.addresses.Entry, contracts.abis.Entry, provider);
  while (true) {
    let hasError = false;
    try {
      // 更新新的基金列表
      const eventLogs = await entry.queryFilter('FundCreated', fromBlock + 1);
      eventLogs.forEach(({ blockNumber, args }) => {
        funds.push(args['fund']);
        if (fromBlock < blockNumber) fromBlock = blockNumber;
      });

      // 调用每个基金的updateValue接口
      const works = [];
      for (let i = 0; i < funds.length; i++) {
        const fund = new Contract(funds[i], contracts.abis.IFund, signer);
        const property = await fund.getProperty();
        if (property.value > 0) {
          switch (property.provider) {
            case '0x35D8949372D46B7a3D5A56006AE77B215fc69bC0': {
              // USD0++
              const { data: rewards } = await axios.get(`https://app.usual.money/api/rewards/${funds[i]}`);
              if (rewards.length > 0) {
                const { value, merkleProof } = rewards[rewards.length - 1];
                const interface = new Interface(['function claimOffChainDistribution(address account,uint256 amount,bytes32[] proof)']);
                const data = interface.encodeFunctionData('claimOffChainDistribution', [funds[i], value, merkleProof]);
                works.push((await fund.updateValue(data, { blockTag: 'pending' })).wait());
              } else {
                console.log('skip fund because there is no income:', funds[i]);
              }
              break;
            }
            default: {
              const erc20 = new Contract(property.token, contracts.abis.IERC20, signer);
              await (
                await erc20.approve(funds[i], 10n * 22n, {
                  blockTag: 'pending',
                })
              ).wait();
              const amount = (Math.random() * Number(property.value) * 8).toFixed(0);
              await (await erc20.transfer(fund, amount)).wait();
              works.push((await fund.updateValue('0x', { blockTag: 'pending' })).wait());
              break;
            }
          }
        } else {
          console.log('skip fund because the value is zero:', funds[i]);
        }
      }
      const txResults = await Promise.all(works);
      txResults.forEach(({ hash }) => {
        console.log('update fund value success:', hash);
      });
    } catch (error) {
      hasError = true;
      console.log('update fund value error:', error.message);
    }

    // 睡眠指定时间
    await new Promise((resolve) => setTimeout(resolve, (hasError ? 1 : INTERVAL) * 3600 * 1000));
  }
};

exports.swapQuote = swapQuote;
exports.checkAndSwapETH = checkAndSwapETH;
exports.startUpdateNetValue = startUpdateNetValue;
