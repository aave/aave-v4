// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';

contract AaveV4InterestRateStrategyDeployProcedureWrapper {
  bool public IS_TEST = true;

  function deployInterestRateStrategy(address hub, bytes32 salt) external returns (address) {
    return AaveV4InterestRateStrategyDeployProcedure.deployInterestRateStrategy(hub, salt);
  }
}
