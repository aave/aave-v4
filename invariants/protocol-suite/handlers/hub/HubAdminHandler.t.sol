// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Test Contracts
import {HubAdminHandlerBase} from '../../../hub-suite/handlers/HubAdminHandler.t.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title HubAdminHandler
/// @notice Protocol-suite concrete handler — multi-hub variant that selects hubs indirectly
///         through spoke → reserveId → hub mappings, covering all hub/asset combinations
///         reachable from the deployed spokes.
contract HubAdminHandler is BaseHandler, HubAdminHandlerBase {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function _beforeHook() internal override {
    _before();
  }

  function _afterHook() internal override {
    _after();
  }

  /// @dev Picks a random spoke, derives a random reserveId, then resolves the backing hub.
  function _getRandomHub(uint8 i) internal view override returns (IHub) {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(
      spoke,
      _bound(_randomize(i, vm.toString(spoke)), 0, type(uint8).max)
    );
    return IHub(_getHubAddress(spoke, reserveId));
  }

  /// @dev Picks a random spoke, derives a random reserveId, then resolves the hub-level assetId.
  function _getRandomAssetId(uint8 i) internal view override returns (uint256) {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(
      spoke,
      _bound(_randomize(i, vm.toString(spoke)), 0, type(uint8).max)
    );
    return _getAssetId(spoke, reserveId);
  }
}
