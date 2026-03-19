// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EIP712Helpers} from 'tests/helpers/tokenization-spoke/EIP712Helpers.sol';
import {Assertions} from 'tests/helpers/tokenization-spoke/Assertions.sol';
import {SetupHelpers} from 'tests/helpers/tokenization-spoke/SetupHelpers.sol';

/// @title TokenizationSpokeHelpers
/// @notice Aggregates all tokenization spoke test helpers.
///
/// Inheritance tree:
///   TokenizationSpokeHelpers
///   ├── EIP712Helpers
///   │   └── Test
///   ├── Assertions
///   │   └── SpokeHelpers
///   └── SetupHelpers
///       └── SpokeHelpers (shared)
abstract contract TokenizationSpokeHelpers is EIP712Helpers, Assertions, SetupHelpers {}
