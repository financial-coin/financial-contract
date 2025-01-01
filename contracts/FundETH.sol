// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

contract FundETH is ERC20("Test Fund", "TF"), IFund {
    Property private property;

    modifier onlyEntry() {
        require(msg.sender == property.entry, "call is not from entry");
        _;
    }

    function initialize() external returns (address token) {
        require(property.entry == address(0), "fund already initialized!");
        property.token = EthToken;
        property.entry = msg.sender;
        return EthToken;
    }

    function getProperty() external view returns (Property memory) {}

    function getAccount(
        address owner
    ) external view returns (uint shares, uint value, uint cost) {}

    function getMaxAPR() external view returns (uint) {}

    function setMaxAPR(uint newAPR) external onlyEntry {}

    function mint(
        address to
    ) external payable onlyEntry returns (uint shares, uint value) {}

    function burn(
        address owner,
        address to,
        uint shares
    ) external onlyEntry returns (uint amount) {}

    function updateValue(
        bytes calldata data
    ) external payable returns (uint newValue) {}
}
