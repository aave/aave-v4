// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4AaveOracleDeployProcedure is AaveV4DeployProcedureBase {
  function _deployAaveOracle(uint8 decimals) internal returns (address) {
    require(decimals > 0, 'invalid oracle decimals');
    // AaveOracle must be deployed via create so deployer can call setSpoke after deployment
    return address(new AaveOracle({decimals_: decimals}));
  }
}
