// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';

/// @title AaveV4TreasurySpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the TreasurySpoke contract behind a transparent proxy.
contract AaveV4TreasurySpokeDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a Treasury Spoke instance via CREATE2 and sets up a transparent proxy.
  /// @param owner The owner of the proxy admin and the TreasurySpoke initializer.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed transparent proxy contract.
  function _deployTreasurySpoke(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    address implementation = Create2Utils.create2DeployIdempotent(
      salt,
      type(TreasurySpokeInstance).creationCode
    );
    return
      Create2Utils.proxify(
        salt,
        implementation,
        owner,
        abi.encodeCall(TreasurySpokeInstance.initialize, (owner))
      );
  }
}
