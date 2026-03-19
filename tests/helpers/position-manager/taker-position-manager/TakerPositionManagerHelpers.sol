// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/position-manager/taker-position-manager/EIP712Helpers.sol';
import {SetupHelpers} from 'tests/helpers/position-manager/taker-position-manager/SetupHelpers.sol';

/// @title TakerPositionManagerHelpers
/// @notice Aggregates all TakerPositionManager test helpers.
///
/// Inheritance tree:
///   TakerPositionManagerHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   └── SetupHelpers
///       └── SpokeHelpers
abstract contract TakerPositionManagerHelpers is EIP712Helpers, SetupHelpers {}
