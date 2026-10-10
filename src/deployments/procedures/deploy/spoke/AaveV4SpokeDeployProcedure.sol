// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';

/// @title AaveV4SpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys an upgradeable Spoke instance behind a transparent proxy.
contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a Spoke implementation via CREATE2 and sets up a transparent proxy.
  /// @param proxyAdminOwner The owner of the proxy admin contract.
  /// @param authority The access control authority address used to initialize the Spoke.
  /// @param oracle The oracle address used by the Spoke instance.
  /// @param spokeBytecode The creation bytecode of the Spoke implementation.
  /// @param maxUserReservesLimit The maximum number of reserves a single user can interact with.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return spokeProxy The address of the deployed transparent proxy.
  /// @return spokeImplementation The address of the deployed Spoke implementation contract.
  function _deployUpgradeableSpokeInstance(
    address proxyAdminOwner,
    address authority,
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address spokeProxy, address spokeImplementation) {
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(oracle != address(0), 'invalid oracle');
    require(maxUserReservesLimit > 0, 'invalid max user reserves limit');
    spokeImplementation = Create2Utils.create2DeployIdempotent({
      salt: salt,
      bytecode: _getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
    });
    spokeProxy = Create2Utils.proxify({
      salt: salt,
      logic: spokeImplementation,
      initialOwner: proxyAdminOwner,
      data: abi.encodeCall(ISpokeInstance.initialize, (authority))
    });
    return (spokeProxy, spokeImplementation);
  }

  /// @notice Constructs the full init code for a Spoke instance by appending constructor arguments.
  /// @param spokeBytecode The creation bytecode of the Spoke implementation.
  /// @param oracle The oracle address to encode as a constructor argument.
  /// @param maxUserReservesLimit The maximum number of user reserves to encode as a constructor argument.
  /// @return The complete init code with encoded constructor arguments.
  function _getSpokeInstanceInitCode(
    bytes memory spokeBytecode,
    address oracle,
    uint16 maxUserReservesLimit
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(spokeBytecode, abi.encode(oracle, maxUserReservesLimit));
  }
}
