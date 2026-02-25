// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubConfigHelpers} from 'tests/helpers/hub/HubConfigHelpers.sol';
import {HubMockHelpers} from 'tests/helpers/hub/HubMockHelpers.sol';
import {HubSetupHelpers} from 'tests/helpers/hub/HubSetupHelpers.sol';

/// @title HubHelpers
/// @notice Aggregates all hub-level test helpers.
///
/// Inheritance tree:
///   HubHelpers
///   ├── HubConfigHelpers
///   │   └── HubAssertions
///   │       └── HubQueryHelpers
///   │           ├── CommonHelpers
///   │           └── HubConstants
///   ├── HubSetupHelpers
///   │   └── HubMathHelpers
///   │       └── HubQueryHelpers (shared)
///   └── HubMockHelpers
///       ├── CommonHelpers (shared)
///       └── HubConstants (shared)
abstract contract HubHelpers is HubConfigHelpers, HubSetupHelpers, HubMockHelpers {}
