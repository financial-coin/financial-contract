// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./FundBase.sol";
import "./Utils.sol";

contract FundTest is FundBase {
    function initialize() external returns (address token) {
        token = address(new TestToken());
        TestToken(token).mint(tx.origin, 10 ** 24);
        TestToken(token).transferOwnership(tx.origin);

        uint maxAPR = 1400; // MaxAPR = 14%
        __Fund_init(token, token, maxAPR, "Fund For Test", "FundTest");
    }

    // 和输入代币保持相同的精度
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to) public payable returns (uint shares, uint value) {
        uint newValue = IERC20(_token()).balanceOf(address(this));
        return _mintShares(to, newValue);
    }

    function burn(
        address owner,
        address to,
        uint shares
    ) external returns (uint value) {
        value = _burnShares(owner, shares);
        IERC20(_token()).transfer(to, value);
    }

    function updateValue(
        bytes calldata data
    ) external payable returns (uint value) {
        if (data.length == 32) {
            if (block.timestamp - _updatedAt() > 86000) {
                uint amountIn = abi.decode(data, (uint));
                IERC20(_provider()).transferFrom(
                    tx.origin,
                    address(this),
                    amountIn
                );
            }
        }

        value = IERC20(_provider()).balanceOf(address(this));
        _updateValue(value);
    }
}
