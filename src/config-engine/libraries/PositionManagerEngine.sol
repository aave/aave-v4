// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title PositionManagerEngine
/// @author Aave Labs
/// @notice Library containing position manager logic for AaveV4ConfigEngine.
library PositionManagerEngine {
  /// @notice Registers/deregisters Spokes on position managers.
  /// @param registrations The Spoke registrations to execute.
  function executePositionManagerSpokeRegistrations(
    IAaveV4ConfigEngine.SpokeRegistration[] calldata registrations
  ) external {
    uint256 length = registrations.length;
    for (uint256 i; i < length; ++i) {
      IPositionManagerBase(registrations[i].positionManager).registerSpoke(
        registrations[i].spoke,
        registrations[i].registered
      );
    }
  }

  /// @notice Renounces position manager roles for users on Spokes.
  /// @param renouncements The role renouncements to execute.
  function executePositionManagerRoleRenouncements(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] calldata renouncements
  ) external {
    uint256 length = renouncements.length;
    for (uint256 i; i < length; ++i) {
      IPositionManagerBase(renouncements[i].positionManager).renouncePositionManagerRole(
        renouncements[i].spoke,
        renouncements[i].user
      );
    }
  }
}
