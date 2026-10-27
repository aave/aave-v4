// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';

/// @title AaveV4TreasurySpokeDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the TreasurySpoke contract behind a transparent proxy.
library AaveV4TreasurySpokeDeployProcedure {
  /// @notice Deploys a Treasury Spoke instance via CREATE2 and sets up a transparent proxy.
  /// @param owner The owner of the proxy admin and the TreasurySpoke initializer.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed transparent proxy contract.
  function deployTreasurySpoke(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    address implementation = Create2Utils.create2Deploy(
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
