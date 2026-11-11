// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';

/// @title AaveV4TreasurySpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the canonical TreasurySpoke implementation.
contract AaveV4TreasurySpokeDeployProcedure {
  /// @notice Deploys the canonical TreasurySpoke implementation via CREATE2.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed TreasurySpoke implementation contract.
  function _deployTreasurySpokeImplementation(bytes32 salt) internal returns (address) {
    return
      Create2Utils.create2Deploy({salt: salt, bytecode: type(TreasurySpokeInstance).creationCode});
  }
}
