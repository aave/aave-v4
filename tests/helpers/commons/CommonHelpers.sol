// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {MathHelpers} from 'tests/helpers/commons/MathHelpers.sol';
import {ProxyHelpers} from 'tests/helpers/commons/ProxyHelpers.sol';
import {SetupHelpers} from 'tests/helpers/commons/SetupHelpers.sol';

/// @title CommonHelpers
/// @notice Aggregates all commons-level test helpers.
///
/// Inheritance tree:
///   CommonHelpers
///   ├── MathHelpers
///   ├── SetupHelpers
///   │   └── Test
///   └── ProxyHelpers
abstract contract CommonHelpers is MathHelpers, SetupHelpers, ProxyHelpers {}
