// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';

/// @title AaveV4SpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the transparent proxy of a Spoke instance.
/// @dev The implementation is deployed in its own transaction (see `AaveV4DeployBase.deploySpokeImplementation`)
///      so that each step fits on chains with a per-transaction gas cap. The implementation must be the CREATE2
///      deployment of `spokeInitCodeHash` under `salt`, which pins its exact code.
contract AaveV4SpokeDeployProcedure {
  /// @notice Deploys a transparent proxy for an already deployed Spoke implementation via CREATE2.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the Spoke.
  /// @param spokeImplementation The address of the deployed Spoke implementation.
  /// @param spokeInitCodeHash The keccak256 hash of the Spoke implementation creation bytecode, constructor
  ///        arguments included.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed transparent proxy.
  function _deploySpokeProxy(
    address proxyAdminOwner,
    address authority,
    address spokeImplementation,
    bytes32 spokeInitCodeHash,
    bytes32 salt
  ) internal returns (address) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(
      spokeImplementation == Create2Utils.computeCreate2Address(salt, spokeInitCodeHash) &&
        Create2Utils.isContractDeployed(spokeImplementation),
      'invalid spoke implementation'
    );
    return
      Create2Utils.proxify({
        salt: salt,
        logic: spokeImplementation,
        initialOwner: proxyAdminOwner,
        data: abi.encodeCall(ISpokeInstance.initialize, (authority))
      });
  }
}
