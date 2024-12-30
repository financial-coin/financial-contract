// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

contract FundETH is ERC20("Test Fund", "TF"), IFund {
    Property private property;

    uint lastBalance;
    mapping(address => uint) lastNetValue;

    function initialize(address entry, bytes memory data) external {
        require(property.entry == address(0), "fund already initialized!");
        property.token = EthToken;
        property.entry = entry;
    }

    function getProperty() external view returns (Property memory) {
        Property memory result = property;
        result.shares = totalSupply();
        result.netValue = result.value / result.shares;
        return result;
    }

    function getAccount(
        address owner
    ) external view returns (uint shares, uint value, uint cost) {
        shares = balanceOf(owner);
        value = (shares * property.value) / totalSupply();
    }

    function mint(
        address to,
        bytes calldata data
    ) external payable returns (uint shares) {
        uint balance = address(this).balance;
        if (totalSupply() == 0) {
            property.value = balance;
            shares = property.value * 10000;
        } else {
            uint dValue = balance - lastBalance;
            shares = (dValue * totalSupply()) / property.value;
            property.value += (shares * property.value) / totalSupply();
        }
        lastBalance = balance;
        _mint(to, shares);
    }

    function burn(
        address owner,
        address to,
        uint shares,
        bytes calldata data
    ) external returns (uint amount) {
        amount = (shares * property.value) / totalSupply();
        lastBalance -= amount;
        _burn(owner, shares);
        payable(to).transfer(amount);
    }

    function updateValue() external returns (uint value) {}
}
