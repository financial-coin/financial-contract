// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC1967Proxy} from '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol';
import {ERC20Permit, ERC20} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

contract TestToken is ERC20Permit, Ownable(msg.sender) {
    constructor() ERC20('Test Token', 'TT') ERC20Permit('Test Token') {}

    // 和USDC保持一样的6位精度
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address account, uint value) external onlyOwner {
        _mint(account, value);
    }

    function burn(address account, uint value) external onlyOwner {
        _burn(account, value);
    }
}
