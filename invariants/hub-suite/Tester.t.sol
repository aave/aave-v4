// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Invariants} from './Invariants.t.sol';
import {Setup} from './Setup.t.sol';

/// @title Tester
/// @notice Entry point for hub invariant testing
contract Tester is Invariants, Setup {
  constructor() payable {
    setUp();
  }

  function setUp() internal {
    _setUp();
  }
}
