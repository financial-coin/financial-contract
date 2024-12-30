// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TestToken is ERC20("Test Token", "TT"), Ownable(msg.sender) {
    function mint(address account, uint value) external onlyOwner {
        _mint(account, value);
    }

    function burn(address account, uint value) external onlyOwner {
        _burn(account, value);
    }
}
