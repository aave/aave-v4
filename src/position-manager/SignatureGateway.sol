// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.
contract SignatureGateway is
  ISignatureGateway,
  NoncesKeyed,
  Multicall,
  Rescuable,
  Ownable2Step,
  EIP712
{
  using SafeERC20 for IERC20;

  ISpoke internal immutable _spoke;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SUPPLY_TYPEHASH =
    // keccak256('Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xe85497eb293c001e8483fe105efadd1d50aa0dadfc0570b27058031dfceab2e6;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant WITHDRAW_TYPEHASH =
    // keccak256('Withdraw(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0x0bc73eb58cf4068a29b9593ef18c0d26b3b4453bd2155424a90cb26a22f41d7f;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant BORROW_TYPEHASH =
    // keccak256('Borrow(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xe248895a233688ba2a70b6f560472dbc27e35ece0d86914f7d43bf2f7df8025b;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant REPAY_TYPEHASH =
    // keccak256('Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xd23fe99a7aac398d03952a098faa8889259d062784bd80ea0f159e4af604c045;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    // keccak256('SetUsingAsCollateral(address spoke,uint256 reserveId,bool useAsCollateral,address onBehalfOf,uint256 nonce,uint256 deadline)')
    0xd4350e1f25ecd62a35b50e8cd1e00bc34331ae8c728ee4dbb69ecf1023daecf7;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    // keccak256('UpdateUserRiskPremium(address spoke,address user,uint256 nonce,uint256 deadline)')
    0xb41e132023782c9b02febf1b9b7fe98c4a73f57ebc63ba44cd71f6365ea09eaf;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    // keccak256('UpdateUserDynamicConfig(address spoke,address user,uint256 nonce,uint256 deadline)')
    0xba177b1f5b5e1e709f62c19f03c97988c57752ba561de58f383ebee4e8d0a71c;

  /// @dev Constructor.
  /// @param spoke_ The address of the connected spoke.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address spoke_, address initialOwner_) Ownable(initialOwner_) {
    require(spoke_ != address(0) && initialOwner_ != address(0), InvalidAddress());
    _spoke = ISpoke(spoke_);
  }

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(SUPPLY_TYPEHASH, address(_spoke), reserveId, amount, onBehalfOf, nonce, deadline)
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());
    _useCheckedNonce(onBehalfOf, nonce);

    (IERC20 underlying, address hub) = _getReserveData(reserveId);
    underlying.safeTransferFrom(onBehalfOf, address(this), amount);
    underlying.forceApprove(hub, amount);

    _spoke.supply(reserveId, amount, onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          address(_spoke),
          reserveId,
          amount,
          onBehalfOf,
          nonce,
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());
    _useCheckedNonce(onBehalfOf, nonce);

    (IERC20 underlying, ) = _getReserveData(reserveId);
    uint256 withdrawAmount = MathUtils.min(
      amount,
      _spoke.getUserSuppliedAssets(reserveId, onBehalfOf)
    );

    _spoke.withdraw(reserveId, withdrawAmount, onBehalfOf);
    underlying.safeTransfer(onBehalfOf, withdrawAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(BORROW_TYPEHASH, address(_spoke), reserveId, amount, onBehalfOf, nonce, deadline)
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());
    _useCheckedNonce(onBehalfOf, nonce);

    (IERC20 underlying, ) = _getReserveData(reserveId);

    _spoke.borrow(reserveId, amount, onBehalfOf);
    underlying.safeTransfer(onBehalfOf, amount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(REPAY_TYPEHASH, address(_spoke), reserveId, amount, onBehalfOf, nonce, deadline)
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());
    _useCheckedNonce(onBehalfOf, nonce);

    (IERC20 underlying, address hub) = _getReserveData(reserveId);
    uint256 repayAmount = MathUtils.min(amount, _spoke.getUserTotalDebt(reserveId, onBehalfOf));

    underlying.safeTransferFrom(onBehalfOf, address(this), repayAmount);
    underlying.forceApprove(hub, repayAmount);

    _spoke.repay(reserveId, repayAmount, onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    uint256 reserveId,
    bool useAsCollateral,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_TYPEHASH,
          address(_spoke),
          reserveId,
          useAsCollateral,
          onBehalfOf,
          nonce,
          deadline
        )
      )
    );
    require(SignatureChecker.isValidSignatureNow(onBehalfOf, hash, signature), InvalidSignature());
    _useCheckedNonce(onBehalfOf, nonce);

    _spoke.setUsingAsCollateral(reserveId, useAsCollateral, onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    address user,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(UPDATE_USER_RISK_PREMIUM_TYPEHASH, address(_spoke), user, nonce, deadline)
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, nonce);

    _spoke.updateUserRiskPremium(user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    address user,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    require(block.timestamp <= deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH, address(_spoke), user, nonce, deadline)
      )
    );
    require(SignatureChecker.isValidSignatureNow(user, hash, signature), InvalidSignature());
    _useCheckedNonce(user, nonce);

    _spoke.updateUserDynamicConfig(user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    try
      _spoke.setUserPositionManagerWithSig(address(this), user, approve, nonce, deadline, signature)
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
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

  /// @inheritdoc ISignatureGateway
  function renounceSelfAsUserPositionManager(address user) external onlyOwner {
    _spoke.renouncePositionManagerRole(user);
  }

  /// @inheritdoc ISignatureGateway
  function SPOKE() external view returns (address) {
    return address(_spoke);
  }

  /// @inheritdoc ISignatureGateway
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }

  /// @dev RescueGuardian is the owner of the contract.
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }

  /// @return The underlying asset for `reserveId` on connected spoke.
  /// @return The corresponding hub address.
  function _getReserveData(uint256 reserveId) internal view returns (IERC20, address) {
    ISpoke.Reserve memory reserveData = _spoke.getReserve(reserveId);
    require(reserveData.underlying != address(0), InvalidReserveId());
    return (IERC20(reserveData.underlying), address(reserveData.hub));
  }
}
