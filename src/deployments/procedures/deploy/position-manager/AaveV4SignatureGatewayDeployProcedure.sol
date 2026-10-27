// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';

/// @title AaveV4SignatureGatewayDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the SignatureGateway contract.
library AaveV4SignatureGatewayDeployProcedure {
  /// @notice Deploys a new SignatureGateway instance via CREATE2.
  /// @param owner The owner of the SignatureGateway.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed SignatureGateway contract.
  function deploySignatureGateway(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: abi.encodePacked(type(SignatureGateway).creationCode, abi.encode(owner))
      });
  }
}
