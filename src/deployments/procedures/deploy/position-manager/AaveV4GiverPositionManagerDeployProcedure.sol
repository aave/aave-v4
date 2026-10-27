// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {GiverPositionManager} from 'src/position-manager/GiverPositionManager.sol';

/// @title AaveV4GiverPositionManagerDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the GiverPositionManager contract.
library AaveV4GiverPositionManagerDeployProcedure {
  /// @notice Deploys a new GiverPositionManager instance via CREATE2.
  /// @param owner The owner of the GiverPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed GiverPositionManager contract.
  function deployGiverPositionManager(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(type(GiverPositionManager).creationCode, abi.encode(owner))
      });
  }
}
