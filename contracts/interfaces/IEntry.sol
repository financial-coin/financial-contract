// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./IFund.sol";

interface IEntry {
    // 基金创建事件
    event FundCreated(uint indexed index, address indexed fund);

    // 查询指定索引的基金地址
    function funds(uint index) external view returns (address);

    // 查询基金总数
    function fundsLength() external view returns (uint);

    // 使用基金合约字节码创建基金
    function createFund(
        bytes calldata code
    ) external returns (uint index, address fund);

    // 使用基金地址注册
    function registerFund(
        address fund,
        bytes calldata data
    ) external returns (uint index);

    // 查询基金属性
    function getFundProperty(
        address fund
    ) external view returns (IFund.Property memory property);

    // 查询指定账户的基金价值(按购买的代币计算)和份额
    function getFundAccount(
        address fund,
        address owner
    ) external view returns (uint value, uint shares);

    // 查询自购买后获得的累计收益（减去已领取部分）
    function getFundProfit(
        address fund,
        address owner
    ) external view returns (uint profit);

    // 使用指定数量的代币购买指定基金给指定用户，返回购买的基金份额
    function buyFund(
        address fund,
        address to,
        address token,
        uint amount,
        bytes memory data
    ) external returns (uint shares);

    // 使用指定数量的ETH购买指定基金给指定用户，返回购买的基金份额
    function buyFund(
        address fund,
        address to,
        bytes memory data
    ) external payable returns (uint shares);

    // 赎回指定份额的基金到指定用户，返回代币数量
    function redeemFund(
        address fund,
        address to,
        uint shares,
        bytes memory data
    ) external returns (uint amount);

    // 领取基金当前累计收益，返回代币数量
    function claimFundProfit(
        address fund,
        address to,
        bytes memory data
    ) external returns (uint amount);

    // 更新基金总价值，应该由后端服务定时调用
    function updateFundValue(address fund) external returns (uint netValue);

    // 使用用户签名批准花费指定代币兑换ETH（前端签发一笔代币approve交易和批准兑换ETH的签名）
    // 如果前端报价太低，后端有权拒绝，后端会预先发送少部分ETH给用户，让approve交易可以成交，要覆盖这个成本
    function swapETH(
        address user,
        address token,
        uint amount,
        uint outAmount,
        bytes calldata signature
    ) external;
}
