// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TokenizationSpokeSetupHelpers} from 'tests/helpers/tokenization-spoke/TokenizationSpokeSetupHelpers.sol';

/// @title TokenizationSpokeHelpers
/// @notice Aggregates all tokenization spoke test helpers.
///
/// Inheritance tree:
///   TokenizationSpokeHelpers
///   └── TokenizationSpokeSetupHelpers
///       └── SetupHelpers
///           └── Test
abstract contract TokenizationSpokeHelpers is TokenizationSpokeSetupHelpers {}
