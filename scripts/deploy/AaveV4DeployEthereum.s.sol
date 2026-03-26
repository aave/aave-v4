// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @notice Ethereum deploy script with hardcoded inputs for local testing.
abstract contract AaveV4DeployEthereum is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('ethereum') {}

  function _expectedChainId() internal pure virtual override returns (uint256) {
    return 1;
  }
}
