// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfigHelpers} from 'tests/helpers/hub/ConfigHelpers.sol';
import {MockHelpers} from 'tests/helpers/hub/MockHelpers.sol';
import {SetupHelpers} from 'tests/helpers/hub/SetupHelpers.sol';

/// @title HubHelpers
/// @notice Aggregates all hub-level test helpers.
///
/// Inheritance tree:
///   HubHelpers
///   ├── ConfigHelpers
///   │   └── Assertions
///   │       └── QueryHelpers
///   │           ├── CommonHelpers
///   │           ├── Constants
///   │           └── Types
///   ├── SetupHelpers
///   │   └── MathHelpers
///   │       └── QueryHelpers (shared)
///   └── MockHelpers
///       ├── CommonHelpers (shared)
///       └── Constants (shared)
abstract contract HubHelpers is ConfigHelpers, SetupHelpers, MockHelpers {}
