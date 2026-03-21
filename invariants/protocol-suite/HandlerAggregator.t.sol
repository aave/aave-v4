// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Handler contracts
import {SpokeHandler} from './handlers/spoke/SpokeHandler.t.sol';
import {TreasurySpokeHandler} from './handlers/spoke/TreasurySpokeHandler.t.sol';
import {SpokeConfiguratorHandler} from './handlers/spoke/SpokeConfiguratorHandler.t.sol';
import {HubConfiguratorHandler} from './handlers/hub/HubConfiguratorHandler.t.sol';
import {HubAdminHandler} from './handlers/hub/HubAdminHandler.t.sol';

// Simulator contracts
import {PriceFeedSimulatorHandler} from './handlers/simulators/PriceFeedSimulatorHandler.t.sol';
import {DonationAttackHandler} from './handlers/simulators/DonationAttackHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
  SpokeHandler, // Main handlers
  TreasurySpokeHandler,
  HubConfiguratorHandler, // Configurators
  SpokeConfiguratorHandler,
  HubAdminHandler,
  PriceFeedSimulatorHandler, // Simulators
  DonationAttackHandler
{
  /// @notice Helper function in case any handler requires additional setup
  function _setUpHandlers() internal {}
}
