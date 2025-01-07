// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {UUPSUpgradeable} from '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import {EIP712Upgradeable} from '@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol';
import {NoncesUpgradeable} from '@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol';
import {ECDSA} from '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import {IERC20Permit} from '@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol';
import {IERC20} from '@openzeppelin/contracts/interfaces/IERC20.sol';
import {IEntry} from './interfaces/IEntry.sol';
import {IFund} from './interfaces/IFund.sol';
import {Exchange} from './Exchange.sol';

contract Entry is Initializable, OwnableUpgradeable, UUPSUpgradeable, EIP712Upgradeable, NoncesUpgradeable, IEntry {
    bytes32 private constant SWAP_TYPEHASH =
        keccak256('SwapETH(address owner,address token,uint256 amountIn,uint256 amountOut,uint256 nonce,uint256 deadline)');
    bytes32 private constant ERC20_PERMIT_SELECTOR = IERC20Permit.permit.selector;

    address[] public funds;
    mapping(address => address) public getFundToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __EIP712_init_unchained('entry', '1');
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    receive() external payable {}

    function fundsLength() external view returns (uint) {
        return funds.length;
    }

    function createFund(bytes memory code) external onlyOwner returns (uint index, address fund) {
        bytes32 salt = keccak256(code);
        assembly {
            fund := create2(0, add(code, 32), mload(code), salt)
        }
        address token = IFund(fund).initialize();
        index = funds.length;
        getFundToken[fund] = token;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function registerFund(address fund) external onlyOwner returns (uint index) {
        address token = IFund(fund).initialize();
        require(token != address(0), 'invaild token address');
        require(getFundToken[fund] == address(0), 'exist the fund');
        index = funds.length;
        getFundToken[fund] = token;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function getFundProperty(address fund) external view returns (IFund.Property memory) {
        return IFund(fund).getProperty();
    }

    function getFundAccount(address fund, address owner) external view returns (uint shares, uint value, uint cost) {
        return IFund(fund).getAccount(owner);
    }

    function setFundMaxAPR(address fund, uint newAPR) external onlyOwner {
        IFund(fund).setMaxAPR(newAPR);
    }

    function buyFund(address fund, address to, address token, uint amount, bytes calldata permitData) external returns (uint shares, uint value) {
        _execPermit(token, permitData);
        Exchange._swap(msg.sender, token, getFundToken[fund], amount, fund);
        return IFund(fund).mint(to);
    }

    function buyFund(address fund, address to, address token, uint amount) external payable returns (uint shares, uint value) {
        Exchange._swap(msg.sender, token, getFundToken[fund], amount, fund);
        return IFund(fund).mint{value: msg.value}(to);
    }

    function redeemFund(address fund, address to, uint shares) external returns (uint amount) {
        uint value = IFund(fund).burn(msg.sender, address(this), shares);
        amount = Exchange._swap(msg.sender, getFundToken[fund], Exchange.USDC, value, to);
    }

    function updateFundValue(address fund, bytes calldata data) external payable returns (uint value) {
        return IFund(fund).updateValue{value: msg.value}(data);
    }

    function swapToken(address tokenIn, uint amountIn, address tokenOut, uint minOut) external {}

    function swapETH(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        uint deadline,
        bytes calldata signature
    ) external payable onlyOwner {
        _swapETH(owner, token, amountIn, amountOut, deadline, signature);
    }

    function swapETH(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        uint deadline,
        bytes calldata signature,
        bytes calldata permitData
    ) external payable onlyOwner {
        _execPermit(token, permitData);
        _swapETH(owner, token, amountIn, amountOut, deadline, signature);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function nonces(address owner) public view override(NoncesUpgradeable, IEntry) returns (uint) {
        return super.nonces(owner);
    }

    function feeTo() external view returns (address) {
        return super.owner();
    }

    function withdraw(uint amount) external {
        payable(owner()).transfer(amount);
    }

    function withdraw(address token, uint amount) external {
        IERC20(token).transfer(owner(), amount);
    }

    function _swapETH(address owner, address token, uint amountIn, uint amountOut, uint deadline, bytes calldata signature) internal {
        _checkSwap(owner, token, amountIn, amountOut, deadline, signature);
        IERC20(token).transferFrom(owner, address(this), amountIn);
        payable(owner).transfer(amountOut);
        emit SwapETH(owner, token, amountIn, amountOut);
    }

    // 执行ERC20的Permit
    function _execPermit(address token, bytes calldata permitData) internal {
        bytes4 selector = bytes4(permitData[0:32]);
        require(selector == ERC20_PERMIT_SELECTOR, 'permit selector no match');
        (bool success, ) = token.call(permitData);
        require(success, 'permit failure');
    }

    // 检查用户兑换承诺签名
    function _checkSwap(address owner, address token, uint amountIn, uint amountOut, uint deadline, bytes calldata signature) internal {
        require(block.timestamp < deadline, 'signature expired');
        bytes32 structHash = keccak256(abi.encode(SWAP_TYPEHASH, owner, token, amountIn, amountOut, _useNonce(owner), deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(signer == owner, 'invalid signer');
    }
}
