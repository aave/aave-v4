// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/spoke/EIP712Helpers.sol';
import {SetupHelpers} from 'tests/helpers/spoke/SetupHelpers.sol';

/// @title SpokeHelpers
/// @notice Aggregates all spoke-level test helpers.
///
/// Inheritance tree:
///   SpokeHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   └── SetupHelpers
///       ├── CheckedActions
///       │   └── MathHelpers
///       │       └── QueryHelpers
///       │           ├── HubHelpers
///       │           ├── Constants
///       │           └── Types
///       ├── ConfigHelpers
///       │   └── Assertions
///       │       └── QueryHelpers (shared)
///       └── MockHelpers
///           └── CommonHelpers
abstract contract SpokeHelpers is EIP712Helpers, SetupHelpers {}
