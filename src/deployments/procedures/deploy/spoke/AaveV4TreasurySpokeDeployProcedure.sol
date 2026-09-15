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
  /// @param hub The hub connected with Treasury Spoke, encoded to prevent the CREATE2 deployment from failing.
  /// @return The address of the deployed transparent proxy contract
  function _deployTreasurySpoke(address owner, bytes32 salt, address hub) internal returns (address) {
    require(owner != address(0), 'invalid owner');

    bytes memory bytecode = abi.encodePacked(
      type(TreasurySpokeInstance).creationCode,
      /* The hub must be encoded because it is an argument in the TreasurySpoke constructor, 
      constructor arguments can alter the final bytecode causing the 
      CREATE2 deterministic deployement to fail, so encoding ensures the deploy succeds */
      abi.encode(hub)
    );

    address implementation = Create2Utils.create2Deploy(
      salt,
      bytecode
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
