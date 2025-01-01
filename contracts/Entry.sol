// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
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
            "SwapETH(address owner,address token,uint256 amountIn,uint256 amountOut,uint256 nonce,uint256 deadline)"
        );

    address[] public funds;
    mapping(address => address) public getFundToken;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __EIP712_init_unchained("entry", "1");
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    receive() external payable {}

    function fundsLength() external view returns (uint) {
        return funds.length;
    }

    function createFund(
        bytes memory code
    ) external onlyOwner returns (uint index, address fund) {
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

    function registerFund(address fund) external returns (uint index) {
        address token = IFund(fund).initialize();
        require(token != address(0), "invaild token address");
        require(getFundToken[fund] == address(0), "exist the fund");
        index = funds.length;
        getFundToken[fund] = token;
        funds.push(fund);

        emit FundCreated(index, fund);
    }

    function getFundProperty(
        address fund
    ) external view returns (IFund.Property memory) {
        return IFund(fund).getProperty();
    }

    function getFundAccount(
        address fund,
        address owner
    ) external view returns (uint shares, uint value, uint cost) {
        return IFund(fund).getAccount(owner);
    }

    function setFundMaxAPR(address fund, uint newAPR) external onlyOwner {
        IFund(fund).setMaxAPR(newAPR);
    }

    function buyFund(
        address fund,
        address to,
        address token,
        uint amount,
        uint256 deadline,
        bytes memory permit
    ) external returns (uint shares, uint value) {
        _execPermit(token, amount, deadline, permit);
        IERC20(token).transferFrom(msg.sender, fund, amount);
        return IFund(fund).mint(to);
    }

    function buyFund(
        address fund,
        address to,
        address token,
        uint amount
    ) external returns (uint shares, uint value) {
        IERC20(token).transferFrom(msg.sender, fund, amount);
        return IFund(fund).mint(to);
    }

    function buyFund(
        address fund,
        address to
    ) external payable returns (uint shares, uint value) {
        return IFund(fund).mint{value: msg.value}(to);
    }

    function redeemFund(
        address fund,
        address to,
        uint shares
    ) external returns (uint amount) {
        return IFund(fund).burn(msg.sender, to, shares);
    }

    function updateFundValue(
        address fund,
        bytes calldata data
    ) external payable onlyOwner returns (uint value) {
        return IFund(fund).updateValue{value: msg.value}(data);
    }

    function swapETH(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        uint deadline,
        bytes memory permit
    ) external onlyOwner {
        _checkSwapPermit(owner, token, amountIn, amountOut, deadline, permit);
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

    function feeTo() external view returns (address) {
        return super.owner();
    }

    function withdrawTo(address to, uint amount) external onlyOwner {
        payable(to).transfer(amount);
    }

    function withdrawTo(
        address to,
        address token,
        uint amount
    ) external onlyOwner {
        IERC20(token).transfer(to, amount);
    }

    // 执行ERC20的Permit
    function _execPermit(
        address token,
        uint amount,
        uint deadline,
        bytes memory permit
    ) internal {
        assert(permit.length == 65);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := mload(add(permit, 0x20))
            s := mload(add(permit, 0x40))
            v := byte(0, mload(add(permit, 0x60)))
        }
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
    }

    // 执行ERC20的Permit
    function _execPermit(
        address token,
        uint amount,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20Permit(token).permit(
            msg.sender,
            address(this),
            amount,
            deadline,
            v,
            r,
            s
        );
    }

    // 检查用户兑换承诺签名
    function _checkSwapPermit(
        address owner,
        address token,
        uint amountIn,
        uint amountOut,
        uint deadline,
        bytes memory permit
    ) internal {
        require(block.timestamp < deadline, "permit expired");
        bytes32 structHash = keccak256(
            abi.encode(
                SWAP_TYPEHASH,
                owner,
                token,
                amountIn,
                amountOut,
                _useNonce(owner),
                deadline
            )
        );
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, permit);
        require(signer == owner, "invalid permit signer");
    }
}
