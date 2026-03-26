// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

import {WETHDeployProcedure} from 'tests/deployments/procedures/WETHDeployProcedure.sol';
import {TestnetERC20DeployProcedure} from 'tests/deployments/procedures/TestnetERC20DeployProcedure.sol';
import {TestTypes} from 'tests/utils/TestTypes.sol';

contract TestTokensBatch is WETHDeployProcedure, TestnetERC20DeployProcedure {
  TestTypes.TestTokensBatchReport internal _report;

  constructor(TestTypes.TestTokenInput[] memory inputs_) {
    _report.tokens = new address[](inputs_.length);
    _report.weth = _deployWETH();

    for (uint256 i; i < inputs_.length; i++) {
      TestTypes.TestTokenInput memory input = inputs_[i];
      address token = _deployTestnetERC20(input.name, input.symbol, input.decimals);
      _report.tokens[i] = token;
    }
  }

  function getReport() external view returns (TestTypes.TestTokensBatchReport memory) {
    return _report;
  }
}
