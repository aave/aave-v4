// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/spoke/EIP712Helpers.sol';
import {SpokeSetupHelpers} from 'tests/helpers/spoke/SpokeSetupHelpers.sol';

/// @title SpokeHelpers
/// @notice Aggregates all spoke-level test helpers.
///
/// Inheritance tree:
///   SpokeHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   └── SpokeSetupHelpers
///       ├── CheckedActions
///       │   └── SpokeMathHelpers
///       │       └── SpokeQueryHelpers
///       │           ├── HubMathHelpers
///       │           │   └── HubQueryHelpers
///       │           │       ├── CommonHelpers
///       │           │       └── HubConstants
///       │           ├── SpokeConstants
///       │           └── SpokeTypes
///       ├── SpokeConfigHelpers
///       │   └── SpokeAssertions
///       │       └── SpokeQueryHelpers (shared)
///       ├── SpokeMockHelpers
///       │   └── CommonHelpers (shared)
///       └── HubMockHelpers
///           ├── CommonHelpers (shared)
///           └── HubConstants (shared)
abstract contract SpokeHelpers is EIP712Helpers, SpokeSetupHelpers {}
