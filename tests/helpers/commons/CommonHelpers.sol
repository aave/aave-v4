// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AssertionHelpers} from 'tests/helpers/commons/AssertionHelpers.sol';
import {MathHelpers} from 'tests/helpers/commons/MathHelpers.sol';
import {ProxyHelpers} from 'tests/helpers/commons/ProxyHelpers.sol';
import {SetupHelpers} from 'tests/helpers/commons/SetupHelpers.sol';

/// @title CommonHelpers
/// @notice Aggregates all commons-level test helpers.
///
/// Inheritance tree:
///   CommonHelpers
///   ├── AssertionHelpers
///   │   └── Test
///   ├── MathHelpers
///   ├── SetupHelpers
///   │   └── Test
///   └── ProxyHelpers
abstract contract CommonHelpers is AssertionHelpers, MathHelpers, SetupHelpers, ProxyHelpers {}
