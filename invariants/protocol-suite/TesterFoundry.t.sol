// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Contracts
import {StdInvariant} from 'forge-std/StdInvariant.sol';
import {Invariants} from './Invariants.t.sol';
import {Setup} from './Setup.t.sol';

/// @title TesterFoundry
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract TesterFoundry is Invariants, Setup, StdInvariant {
  /// @dev Foundry compatibility faster setup debugging
  function setUp() public {
    // Deploy protocol contracts and protocol actors
    _setUp();

    // Set the target contract
    targetContract(address(this));

    // Exclude target selectors
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = this.checkPostConditions.selector;

    excludeSelector(FuzzSelector({addr: address(this), selectors: selectors}));

    // Set the target senders
    targetSender(USER1);
    targetSender(USER2);
    targetSender(USER3);
  }
}
