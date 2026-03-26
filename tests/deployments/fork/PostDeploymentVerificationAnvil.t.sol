// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployAnvil} from 'scripts/deploy/examples/AaveV4DeployAnvil.s.sol';

/// @title PostDeploymentVerificationAnvil
/// @notice Anvil-specific post-deployment verification test.
///         Extends the deploy script directly to read inputs and output directory — single source of truth.
///
/// Usage:
///   1. Deploy to anvil (see AaveV4DeployAnvil.s.sol)
///   2. Set REPORT_FILE, DEPLOYER in this test file
///   3. Run: forge test --mc PostDeploymentVerificationAnvil
contract PostDeploymentVerificationAnvil is PostDeploymentVerificationBase, AaveV4DeployAnvil {
  // TODO: Update these constants to the test deployment params
  string public constant REPORT_FILE = '1773975754-31337-anvil-deploy.json';
  address public constant DEPLOYER = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8; // anvil account

  function setUp() public override(PostDeploymentVerificationBase) {
    vm.skip(true, 'Anvil post-deployment test');
    _reportFile = string.concat(OUTPUT_DIR, REPORT_FILE);
    _deployer = DEPLOYER;
    PostDeploymentVerificationBase.setUp();
    vm.createSelectFork('anvil');
  }

  function _getSanitizedDeployInputs() internal override returns (FullDeployInputs memory) {
    FullDeployInputs memory rawInputs = _getDeployInputs();
    return _loadWarningsAndSanitizeInputs(rawInputs, _deployer);
  }
}
