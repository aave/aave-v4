// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {Multicall} from 'src/misc/Multicall.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {ISignatureGateway} from 'src/interfaces/ISignatureGateway.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ISpoke} from 'src/interfaces/ISpoke.sol';

contract SignatureGateway is EIP712, Multicall, Ownable2Step, ISignatureGateway {
  using SafeERC20 for IERC20;

  // @inheritdoc ISignatureGateway
  ISpoke public immutable SPOKE;

  // @inheritdoc ISignatureGateway
  bytes32 public constant SUPPLY_TYPEHASH =
    0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6; // keccak256('Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant WITHDRAW_TYPEHASH =
    0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f; // keccak256('Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant BORROW_TYPEHASH =
    0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b; // keccak256('Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant REPAY_TYPEHASH =
    0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045; // keccak256('Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    0xd4350e1f25ecd62a35b50e8cd1e00bc34331ae8c728ee4dbb69ecf1023daecf7; // keccak256('SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    0xb41e132023782c9b02febf1b9b7fe98c4a73f57ebc63ba44cd71f6365ea09eaf; // keccak256('UpdateUserRiskPremium(address spoke,address user,uint256 nonce,uint256 deadline)')
  // @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    0xba177b1f5b5e1e709f62c19f03c97988c57752ba561de58f383ebee4e8d0a71c; // keccak256('UpdateUserDynamicConfig(address spoke,address user,uint256 nonce,uint256 deadline)')

  mapping(address user => uint256 nonce) internal _nonces;

  constructor(address spoke_, address initialOwner_) Ownable(initialOwner_) {
    assert(spoke_ != address(0) && initialOwner_ != address(0));
    SPOKE = ISpoke(spoke_);
  }

  // @inheritdoc ISignatureGateway
  function supplyWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SUPPLY_TYPEHASH,
          address(SPOKE),
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());

    (IERC20 underlying, address hub) = _getReserveData(reserveId);
    underlying.safeTransferFrom(onBehalfOf, address(this), amount);
    underlying.forceApprove(hub, amount);

    SPOKE.supply(reserveId, amount, onBehalfOf);
  }

  // @inheritdoc ISignatureGateway
  function withdrawWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          address(SPOKE),
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());

    (IERC20 underlying, ) = _getReserveData(reserveId);
    amount = MathUtils.min(amount, SPOKE.getUserSuppliedAmount(reserveId, onBehalfOf));

    SPOKE.withdraw(reserveId, amount, onBehalfOf);
    underlying.safeTransfer(onBehalfOf, amount);
  }

  // @inheritdoc ISignatureGateway
  function borrowWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          BORROW_TYPEHASH,
          address(SPOKE),
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());

    (IERC20 underlying, ) = _getReserveData(reserveId);

    SPOKE.borrow(reserveId, amount, onBehalfOf);
    underlying.safeTransfer(onBehalfOf, amount);
  }

  // @inheritdoc ISignatureGateway
  function repayWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          REPAY_TYPEHASH,
          address(SPOKE),
          reserveId,
          amount,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());

    (IERC20 underlying, address hub) = _getReserveData(reserveId);
    amount = MathUtils.min(amount, SPOKE.getUserTotalDebt(reserveId, onBehalfOf));

    underlying.safeTransferFrom(onBehalfOf, address(this), amount);
    underlying.forceApprove(hub, amount);

    SPOKE.repay(reserveId, amount, onBehalfOf);
  }

  // @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    uint256 reserveId,
    bool useAsCollateral,
    address onBehalfOf,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_TYPEHASH,
          address(SPOKE),
          reserveId,
          useAsCollateral,
          onBehalfOf,
          _useNonce(onBehalfOf),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());

    SPOKE.setUsingAsCollateral(reserveId, useAsCollateral, onBehalfOf);
  }

  // @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    address user,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          UPDATE_USER_RISK_PREMIUM_TYPEHASH,
          address(SPOKE),
          user,
          _useNonce(user),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());

    SPOKE.updateUserRiskPremium(user);
  }

  // @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    address user,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
          address(SPOKE),
          user,
          _useNonce(user),
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());

    SPOKE.updateUserDynamicConfig(user);
  }

  // @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 deadline,
    bytes calldata signature
  ) external {
    SPOKE.setUserPositionManagerWithSig(address(this), user, approve, deadline, signature);
  }

  // @inheritdoc ISignatureGateway
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    (IERC20 underlying, ) = _getReserveData(reserveId);
    try
      IERC20Permit(address(underlying)).permit({
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: v,
        r: r,
        s: s
      })
    {} catch {}
  }

  // @inheritdoc ISignatureGateway
  function renounceSelfAsUserPositionManager(address user) external onlyOwner {
    SPOKE.renouncePositionManagerRole(user);
  }

  // @inheritdoc ISignatureGateway
  function useNonce() external {
    _useNonce(msg.sender);
  }

  // @inheritdoc ISignatureGateway
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  // @inheritdoc ISignatureGateway
  function nonces(address user) external view returns (uint256) {
    return _nonces[user];
  }

  function _useNonce(address user) internal returns (uint256) {
    unchecked {
      return _nonces[user]++;
    }
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }

  function _getReserveData(uint256 reserveId) internal view returns (IERC20, address) {
    DataTypes.Reserve memory reserveData = SPOKE.getReserve(reserveId);
    require(reserveData.underlying != address(0), InvalidReserveId());
    return (IERC20(reserveData.underlying), address(reserveData.hub));
  }
}
