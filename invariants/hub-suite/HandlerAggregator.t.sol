// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Handler contracts
import {HubHandler} from './handlers/HubHandler.t.sol';
import {HubConfiguratorHandler} from './handlers/HubConfiguratorHandler.t.sol';
import {HubAdminHandler} from './handlers/HubAdminHandler.t.sol';
import {DonationAttackHandler} from './handlers/simulators/DonationAttackHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts for hub suite
abstract contract HandlerAggregator is
  HubHandler,
  HubConfiguratorHandler,
  HubAdminHandler,
  DonationAttackHandler
{
  function _setUpHandlers() internal {}
}
