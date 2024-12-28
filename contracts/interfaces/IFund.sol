// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// 原生代币占位表示
address constant EthToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

interface IFund is IERC20 {
    // 基金铸造（购买）事件
    event Mint(address to, uint shares, uint value);
    // 基金销毁（赎回）事件
    event Burn(address owner, uint shares, uint value);
    // 基金总价值更新事件
    event ValueUpdated(uint value, uint oldValue);

    // 基金属性
    struct Property {
        address token; // 支付或赎回的代币，如果值为EthToken，则表示原生代币
        uint value; // 基金总价值
        uint shares; // 基金总份额，用户购买时增加，赎回时减少
        uint netValue; // 基金净值 = 基金总价值/基金总份额，有收益时增加
        address entry; // 入口合约地址
        address provider; // 供给合约地址，提供收益的合约
        // uint feeRate; // 买入卖出手续费率
    }

    // 初始化基金，注册基金的时候，入口合约进行调用
    function initialize(address entry, bytes memory data) external;

    // 查询基金属性
    function getProperty() external view returns (Property memory property);

    // 查询指定账户的基金价值(按购买的代币计算)和份额
    function getAccount(
        address owner
    ) external view returns (uint value, uint shares);

    // 查询自购买后获得的累计收益（减去已领取部分）
    function getProfit(address owner) external view returns (uint profit);

    // 铸造基金给指定用户，返回份额数量，代币需要提前转给合约
    function mint(
        address to,
        bytes calldata data
    ) external payable returns (uint shares);

    // 销毁指定账户的基金份额，返回代币数量
    function burn(
        address owner,
        address to,
        uint shares,
        bytes calldata data
    ) external returns (uint amount);

    // 领取基金当前累计收益，返回代币数量
    function claimProfit(
        address owner,
        address to,
        bytes memory data
    ) external returns (uint amount);

    // 更新基金总价值
    function updateValue() external returns (uint value);
}
