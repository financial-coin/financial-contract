// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "./IFund.sol";

interface IEntry {
    // 基金创建事件
    event FundCreated(uint indexed index, address indexed fund);
    // 用户兑换ETH事件
    event SwapETH(
        address indexed owner,
        address indexed token,
        uint amountIn,
        uint amountOut
    );

    // 允许合约接收原生货币
    receive() external payable;

    // 查询指定索引的基金地址，超过索引的报错
    function funds(uint index) external view returns (address);

    // 查询基金总数
    function fundsLength() external view returns (uint);

    // 使用基金合约字节码创建基金
    function createFund(
        bytes memory code
    ) external returns (uint index, address fund);

    // 使用基金地址注册
    function registerFund(address fund) external returns (uint index);

    // 查询基金属性
    function getFundProperty(
        address fund
    ) external view returns (IFund.Property memory);

    // 查询指定账户基金的份额、价值和成本等等
    function getFundAccount(
        address fund,
        address owner
    ) external view returns (uint shares, uint value, uint cost);

    // 设置基金最大年化利率
    function setFundMaxAPR(address fund, uint newAPR) external;

    // 使用指定数量的代币批准购买指定基金给指定用户，返回购买的基金份额
    function buyFund(
        address fund,
        address to,
        address token,
        uint amount,
        uint deadline,
        bytes memory permit
    ) external returns (uint shares, uint value);

    // 使用指定数量的代币购买指定基金给指定用户，返回购买的基金份额
    function buyFund(
        address fund,
        address to,
        address token,
        uint amount
    ) external returns (uint shares, uint value);

    // 使用指定数量的ETH购买指定基金给指定用户，返回购买的基金份额
    function buyFund(
        address fund,
        address to
    ) external payable returns (uint shares, uint value);

    // 赎回指定份额的基金到指定用户，返回代币数量
    function redeemFund(
        address fund,
        address to,
        uint shares
    ) external returns (uint amount);

    // 更新基金总价值
    function updateFundValue(
        address fund,
        bytes memory data
    ) external payable returns (uint value);

    // 使用用户签名批准花费指定代币兑换ETH（前端签发一笔代币approve交易和批准兑换ETH的签名）
    // 如果前端报价太低，后端有权拒绝，后端会预先发送少部分ETH给用户，让approve交易可以成交，要覆盖这个成本
    // structHash: SwapETH(address owner,address token,uint256 amountIn,uint256 amountOut,uint256 nonce,uint256 deadline)
    function swapETH(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        uint deadline,
        bytes memory permit
    ) external;

    // 查询EIP712签名域分隔符
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    // 查询指定用户签名随机数，每次使用后加一
    function nonces(address owner) external view returns (uint);

    function feeTo() external view returns (address);

    // 取出原生货币
    function withdrawTo(address to, uint amount) external;

    // 取出指定代币
    function withdrawTo(address to, address token, uint amount) external;
}
