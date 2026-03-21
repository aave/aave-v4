// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubAdminHandler} from './interfaces/IHubAdminHandler.sol';

// Test Contracts
import {CommonHelpers} from '../../shared/utils/CommonHelpers.sol';
import {BaseHandler} from '../base/BaseHandler.t.sol';

/// @title HubAdminHandlerBase
/// @notice Handler for hub-level admin operations that are not configurator-restricted:
///         liquidity reinvestment (sweep/reclaim) and fee share minting (mintFeeShares).
/// @dev These target the Hub's reinvestment controller interface and access-managed fee paths.
///      The handler itself is the caller (not an actor proxy), so it must be configured as the
///      reinvestmentController for sweep/reclaim and granted permissions for mintFeeShares.
abstract contract HubAdminHandlerBase is CommonHelpers, IHubAdminHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function sweep(uint256 amount, uint8 i, uint8 j) external {
    uint256 assetId = _getRandomAssetId(i);
    IHub hub = _getRandomHub(j);

    _beforeHook();
    try hub.sweep(assetId, amount) {
      _afterHook();
    } catch {
      revert('HubHandler: sweep failed');
    }
  }

  function reclaim(uint256 amount, uint8 i, uint8 j) external {
    uint256 assetId = _getRandomAssetId(i);
    IHub hub = _getRandomHub(j);

    _tryMint(hub.getAsset(assetId).underlying, address(hub), amount);

    _beforeHook();
    try hub.reclaim(assetId, amount) {
      _afterHook();
    } catch {
      revert('HubHandler: reclaim failed');
    }
  }

  function mintFeeShares(uint8 i, uint8 j) external {
    uint256 assetId = _getRandomAssetId(i);
    IHub hub = _getRandomHub(j);

    _beforeHook();
    try hub.mintFeeShares(assetId) {
      _afterHook();
    } catch {
      revert('HubHandler: mintFeeShares failed');
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Hook invoked before each handler action. Concrete handlers wire this to the suite's _before() snapshot.
  function _beforeHook() internal virtual;

  /// @dev Hook invoked after each handler action. Concrete handlers wire this to the suite's _after() snapshot + postcondition checks.
  function _afterHook() internal virtual;

  /// @dev Returns the hub to target for the current action.
  function _getRandomHub(uint8 i) internal view virtual returns (IHub);

  /// @dev Returns the hub-level assetId to target for the current action.
  function _getRandomAssetId(uint8 i) internal view virtual returns (uint256);
}

/// @title HubAdminHandler
/// @notice Hub-suite concrete handler — single hub, selects a random asset id per call.
contract HubAdminHandler is HubAdminHandlerBase, BaseHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _beforeHook() internal override {
    _before();
  }

  function _afterHook() internal override {
    _after();
  }

  function _getRandomHub(uint8) internal view override returns (IHub) {
    return hub;
  }

  function _getRandomAssetId(uint8 i) internal view override returns (uint256) {
    return _getRandomBaseAssetId(i);
  }
}
