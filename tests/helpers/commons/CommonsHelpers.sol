// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {MathHelpers} from 'tests/helpers/commons/MathHelpers.sol';
import {ProxyHelpers} from 'tests/helpers/commons/ProxyHelpers.sol';
import {SetupHelpers} from 'tests/helpers/commons/SetupHelpers.sol';

/// @title CommonsHelpers
/// @notice Aggregates all commons-level test helpers.
abstract contract CommonsHelpers is MathHelpers, SetupHelpers, ProxyHelpers {}
