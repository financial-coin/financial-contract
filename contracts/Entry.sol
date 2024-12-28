// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

contract Entry is Initializable, OwnableUpgradeable, UUPSUpgradeable, IEntry {
    address[] public funds;
    mapping(address => uint) private indexOf;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function fundsLength() external view returns (uint) {
        return funds.length;
    }

    function createFund(
        bytes calldata code
    ) external onlyOwner returns (uint index, address fund) {
        assembly {
            fund := create(0, code.offset, code.length)
        }
        index = funds.length;
        indexOf[fund] = index;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function registerFund(address fund, bytes calldata data) external returns (uint index) {
        require(fund != address(0), "invaild fund address");
        if (funds.length > 0) {
            require(
                indexOf[fund] == 0 && funds[0] != fund,
                "exist fund address"
            );
        }
        IFund(fund).initialize(address(this), data);
        index = funds.length;
        indexOf[fund] = index;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function getFundProperty(
        address fund
    ) external view returns (IFund.Property memory property) {
        return IFund(fund).getProperty();
    }

    function getFundAccount(
        address fund,
        address owner
    ) external view returns (uint value, uint shares) {
        return IFund(fund).getAccount(owner);
    }

    function getFundProfit(
        address fund,
        address owner
    ) external view returns (uint profit) {
        return IFund(fund).getProfit(owner);
    }

    function buyFund(
        address fund,
        address to,
        address token,
        uint amount,
        bytes memory data
    ) external returns (uint shares) {
        IERC20(token).transferFrom(msg.sender, fund, amount);
        shares = IFund(fund).mint(to, data);
    }

    function buyFund(
        address fund,
        address to,
        bytes memory data
    ) external payable returns (uint shares) {
        shares = IFund(fund).mint{value: msg.value}(to, data);
    }

    function redeemFund(
        address fund,
        address to,
        uint shares,
        bytes memory data
    ) external returns (uint amount) {
        return IFund(fund).burn(msg.sender, to, shares, data);
    }

    function claimFundProfit(
        address fund,
        address to,
        bytes memory data
    ) external returns (uint amount) {
        return IFund(fund).claimProfit(msg.sender, to, data);
    }

    function updateFundValue(
        address fund
    ) external onlyOwner returns (uint netValue) {
        return IFund(fund).updateValue();
    }

    function swapETH(
        address user,
        address token,
        uint amount,
        uint outAmount,
        bytes calldata signature
    ) external onlyOwner {
        // todo: check user signature
        IERC20(token).transferFrom(user, address(this), amount);
        payable(user).transfer(outAmount);
    }
}
