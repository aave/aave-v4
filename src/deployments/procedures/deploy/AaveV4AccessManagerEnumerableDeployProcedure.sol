// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

/// @title AaveV4AccessManagerEnumerableDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the AccessManagerEnumerable contract for access control.
library AaveV4AccessManagerEnumerableDeployProcedure {
  /// @notice Deploys a new AccessManagerEnumerable instance via CREATE2.
  /// @param admin The initial admin address for the access manager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed AccessManagerEnumerable contract.
  function deployAccessManagerEnumerable(address admin, bytes32 salt) internal returns (address) {
    require(admin != address(0), 'invalid admin');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(AccessManagerEnumerable).creationCode, abi.encode(admin))
      );
  }
}
