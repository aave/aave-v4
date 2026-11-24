// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPolicyGate} from 'src/spoke/interfaces/IPolicyGate.sol';
import {IEligibilityPolicyGate} from 'src/spoke/interfaces/IEligibilityPolicyGate.sol';
import {IEligibilityRegistry} from 'src/spoke/interfaces/IEligibilityRegistry.sol';
import {AuthKind} from 'src/spoke/libraries/AuthKind.sol';

/// @title EligibilityPolicyGate
/// @author Aave Labs
/// @notice Configurable stateless policy gate. Each permissioned Spoke uses its own, configured with:
///   - `REGISTRY` (optional): statuses and reserve managers, e.g. Horizon KYC
///   - `ONLY_CALLER` (optional): the only caller allowed on position actions, e.g. CustodySync
///   - `ONLY_LIQUIDATOR` (optional): the only liquidator allowed
///   - `ALLOW_OWNER_REPAY`: whether the owner's own repay is always allowed
///   - `ALLOW_FROZEN_EXIT`: whether frozen users can withdraw and disable collateral
/// @dev Liquidations: only `ONLY_LIQUIDATOR` if set. Otherwise open, and a liquidator receiving
/// shares must be ACTIVE.
/// @dev Position actions, when a registry is set:
///   - position and reserve managers must be ACTIVE themselves
///   - reserve managers act whatever the user's status
///   - repay: any status
///   - supply, borrow, enable collateral: ACTIVE
///   - withdraw, disable collateral: ACTIVE or OFFBOARDED, FROZEN only if `ALLOW_FROZEN_EXIT`
contract EligibilityPolicyGate is IEligibilityPolicyGate {
  /// @inheritdoc IEligibilityPolicyGate
  IEligibilityRegistry public immutable REGISTRY;

  /// @inheritdoc IEligibilityPolicyGate
  address public immutable ONLY_CALLER;

  /// @inheritdoc IEligibilityPolicyGate
  address public immutable ONLY_LIQUIDATOR;

  /// @inheritdoc IEligibilityPolicyGate
  bool public immutable ALLOW_OWNER_REPAY;

  /// @inheritdoc IEligibilityPolicyGate
  bool public immutable ALLOW_FROZEN_EXIT;

  /// @dev Constructor.
  /// @param config The configuration of the policy gate.
  constructor(Config memory config) {
    require(
      config.registry != address(0) ||
        config.onlyCaller != address(0) ||
        config.onlyLiquidator != address(0),
      InvalidConfig()
    );
    REGISTRY = IEligibilityRegistry(config.registry);
    ONLY_CALLER = config.onlyCaller;
    ONLY_LIQUIDATOR = config.onlyLiquidator;
    ALLOW_OWNER_REPAY = config.allowOwnerRepay;
    ALLOW_FROZEN_EXIT = config.allowFrozenExit;
  }

  /// @inheritdoc IPolicyGate
  function isEligible(
    address caller,
    address user,
    bytes calldata data,
    uint8 auth
  ) external view returns (bool) {
    bytes4 selector = bytes4(data[0:4]);
    if (selector == ISpoke.liquidationCall.selector) {
      if (ONLY_LIQUIDATOR != address(0)) return caller == ONLY_LIQUIDATOR;
      // `receiveShares`, fifth argument of `liquidationCall`
      if (!_boolArg(data, 132)) return true;
      return address(REGISTRY) == address(0) || _isActive(caller);
    }
    if (selector == ISpoke.repay.selector && auth == AuthKind.OWNER && ALLOW_OWNER_REPAY) {
      return true;
    }
    if (ONLY_CALLER != address(0) && caller != ONLY_CALLER) return false;
    if (address(REGISTRY) == address(0)) return true;
    if (auth == AuthKind.RESERVE_MANAGER) return _isActive(caller);
    if (auth == AuthKind.POSITION_MANAGER && !_isActive(caller)) return false;
    if (selector == ISpoke.repay.selector) return true;

    IEligibilityRegistry.Status status = REGISTRY.getStatus(user);
    if (status == IEligibilityRegistry.Status.ACTIVE) return true;
    if (selector == ISpoke.supply.selector || selector == ISpoke.borrow.selector) return false;

    // `usingAsCollateral`, second argument of `setUsingAsCollateral`
    bool isExit = selector == ISpoke.withdraw.selector ||
      (selector == ISpoke.setUsingAsCollateral.selector && !_boolArg(data, 36));
    if (!isExit) return false;
    if (status == IEligibilityRegistry.Status.OFFBOARDED) return true;
    return status == IEligibilityRegistry.Status.FROZEN && ALLOW_FROZEN_EXIT;
  }

  /// @inheritdoc IPolicyGate
  function getReserveManagerActions(
    address account,
    uint256 reserveId
  ) external view returns (uint8) {
    if (address(REGISTRY) == address(0)) return 0;
    return
      REGISTRY.getReserveManagerActions({
        spoke: msg.sender,
        reserveId: reserveId,
        manager: account
      });
  }

  function _isActive(address account) internal view returns (bool) {
    return REGISTRY.getStatus(account) == IEligibilityRegistry.Status.ACTIVE;
  }

  /// @dev Reads the bool argument at byte `offset` of `data`.
  function _boolArg(bytes calldata data, uint256 offset) internal pure returns (bool) {
    return uint256(bytes32(data[offset:offset + 32])) != 0;
  }
}
