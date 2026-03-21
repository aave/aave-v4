// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHubConfiguratorHandler} from '../interfaces/IHubConfiguratorHandler.sol';

// Test Contracts
import {Actor} from '../../../shared/utils/Actor.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title HubConfiguratorHandler
/// @notice Handler test contract for a set of actions
/// @dev Inputs are bounded to Hub validation constraints so admin actions don't unnecessarily
///      discard fuzzer runs.
contract HubConfiguratorHandler is BaseHandler, IHubConfiguratorHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        SPOKE CONFIG                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateSpokeAddCap(uint256 addCap, uint8 i, uint8 j, uint8 k) external setup {
    address hub = _getRandomHub(i);
    uint256 assetId = _getRandomHubAssetId(hub, j);
    address spoke = _getRandomSpoke(k);
    addCap = _bound(addCap, 0, MAX_ALLOWED_SPOKE_CAP);
    hubConfigurator.updateSpokeAddCap(hub, assetId, spoke, addCap);
  }

  function updateSpokeDrawCap(uint256 drawCap, uint8 i, uint8 j, uint8 k) external setup {
    address hub = _getRandomHub(i);
    uint256 assetId = _getRandomHubAssetId(hub, j);
    address spoke = _getRandomSpoke(k);
    drawCap = _bound(drawCap, 0, MAX_ALLOWED_SPOKE_CAP);
    hubConfigurator.updateSpokeDrawCap(hub, assetId, spoke, drawCap);
  }

  function updateSpokeRiskPremiumThreshold(
    uint256 riskPremiumThreshold,
    uint8 i,
    uint8 j,
    uint8 k
  ) external setup {
    address hub = _getRandomHub(i);
    uint256 assetId = _getRandomHubAssetId(hub, j);
    address spoke = _getRandomSpoke(k);
    riskPremiumThreshold = _bound(riskPremiumThreshold, 0, MAX_RISK_PREMIUM_THRESHOLD);
    hubConfigurator.updateSpokeRiskPremiumThreshold(hub, assetId, spoke, riskPremiumThreshold);
  }

  function updateSpokeHalted(bool halted, uint8 i, uint8 j, uint8 k) external setup {
    address hub = _getRandomHub(i);
    uint256 assetId = _getRandomHubAssetId(hub, j);
    address spoke = _getRandomSpoke(k);
    hubConfigurator.updateSpokeHalted(hub, assetId, spoke, halted);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
