// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';

/// @title AaveV4NativeTokenGatewayDeployProcedure
/// @author Aave Labs
/// @notice Deploys the NativeTokenGateway contract.
contract AaveV4NativeTokenGatewayDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new NativeTokenGateway instance via CREATE2.
  /// @param nativeWrapper The address of the native wrapper token (e.g. WETH).
  /// @param owner The owner of the NativeTokenGateway.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed NativeTokenGateway contract.
  function _deployNativeTokenGateway(
    address nativeWrapper,
    address owner,
    bytes32 salt
  ) internal returns (address) {
    require(nativeWrapper != address(0), 'invalid native wrapper');
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2DeployIdempotent({
        salt: salt,
        bytecode: abi.encodePacked(
          type(NativeTokenGateway).creationCode,
          abi.encode(nativeWrapper, owner)
        )
      });
  }
}
