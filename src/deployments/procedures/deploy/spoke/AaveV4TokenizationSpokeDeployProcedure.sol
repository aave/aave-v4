// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title AaveV4TokenizationSpokeDeployProcedure
/// @author Aave Labs
/// @notice Deploys the canonical TokenizationSpoke implementation.
contract AaveV4TokenizationSpokeDeployProcedure {
  /// @notice Deploys the canonical TokenizationSpokeInstance implementation via CREATE2.
  /// @dev The implementation holds no Hub or asset specific state and is shared by every TokenizationSpoke proxy.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed TokenizationSpoke implementation contract.
  function _deployTokenizationSpokeImplementation(bytes32 salt) internal returns (address) {
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: type(TokenizationSpokeInstance).creationCode
      });
  }
}
