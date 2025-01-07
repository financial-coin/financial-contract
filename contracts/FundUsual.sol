// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {FundBase} from './FundBase.sol';
import {Exchange} from './Exchange.sol';

contract FundUsual is FundBase {
    address constant Distribution = 0x75cC0C0DDD2Ccafe6EC415bE686267588011E36A;
    address constant USD0PP = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0;
    address constant USUAL = 0xC4441c2BE5d8fA8126822B9929CA0b81Ea0DE38E;

    function initialize() external returns (address token) {
        token = USD0PP;
        __Fund_init(USD0PP, Distribution, 1400, 'Wrapped Usual Fund', 'FundUsual');
    }

    function updateValue(bytes calldata data) external payable override returns (uint value) {
        // Updated every 24H
        if (block.timestamp - _updatedAt() > 86000) {
            if (data.length > 128) {
                if (bytes4(data[0:4]) == 0xed99f469) {
                    // claimOffChainDistribution(address account,uint256 amount,bytes32[] proof)
                    (bool success, ) = Distribution.call(data);
                    if (success) {
                        //  将usual兑换为USD0++，直接从参数中提取兑换数量
                        uint amount = uint(bytes32(data[36:68]));
                        Exchange._swap(address(0), USUAL, USD0PP, amount, address(this));
                    }
                }
            }
        }
        value = IERC20(USD0PP).balanceOf(address(this));
        _updateValue(value);
    }
}
