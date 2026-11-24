// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPolicyGate} from 'src/spoke/interfaces/IPolicyGate.sol';
import {IEligibilityRegistry} from 'src/spoke/interfaces/IEligibilityRegistry.sol';

/// @title IEligibilityPolicyGate
/// @author Aave Labs
/// @notice Interface for the configurable policy gate of a permissioned Spoke.
interface IEligibilityPolicyGate is IPolicyGate {
  /// @notice Configuration of the policy gate.
  /// @param registry The registry read for statuses and reserve managers, or zero.
  /// @param onlyCaller The only caller allowed on position actions, or zero.
  /// @param onlyLiquidator The only liquidator allowed, or zero for open liquidations.
  /// @param allowOwnerRepay Whether the owner's own repay is always allowed.
  /// @param allowFrozenExit Whether frozen users can withdraw and disable collateral.
  struct Config {
    address registry;
    address onlyCaller;
    address onlyLiquidator;
    bool allowOwnerRepay;
    bool allowFrozenExit;
  }

  /// @notice Thrown when the registry, the only caller and the only liquidator are all zero.
  error InvalidConfig();

  /// @notice Returns the registry read for statuses and reserve managers. Zero if not used.
  function REGISTRY() external view returns (IEligibilityRegistry);

  /// @notice Returns the only caller allowed on position actions. Zero if not used.
  function ONLY_CALLER() external view returns (address);

  /// @notice Returns the only liquidator allowed. Zero for open liquidations.
  function ONLY_LIQUIDATOR() external view returns (address);

  /// @notice Returns whether the owner's own repay is always allowed.
  function ALLOW_OWNER_REPAY() external view returns (bool);

  /// @notice Returns whether frozen users can withdraw and disable collateral.
  function ALLOW_FROZEN_EXIT() external view returns (bool);
}
