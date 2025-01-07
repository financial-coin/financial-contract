// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {FundBase} from './FundBase.sol';
import {TestToken} from './Utils.sol';

contract FundTest is FundBase {
    function initialize() external returns (address token) {
        token = address(new TestToken());
        TestToken(token).mint(tx.origin, 10 ** 24);
        TestToken(token).transferOwnership(tx.origin);

        __Fund_init(token, token, 1400, 'Fund For Test', 'FundTest');
    }
}
