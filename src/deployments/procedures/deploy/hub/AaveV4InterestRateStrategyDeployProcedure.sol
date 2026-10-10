// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4InterestRateStrategyDeployProcedure
/// @author Aave Labs
/// @notice Deploys the AssetInterestRateStrategy contract for the Hub.
contract AaveV4InterestRateStrategyDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new AssetInterestRateStrategy contract via CREATE2.
  /// @param hub The address of the Hub that the AssetInterestRateStrategy contract is linked to.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed AssetInterestRateStrategy contract.
  function _deployInterestRateStrategy(address hub, bytes32 salt) internal returns (address) {
    require(hub != address(0), 'invalid hub');
    return
      Create2Utils.create2DeployIdempotent(
        salt,
        abi.encodePacked(type(AssetInterestRateStrategy).creationCode, abi.encode(hub))
      );
  }
}
