// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Invariants} from './Invariants.t.sol';
import {Setup} from './Setup.t.sol';

/// @title Tester
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract Tester is Invariants, Setup {
  constructor() payable {
    // Deploy protocol contracts and protocol actors
    setUp();
  }

  /// @dev Foundry compatibility faster setup debugging
  function setUp() internal {
    // Deploy protocol contracts and protocol actors
    _setUp();
  }
}
