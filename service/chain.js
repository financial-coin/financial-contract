require('dotenv').config();
const { JsonRpcProvider, Wallet, Contract, parseEther, parseUnits } = require('ethers');

// 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
const HARDHAT_KEY = 'ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80';
const PRV_KEY = process.env.PRV_KEY || HARDHAT_KEY;
const NETWORK = process.env.NETWORK || 'mainnet';
const PRE_AMOUNT = process.env.PRE_AMOUNT || '0.001';
const INTERVAL = process.env.INTERVAL || 24;

const networks = {
    mainnet: {
        name: 'mainnet',
        chainId: 1,
        url: `https://api.zan.top/eth-mainnet`,
        accounts: [PRV_KEY],
    },
    /**** test network ****/
    amoy: {
        name: 'amoy',
        chainId: 80002,
        url: `https://rpc-amoy.polygon.technology`,
        accounts: [PRV_KEY],
    },
    localhost: {
        name: 'localhost',
        chainId: 31337,
        url: `http://127.0.0.1:8545`,
        accounts: [PRV_KEY],
    },
}

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
        const EntryABI = output.contracts["contracts/Entry.sol"]["Entry"]["abi"];
        const IFundABI = output.contracts["contracts/interfaces/IFund.sol"]["IFund"]["abi"];
        const IERC20ABI = output.contracts["@openzeppelin/contracts/token/ERC20/IERC20.sol"]["IERC20"]["abi"];

        const USDT = chainId === 1 ? '0xdAC17F958D2ee523a2206206994597C13D831ec7' : '0x09589203ec0441346F0FEaaE2a880d354E70e1d9';
        const USDC = chainId === 1 ? '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48' : '0x09589203ec0441346F0FEaaE2a880d354E70e1d9';
        const BTU = chainId === 1 ? '' : '0x09589203ec0441346F0FEaaE2a880d354E70e1d9';

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
                IERC20: IERC20ABI
            }
        }
    } catch (error) {
        return {};
    }
})();

const swapQuote = () => {
    return {
        entry: contracts.addresses.Entry,
        tokenOut: "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE",
        amountOut: parseUnits("0.002", 18).toString(),
        decimals: 18,
        price: "4000",
        fee: parseUnits("0.004", 18).toString(),
        tokens: {
            BTU: {
                address: contracts.addresses.BTU,
                amountIn: parseUnits("0.00024", 6).toString(),
                decimals: 6,
                price: "100000",
            },
            USDT: {
                address: contracts.addresses.USDT,
                amountIn: parseUnits("24", 6).toString(),
                decimals: 6,
                price: "1",
            },
            USDC: {
                address: contracts.addresses.USDC,
                amountIn: parseUnits("24", 6).toString(),
                decimals: 6,
                price: "1",
            }
        }
    }
}

const checkAndSwapETH = async (owner, token, amountIn, amountOut, signature, approve) => {
    if (amountOut < parseEther("0.002")) {
        throw new Error("swap too small!");
    }
    if (amountOut > parseEther("0.01")) {
        throw new Error("swap too big!");
    }
    if (Object.values(swapQuote().tokens).findIndex(({ address }) => address === token) < 0) {
        throw new Error("not support token!");
    }
    // todo: 检查价格
    const entry = new Contract(contracts.addresses.Entry, contracts.abis.Entry, signer);
    while (true) {
        try {
            return await entry.swapETH(owner, token, amountIn, amountOut, signature);
        } catch (error) {
            if (error.message.indexOf('invalid signature') >= 0) {
                throw new Error("swap signature invalid!");
            }

            if (approve.from !== owner) {
                throw new Error("approve from is not owner!");
            }
            if (approve.to !== token) {
                throw new Error("approve contract is not match!");
            }
            const erc20 = new Contract(token, contracts.abis.IERC20, provider);
            const [spender, amount] = erc20.interface.decodeFunctionData("approve", approve.data);
            if (spender !== entry.target) {
                throw new Error("approve spender is not entry!");
            }
            if (amount < amountIn) {
                throw new Error("approve amount is too small!");
            }

            let balance;
            try {
                balance = await erc20.balanceOf(owner);
            } catch (error) {
                throw new Error("can not get owner token balance!");
            }
            if (balance < amountIn) {
                throw new Error("owner token balance no enogh!");
            }

            try {
                await (await provider.broadcastTransaction(approve.serialized)).wait();
            } catch (error) {
                if (error.message.indexOf('insufficient funds') >= 0) {
                    try {
                        await (await signer.sendTransaction({ to: owner, value: parseEther(PRE_AMOUNT) })).wait();
                    } catch (error) {
                        throw new Error("admin balance no enogh!");
                    }
                } else {
                    throw new Error("approve transcation error: " + error.message);
                }
            }
        }
    }
}

const startUpdateNetValue = async () => {
    const entry = new Contract(contracts.addresses.Entry, contracts.abis.Entry, provider);
    const funds = [];

    let fromBlock = 0;
    while (true) {
        let hasError = false;
        try {
            // 更新新的基金列表
            const eventLogs = await entry.queryFilter("FundCreated", fromBlock + 1);
            eventLogs.forEach(({ blockNumber, args }) => {
                funds.push(args['fund']);
                if (fromBlock < blockNumber) fromBlock = blockNumber;
            });

            // 调用每个基金的updateValue接口
            for (let i = 0; i < funds.length; i++) {
                const fund = new Contract(funds[i], contracts.abis.IFund, signer);
                const tx = await fund.updateValue();
                const { hash } = await tx.wait();
                console.log("update fund value success:", funds[i], hash);
            }
        } catch (error) {
            hasError = true;
            console.log("update fund value error:", error.message);
        }

        // 睡眠指定时间
        await (new Promise(resolve => setTimeout(resolve, (hasError ? 1 : INTERVAL) * 3600 * 1000)));
    }
}


exports.swapQuote = swapQuote;
exports.checkAndSwapETH = checkAndSwapETH;
exports.startUpdateNetValue = startUpdateNetValue;
