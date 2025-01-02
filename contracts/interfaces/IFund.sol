// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// 原生代币占位表示
address constant EthToken = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

interface IFund is IERC20 {
    // 设置基金最大年化利率事件
    event SetMaxAPR(uint APR);
    // 基金铸造（购买）事件
    event Mint(address to, uint shares, uint value);
    // 基金销毁（赎回）事件
    event Burn(address owner, uint shares, uint value);
    // 基金总价值更新事件
    event UpdateValue(uint value, uint time);

    // 基金属性
    struct Property {
        address token; // 支付或赎回的代币，如果值为<EthToken>，则表示原生代币
        uint value; // 基金总价值，基金净值 = 基金总价值/基金总份额
        uint shares; // 基金总份额，用户购买时增加，赎回时减少
        address entry; // 入口合约地址
        address provider; // 供给合约地址，提供收益的合约
        uint maxAPR; // 最大年化利率，单位万分一，超过部分归平台所有
        // uint feeRate; // 买卖手续费率
    }

    // 初始化基金，入口合约进行调用，返回基金支付代币
    function initialize() external returns (address token);

    // 查询基金属性
    function getProperty() external view returns (Property memory);

    // 查询指定账户的份额、基金价值和成本
    function getAccount(
        address owner
    ) external view returns (uint shares, uint value, uint cost);

    // 查询基金最大年化利率，单位万分一
    function getMaxAPR() external view returns (uint);

    // 设置基金最大年化利率
    function setMaxAPR(uint newAPR) external;

    // 铸造基金给指定用户，返回份额数量，代币需要提前转给合约
    function mint(
        address to
    ) external payable returns (uint shares, uint value);

    // 销毁指定账户的基金份额，返回代币数量
    function burn(
        address owner,
        address to,
        uint shares
    ) external returns (uint amount);

    // 更新基金总价值
    function updateValue(
        bytes calldata data
    ) external payable returns (uint value);
}
