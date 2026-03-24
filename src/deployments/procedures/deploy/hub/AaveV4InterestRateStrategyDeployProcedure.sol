// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

contract AaveV4InterestRateStrategyDeployProcedure is AaveV4DeployProcedureBase {
  function _deployInterestRateStrategy(address hub, bytes32 salt) internal returns (address) {
    require(hub != address(0), 'invalid hub');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(AssetInterestRateStrategy).creationCode, abi.encode(hub))
      );
  }
}
