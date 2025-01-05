// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

abstract contract FundBase is ERC20Upgradeable, IFund {
    Property private $;
    mapping(address => uint) private costs; //简单跟踪账户持仓成本，每次赎回会置为0

    function __Fund_init(
        address token,
        address provider,
        uint maxAPR,
        string memory name,
        string memory symbol
    ) internal initializer {
        $.entry = msg.sender;
        $.token = token;
        $.provider = provider;
        $.maxAPR = maxAPR;
        $.createdAt = block.timestamp;
        $.updatedAt = block.timestamp;

        __ERC20_init(name, symbol);
    }

    modifier onlyEntry() {
        require(msg.sender == $.entry, "only entry can call");
        _;
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
            value = (shares * $.value) / totalSupply();
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

    function _entry() internal view returns (address) {
        return $.entry;
    }

    function _token() internal view returns (address) {
        return $.token;
    }

    function _provider() internal view returns (address) {
        return $.provider;
    }

    function _updatedAt() internal view returns (uint) {
        return $.updatedAt;
    }

    // newValue 为新的基金总价值
    function _mintShares(
        address to,
        uint newValue
    ) internal returns (uint shares, uint value) {
        value = newValue - $.value;
        if ($.value == 0) {
            shares = value;
        } else {
            shares = (value * totalSupply()) / $.value;
        }
        costs[to] += value; //更新用户持仓成本
        $.value = newValue;
        _mint(to, shares);

        emit Mint(to, shares, value);
    }

    function _burnShares(
        address owner,
        uint shares
    ) internal returns (uint value) {
        require(
            owner == msg.sender || $.entry == msg.sender,
            "caller is not owner or entry"
        );
        value = (shares * $.value) / totalSupply();
        _burn(owner, shares);
        costs[owner] = 0; //重置用户持仓成本
        $.value -= value;
        emit Burn(owner, shares, value);
    }

    function _updateValue(uint newValue) internal {
        assert(newValue >= $.value);
        // 截取超过MaxAPR的收益，当作平台收益
        unchecked {
            uint maxAddValue = (($.value *
                $.maxAPR *
                (block.timestamp - $.updatedAt)) / (365 * 24 * 3600 * 10000));
            if (maxAddValue < newValue - $.value) {
                $.value += maxAddValue;
                _mintShares(IEntry($.entry).feeTo(), newValue);
            } else {
                $.value = newValue;
            }
        }
        $.updatedAt = block.timestamp;
        emit UpdateValue(newValue, block.timestamp);
    }
}
