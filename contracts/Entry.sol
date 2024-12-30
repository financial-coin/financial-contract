// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interfaces/IEntry.sol";
import "./interfaces/IFund.sol";

contract Entry is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    EIP712Upgradeable,
    NoncesUpgradeable,
    IEntry
{
    bytes32 private constant SWAP_TYPEHASH =
        keccak256(
            "SwapETH(address owner,address token,uint256 amountIn,uint256 amountOut,uint256 nonce)"
        );

    address[] public funds;
    mapping(address => uint) private indexes;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __EIP712_init_unchained("entry", "1");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    receive() external payable {}

    function indexOf(address fund) public view returns (uint) {
        require(
            indexes[fund] > 0 || (funds.length > 0 && funds[0] == fund),
            "not exist the fund"
        );
        return indexes[fund];
    }

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
        indexes[fund] = index;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function registerFund(
        address fund,
        bytes calldata data
    ) external returns (uint index) {
        require(fund != address(0), "invaild fund address");
        require(
            funds.length == 0 || (indexes[fund] == 0 && funds[0] != fund),
            "exist the fund"
        );
        IFund(fund).initialize(address(this), data);
        index = funds.length;
        indexes[fund] = index;
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
    ) external view returns (uint shares, uint value, uint cost) {
        return IFund(fund).getAccount(owner);
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

    function updateFundValue(
        address fund
    ) external onlyOwner returns (uint netValue) {
        return IFund(fund).updateValue();
    }

    function swapETH(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        bytes calldata signature
    ) external onlyOwner {
        bytes32 structHash = keccak256(
            abi.encode(
                SWAP_TYPEHASH,
                owner,
                token,
                amountIn,
                amountOut,
                _useNonce(owner)
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(owner == signer, "invalid signature");

        IERC20(token).transferFrom(owner, address(this), amountIn);
        payable(owner).transfer(amountOut);
        emit SwapETH(owner, token, amountIn, amountOut);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function nonces(
        address owner
    ) public view override(NoncesUpgradeable, IEntry) returns (uint) {
        return super.nonces(owner);
    }

    function withdraw(uint amount) external onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function withdraw(address token, uint amount) external onlyOwner {
        IERC20(token).transfer(msg.sender, amount);
    }
}
