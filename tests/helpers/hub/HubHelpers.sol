// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {HubActions} from 'tests/helpers/hub/HubActions.sol';
import {HubAssertions} from 'tests/helpers/hub/HubAssertions.sol';
import {HubConfigHelpers} from 'tests/helpers/hub/HubConfigHelpers.sol';
import {HubConstants} from 'tests/helpers/hub/HubConstants.sol';
import {HubMockHelpers} from 'tests/helpers/hub/HubMockHelpers.sol';
import {HubQueryHelpers} from 'tests/helpers/hub/HubQueryHelpers.sol';
import {HubSetupHelpers} from 'tests/helpers/hub/HubSetupHelpers.sol';

/// @title HubHelpers
/// @notice Aggregates all hub-level test helpers.
/// Inherits: HubConfigHelpers > HubAssertions > HubQueryHelpers > CommonHelpers
///           HubSetupHelpers > HubQueryHelpers > CommonHelpers
///           HubMockHelpers > CommonHelpers
abstract contract HubHelpers is HubConfigHelpers, HubSetupHelpers, HubMockHelpers {}
