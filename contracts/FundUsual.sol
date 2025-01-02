// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

contract FundUsual is ERC20("Wrapped Usual Fund", "FundUsual"), IFund {
    Property private $;

    uint lastUpdateValueTime;
    mapping(address => uint) private costs;

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant Distribution = 0x75cC0C0DDD2Ccafe6EC415bE686267588011E36A;
    address constant USD0PP = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address constant USUAL = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E;

    // 代币兑换事件
    event Swapped(
        address tokenIn,
        uint amountIn,
        address tokenB,
        uint amountOut
    );

    modifier onlyEntry() {
        require(msg.sender == $.entry, "only entry can call");
        _;
    }

    function initialize() external returns (address token) {
        require($.entry == address(0), "fund already initialized!");
        $.token = USDC;
        $.entry = msg.sender;
        $.provider = USD0PP;
        $.maxAPR = 1400; // 14%
        return $.token;
    }

    // 和输入代币保持相同的精度
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function getProperty() external view returns (Property memory result) {
        result = $;
        result.shares = totalSupply();
    }

    function getAccount(
        address owner
    ) external view returns (uint shares, uint value, uint cost) {
        if ($.value > 0) {
            shares = balanceOf(owner);
            value = ($.value * totalSupply()) / shares;
            cost = costs[owner];
        }
    }

    function getMaxAPR() external view returns (uint) {
        return $.maxAPR;
    }

    function setMaxAPR(uint newAPR) external onlyEntry {
        $.maxAPR = newAPR;
        emit SetMaxAPR(newAPR);
    }

    function mint(address to) public payable returns (uint shares, uint value) {
        uint amountIn = IERC20($.token).balanceOf(address(this));
        if (amountIn > 0) {
            // 将USDC兑换USD0++
            _USDC2USD0PP(address(this), amountIn);
        }
        uint balance = IERC20($.provider).balanceOf(address(this));
        value = balance - $.value;
        shares = _mintShares(to, value);
        $.value = balance;
    }

    function burn(
        address owner,
        address to,
        uint shares
    ) external returns (uint amount) {
        require(
            owner == msg.sender || $.entry == msg.sender,
            "caller is not owner"
        );
        uint value = (shares * $.value) / totalSupply();
        $.value -= value;
        _burn(owner, shares);
        costs[to] -= shares; //减少用户持仓成本
        emit Burn(owner, shares, value);
        // 将<value>个USD0++兑换成USDC发给<to>地址
        amount = _USD0PP2USDC(to, value);
    }

    function updateValue(
        bytes calldata data
    ) external payable returns (uint value) {
        // Updated every 24H
        if (block.timestamp - lastUpdateValueTime > 86000) {
            if (data.length > 128) {
                if (bytes4(data[0:4]) == 0xed99f469) {
                    // claimOffChainDistribution(address account,uint256 amount,bytes32[] proof)
                    (bool success, ) = Distribution.call(data);
                    if (success) {
                        //  将usual兑换为USD0++，直接从参数中提取兑换数量
                        uint amount = uint(bytes32(data[36:68]));
                        _USUAL2USD0PP(address(this), amount);
                    }
                }
            }
        }
        value = IERC20($.provider).balanceOf(address(this));
        _updateValue(value);
    }

    function _mintShares(
        address to,
        uint value
    ) internal returns (uint shares) {
        if ($.value == 0) {
            shares = value;
        } else {
            shares = (value * totalSupply()) / $.value;
        }
        _mint(to, shares);
        costs[to] += value; //更新用户持仓成本
        emit Mint(to, shares, value);
    }

    function _updateValue(uint value) internal {
        if ($.value < value) {
            // 截取超过MaxAPR的收益，当作平台收益
            uint maxAddValue = (($.value *
                $.maxAPR *
                (block.timestamp - lastUpdateValueTime)) / 365) *
                24 *
                3600 *
                10000;
            if (maxAddValue > value - $.value) {
                _mintShares(
                    IEntry($.entry).feeTo(),
                    maxAddValue - (value - $.value)
                );
            }
            lastUpdateValueTime = block.timestamp;
        }
        $.value = value;
        emit UpdateValue(value, block.timestamp);
    }

    // 兑换流动池地址，除了兑换方式，USD0可1：1质押获得USD0++，可查兑换价格是否大于1来选择兑换或者质押
    address constant key1 = 0x14154C15fc0fD3f91DE557a1B6FdD2059972Cd0B; // USUAL to WETH, tokenA:WETH
    address constant key2 = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640; // WETH to USDC, tokenA:USDC
    address constant key3 = 0x14100f81e33C33Ecc7CDac70181Fb45B6E78569F; // USDC to USD0, tokenA:USD0
    address constant key4 = 0x1d08E7adC263CfC70b1BaBe6dC5Bb339c16Eec52; // USD0 to USD0++, tokenA:USD0

    // USDC => USD0++
    function _USDC2USD0PP(
        address to,
        uint amountIn
    ) internal returns (uint amountOut) {
        if (amountIn > 0) {
            IERC20(USDC).transfer(key3, amountIn);
            amountOut = _curveswap(key3, false, key4, amountIn);
            amountOut = _curveswap(key4, true, to, amountOut);

            emit Swapped(USDC, amountIn, USD0PP, amountOut);
        }
    }

    // USD0++ => USDC
    function _USD0PP2USDC(
        address to,
        uint amountIn
    ) internal returns (uint amountOut) {
        if (amountIn > 0) {
            IERC20(USD0PP).transfer(key4, amountIn);
            amountOut = _curveswap(key4, false, key3, amountIn);
            amountOut = _curveswap(key3, true, to, amountOut);

            emit Swapped(USD0PP, amountIn, USDC, amountOut);
        }
    }

    // USUAL => USD0++
    function _USUAL2USD0PP(
        address to,
        uint amountIn
    ) internal returns (uint amountOut) {
        if (amountIn > 0) {
            IERC20(USUAL).transfer(key1, amountIn);
            // 参考交易： 0x6230b04503c132d1a3dcf76a835daa106b5dbb74e50b7dedceed10c5940eee2b
            amountOut = _uniswap(key1, false, key2, amountIn);
            // 参考交易： 0xd5b9fd81033eae0d8eb53ac9052752c4fe74b5d3ff8d26649abc9f43b8d7eaf6
            amountOut = _uniswap(key2, false, key3, amountOut);
            // 参考交易： 0xc8f996fdb13720db63a931a953becfc0161194203937a5634ccfb649142b5ded
            amountOut = _curveswap(key3, false, key4, amountOut);
            // 参考交易： 0xfaa34026372bb42bebbbfd48779e93b0dfb459a2cb85262c0950b93acd5a317b
            amountOut = _curveswap(key4, true, to, amountOut);

            emit Swapped(USUAL, amountIn, USD0PP, amountOut);
        }
    }

    function _uniswap(
        address key,
        bool outTokenB,
        address to,
        uint amount
    ) internal returns (uint) {
        (int256 amount0, int256 amount1) = UniswapPool(key).swap(
            to,
            outTokenB,
            int256(amount),
            MAX_SQRT_RATIO,
            new bytes(0)
        );
        if (amount0 > 0) {
            return uint(amount0);
        } else {
            return uint(amount1);
        }
    }

    function _curveswap(
        address key,
        bool outTokenB,
        address to,
        uint amount
    ) internal returns (uint) {
        (int128 i, int128 j) = outTokenB
            ? (int128(0), int128(1))
            : (int128(1), int128(0));
        return CurveSwapNG(key).exchange_received(i, j, amount, 1, to);
    }
}

uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;

interface UniswapPool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface CurveSwapNG {
    function last_price(uint256 i) external returns (uint);

    function exchange(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint amountOut);

    function exchange_received(
        int128 i,
        int128 j,
        uint256 _dx,
        uint256 _min_dy,
        address _receiver
    ) external returns (uint amountOut);
}
