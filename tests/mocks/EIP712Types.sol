// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title EIP712Types library
/// @author Aave Labs
/// @notice Defines type structs used in EIP712-typed signatures.
/// @dev Consolidated types to generate JsonBindings.sol using `forge bind-json` for vm.eip712* cheat-codes.
library EIP712Types {
  /// @dev Spoke Intents
  struct SetUserPositionManagers {
    address onBehalfOf;
    PositionManagerUpdate[] updates;
    uint256 nonce;
    uint256 deadline;
  }

  struct PositionManagerUpdate {
    address positionManager;
    bool approve;
  }

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }

  /// @dev SignatureGateway Intents
  struct Supply {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Withdraw {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Borrow {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct Repay {
    address spoke;
    uint256 reserveId;
    uint256 amount;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct SetUsingAsCollateral {
    address spoke;
    uint256 reserveId;
    bool useAsCollateral;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct UpdateUserRiskPremium {
    address spoke;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct UpdateUserDynamicConfig {
    address spoke;
    address onBehalfOf;
    uint256 nonce;
    uint256 deadline;
  }

  struct WithdrawPermit {
    address spoke;
    uint256 reserveId;
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  struct BorrowPermit {
    address spoke;
    uint256 reserveId;
    address owner;
    address spender;
    uint256 amount;
    uint256 nonce;
    uint256 deadline;
  }

  /// @dev ConfigPositionManager Intents
  struct SetGlobalPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  struct SetCanSetUsingAsCollateralPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  struct SetCanUpdateUserRiskPremiumPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  struct SetCanUpdateUserDynamicConfigPermissionPermit {
    address spoke;
    address delegator;
    address delegatee;
    bool status;
    uint256 nonce;
    uint256 deadline;
  }

  /// @dev TokenizationSpoke Intents
  struct TokenizedDeposit {
    address depositor;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct TokenizedMint {
    address depositor;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct TokenizedWithdraw {
    address owner;
    uint256 assets;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }

  struct TokenizedRedeem {
    address owner;
    uint256 shares;
    address receiver;
    uint256 nonce;
    uint256 deadline;
  }
}
