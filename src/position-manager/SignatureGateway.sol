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
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';

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
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) Ownable(initialOwner_) {}

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    EIP712Types.Supply memory supplyParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= supplyParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SUPPLY_TYPEHASH,
          supplyParams.spoke,
          supplyParams.reserveId,
          supplyParams.amount,
          supplyParams.onBehalfOf,
          supplyParams.nonce,
          supplyParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(supplyParams.onBehalfOf, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(supplyParams.onBehalfOf, supplyParams.nonce);

    ISpoke _spoke = ISpoke(supplyParams.spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, supplyParams.reserveId);
    underlying.safeTransferFrom(supplyParams.onBehalfOf, address(this), supplyParams.amount);
    underlying.forceApprove(hub, supplyParams.amount);

    _spoke.supply(supplyParams.reserveId, supplyParams.amount, supplyParams.onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    EIP712Types.Withdraw memory withdrawParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= withdrawParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          WITHDRAW_TYPEHASH,
          withdrawParams.spoke,
          withdrawParams.reserveId,
          withdrawParams.amount,
          withdrawParams.onBehalfOf,
          withdrawParams.nonce,
          withdrawParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(withdrawParams.onBehalfOf, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(withdrawParams.onBehalfOf, withdrawParams.nonce);

    ISpoke _spoke = ISpoke(withdrawParams.spoke);
    (IERC20 underlying, ) = _getReserveData(_spoke, withdrawParams.reserveId);
    uint256 withdrawAmount = MathUtils.min(
      withdrawParams.amount,
      _spoke.getUserSuppliedAssets(withdrawParams.reserveId, withdrawParams.onBehalfOf)
    );

    _spoke.withdraw(withdrawParams.reserveId, withdrawAmount, withdrawParams.onBehalfOf);
    underlying.safeTransfer(withdrawParams.onBehalfOf, withdrawAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    EIP712Types.Borrow memory borrowParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= borrowParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          BORROW_TYPEHASH,
          borrowParams.spoke,
          borrowParams.reserveId,
          borrowParams.amount,
          borrowParams.onBehalfOf,
          borrowParams.nonce,
          borrowParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(borrowParams.onBehalfOf, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(borrowParams.onBehalfOf, borrowParams.nonce);

    ISpoke _spoke = ISpoke(borrowParams.spoke);
    (IERC20 underlying, ) = _getReserveData(_spoke, borrowParams.reserveId);

    _spoke.borrow(borrowParams.reserveId, borrowParams.amount, borrowParams.onBehalfOf);
    underlying.safeTransfer(borrowParams.onBehalfOf, borrowParams.amount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(EIP712Types.Repay memory repayParams, bytes calldata signature) external {
    require(block.timestamp <= repayParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          REPAY_TYPEHASH,
          repayParams.spoke,
          repayParams.reserveId,
          repayParams.amount,
          repayParams.onBehalfOf,
          repayParams.nonce,
          repayParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(repayParams.onBehalfOf, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(repayParams.onBehalfOf, repayParams.nonce);

    ISpoke _spoke = ISpoke(repayParams.spoke);
    (IERC20 underlying, address hub) = _getReserveData(_spoke, repayParams.reserveId);
    uint256 repayAmount = MathUtils.min(
      repayParams.amount,
      _spoke.getUserTotalDebt(repayParams.reserveId, repayParams.onBehalfOf)
    );

    underlying.safeTransferFrom(repayParams.onBehalfOf, address(this), repayAmount);
    underlying.forceApprove(hub, repayAmount);

    _spoke.repay(repayParams.reserveId, repayAmount, repayParams.onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    EIP712Types.SetUsingAsCollateral memory setUsingAsCollateralParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= setUsingAsCollateralParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          SET_USING_AS_COLLATERAL_TYPEHASH,
          setUsingAsCollateralParams.spoke,
          setUsingAsCollateralParams.reserveId,
          setUsingAsCollateralParams.useAsCollateral,
          setUsingAsCollateralParams.onBehalfOf,
          setUsingAsCollateralParams.nonce,
          setUsingAsCollateralParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(setUsingAsCollateralParams.onBehalfOf, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(setUsingAsCollateralParams.onBehalfOf, setUsingAsCollateralParams.nonce);

    ISpoke(setUsingAsCollateralParams.spoke).setUsingAsCollateral(
      setUsingAsCollateralParams.reserveId,
      setUsingAsCollateralParams.useAsCollateral,
      setUsingAsCollateralParams.onBehalfOf
    );
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    EIP712Types.UpdateUserRiskPremium memory updateRiskParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= updateRiskParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          UPDATE_USER_RISK_PREMIUM_TYPEHASH,
          updateRiskParams.spoke,
          updateRiskParams.user,
          updateRiskParams.nonce,
          updateRiskParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(updateRiskParams.user, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(updateRiskParams.user, updateRiskParams.nonce);

    ISpoke(updateRiskParams.spoke).updateUserRiskPremium(updateRiskParams.user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    EIP712Types.UpdateUserDynamicConfig memory updateUserConfigParams,
    bytes calldata signature
  ) external {
    require(block.timestamp <= updateUserConfigParams.deadline, InvalidSignature());
    bytes32 hash = _hashTypedData(
      keccak256(
        abi.encode(
          UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH,
          updateUserConfigParams.spoke,
          updateUserConfigParams.user,
          updateUserConfigParams.nonce,
          updateUserConfigParams.deadline
        )
      )
    );
    require(
      SignatureChecker.isValidSignatureNow(updateUserConfigParams.user, hash, signature),
      InvalidSignature()
    );
    _useCheckedNonce(updateUserConfigParams.user, updateUserConfigParams.nonce);

    ISpoke(updateUserConfigParams.spoke).updateUserDynamicConfig(updateUserConfigParams.user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    try
      ISpoke(spoke).setUserPositionManagerWithSig(
        address(this),
        user,
        approve,
        nonce,
        deadline,
        signature
      )
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function permitReserve(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external {
    (IERC20 underlying, ) = _getReserveData(ISpoke(spoke), reserveId);
    try
      IERC20Permit(address(underlying)).permit({
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function renounceSelfAsUserPositionManager(address spoke, address user) external onlyOwner {
    ISpoke(spoke).renouncePositionManagerRole(user);
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

  /// @return The underlying asset for `reserveId` on the given spoke.
  /// @return The corresponding hub address.
  function _getReserveData(
    ISpoke spoke,
    uint256 reserveId
  ) internal view returns (IERC20, address) {
    ISpoke.Reserve memory reserveData = spoke.getReserve(reserveId);
    return (IERC20(reserveData.underlying), address(reserveData.hub));
  }
}
