// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/position-manager/config-position-manager/EIP712Helpers.sol';
import {SetupHelpers} from 'tests/helpers/position-manager/config-position-manager/SetupHelpers.sol';

/// @title ConfigPositionManagerHelpers
/// @notice Aggregates all ConfigPositionManager test helpers.
///
/// Inheritance tree:
///   ConfigPositionManagerHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   └── SetupHelpers
///       └── SpokeHelpers
abstract contract ConfigPositionManagerHelpers is EIP712Helpers, SetupHelpers {}
