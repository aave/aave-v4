// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {CommonHelpers} from 'tests/helpers/commons/CommonHelpers.sol';
import {CheckedActions} from 'tests/helpers/spoke/CheckedActions.sol';
import {EIP712Helpers} from 'tests/helpers/spoke/EIP712Helpers.sol';
import {SpokeActions} from 'tests/helpers/spoke/SpokeActions.sol';
import {SpokeAssertions} from 'tests/helpers/spoke/SpokeAssertions.sol';
import {SpokeConfigHelpers} from 'tests/helpers/spoke/SpokeConfigHelpers.sol';
import {SpokeConstants} from 'tests/helpers/spoke/SpokeConstants.sol';
import {SpokeMockHelpers} from 'tests/helpers/spoke/SpokeMockHelpers.sol';
import {SpokeQueryHelpers} from 'tests/helpers/spoke/SpokeQueryHelpers.sol';
import {SpokeSetupHelpers} from 'tests/helpers/spoke/SpokeSetupHelpers.sol';

/// @title SpokeHelpers
/// @notice Aggregates all spoke-level test helpers.
/// Inherits: SpokeSetupHelpers > CheckedActions > SpokeQueryHelpers > HubQueryHelpers > CommonHelpers
///           SpokeSetupHelpers > SpokeConfigHelpers > SpokeAssertions > SpokeQueryHelpers
///           SpokeSetupHelpers > SpokeMockHelpers > CommonHelpers
///           SpokeSetupHelpers > HubMockHelpers > CommonHelpers
///           EIP712Helpers > Test
abstract contract SpokeHelpers is EIP712Helpers, SpokeSetupHelpers {}
