// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Test Contracts
import {HubInvariantsSpec} from './specs/HubInvariantsSpec.t.sol';
import {HubPostconditionsSpec} from './specs/HubPostconditionsSpec.t.sol';

/// @title SpecAggregator
/// @notice Helper contract to aggregate all spec contracts, inherited in BaseHooks
/// @dev inherits HubInvariantsSpec, HubPostconditionsSpec
abstract contract SpecAggregator is HubInvariantsSpec, HubPostconditionsSpec {}
