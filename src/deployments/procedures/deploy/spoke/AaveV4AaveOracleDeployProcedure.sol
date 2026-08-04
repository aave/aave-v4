// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

/// @title AaveV4AaveOracleDeployProcedure
/// @author Aave Labs
/// @notice Deploys the AaveOracle contract.
contract AaveV4AaveOracleDeployProcedure is AaveV4DeployProcedureBase {
  /// @notice Deploys a new AaveOracle instance via CREATE.
  /// @param decimals The number of decimals for the oracle price feed.
  /// @return The address of the deployed AaveOracle contract.
  function _deployAaveOracle(uint8 decimals) internal returns (address) {
    require(decimals > 0, 'invalid oracle decimals');
    return address(new AaveOracle({decimals_: decimals, baseCurrency_: address(0)}));
  }
}
