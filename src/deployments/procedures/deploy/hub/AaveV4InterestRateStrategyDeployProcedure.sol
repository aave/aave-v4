// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4InterestRateStrategyDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the AssetInterestRateStrategy contract for the Hub.
library AaveV4InterestRateStrategyDeployProcedure {
  /// @notice Deploys a new AssetInterestRateStrategy contract via CREATE2.
  /// @param hub The address of the Hub that the AssetInterestRateStrategy contract is linked to.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed AssetInterestRateStrategy contract.
  function deployInterestRateStrategy(address hub, bytes32 salt) internal returns (address) {
    require(hub != address(0), 'invalid hub');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(AssetInterestRateStrategy).creationCode, abi.encode(hub))
      );
  }
}
