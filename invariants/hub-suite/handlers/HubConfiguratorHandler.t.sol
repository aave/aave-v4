// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Libraries
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// Interfaces
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IHubConfiguratorHandler} from './interfaces/IHubConfiguratorHandler.sol';

// Test Contracts
import {Actor} from '../../shared/utils/Actor.sol';
import {BaseHandler} from '../base/BaseHandler.t.sol';

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

  function updateSpokeAddCap(uint256 addCap, uint8 i, uint8 j) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    address spoke = _getRandomActor(j);
    addCap = _bound(addCap, 0, MAX_ALLOWED_SPOKE_CAP);
    hubConfigurator.updateSpokeAddCap(address(hub), assetId, spoke, addCap);
  }

  function updateSpokeDrawCap(uint256 drawCap, uint8 i, uint8 j) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    address spoke = _getRandomActor(j);
    drawCap = _bound(drawCap, 0, MAX_ALLOWED_SPOKE_CAP);
    hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spoke, drawCap);
  }

  function updateSpokeRiskPremiumThreshold(
    uint256 riskPremiumThreshold,
    uint8 i,
    uint8 j
  ) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    address spoke = _getRandomActor(j);
    riskPremiumThreshold = _bound(riskPremiumThreshold, 0, MAX_RISK_PREMIUM_THRESHOLD);
    hubConfigurator.updateSpokeRiskPremiumThreshold(
      address(hub),
      assetId,
      spoke,
      riskPremiumThreshold
    );
  }

  function updateSpokeHalted(bool halted, uint8 i, uint8 j) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    address spoke = _getRandomActor(j);
    hubConfigurator.updateSpokeHalted(address(hub), assetId, spoke, halted);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        ASSET CONFIG                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateLiquidityFee(uint256 liquidityFee, uint8 i) external setup {
    uint256 assetId = _getRandomBaseAssetId(i);
    liquidityFee = _bound(liquidityFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    hubConfigurator.updateLiquidityFee(address(hub), assetId, liquidityFee);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
