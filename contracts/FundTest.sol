// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";
import "./Utils.sol";

contract FundTest is ERC20("Fund For Test", "FundTest"), IFund {
    Property private $;

    uint lastUpdateValueTime;
    mapping(address => uint) private costs;

    modifier onlyEntry() {
        require(msg.sender == $.entry, "only entry can call");
        _;
    }

    function initialize() external returns (address token) {
        require($.entry == address(0), "fund already initialized!");
        token = address(new TestToken());
        $.token = token;
        $.entry = msg.sender;
        $.provider = token;
        $.maxAPR = 1400; // 14%

        TestToken(token).mint(tx.origin, 10 ** 24);
        TestToken(token).transferOwnership(tx.origin);
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
        uint balance = IERC20($.token).balanceOf(address(this));
        value = balance - $.value;
        shares = _mintShares(to, value);
        $.value = balance;
    }

    function burn(
        address owner,
        address to,
        uint shares
    ) external returns (uint) {
        require(
            owner == msg.sender || $.entry == msg.sender,
            "caller is not owner"
        );
        uint value = (shares * $.value) / totalSupply();
        $.value -= value;
        _burn(owner, shares);
        costs[to] -= shares; //减少用户持仓成本
        emit Burn(owner, shares, value);
        IERC20($.token).transfer(to, value);
        return value;
    }

    function updateValue(
        bytes calldata data
    ) external payable returns (uint value) {
        if (block.timestamp - lastUpdateValueTime > 86000) {
            if (data.length == 32) {
                uint amountIn = abi.decode(data, (uint));
                IERC20($.provider).transferFrom(
                    tx.origin,
                    address(this),
                    amountIn
                );
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
                (block.timestamp - lastUpdateValueTime)) /
                (365 * 24 * 3600 * 10000));
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
}
