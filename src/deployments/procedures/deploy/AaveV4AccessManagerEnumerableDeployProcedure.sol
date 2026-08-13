// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

/// @title AaveV4AccessManagerEnumerableDeployProcedure
/// @author Aave Labs
/// @notice Deploys the AccessManagerEnumerable contract for access control.
contract AaveV4AccessManagerEnumerableDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new AccessManagerEnumerable instance via CREATE2.
  /// @param admin The initial admin address for the access manager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed AccessManagerEnumerable contract.
  function _deployAccessManagerEnumerable(address admin, bytes32 salt) internal returns (address) {
    require(admin != address(0), 'invalid admin');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(BytecodeHelper.getAccessManagerEnumerableBytecode(), abi.encode(admin))
      );
  }
}
