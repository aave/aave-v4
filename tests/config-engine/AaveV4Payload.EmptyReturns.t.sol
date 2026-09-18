// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

/// @dev Minimal concrete payload that does NOT override any virtual methods.
///   Calling execute() on this exercises every base virtual method returning empty arrays,
///   plus the no-op _preExecute / _postExecute hooks.
contract MinimalAaveV4Payload is AaveV4Payload {
  event PreExecuteCalled();
  event PostExecuteCalled();

  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

  function _preExecute() internal override {
    emit PreExecuteCalled();
  }

  function _postExecute() internal override {
    emit PostExecuteCalled();
  }
}

contract AaveV4PayloadEmptyReturnsTest is BaseConfigEngineTest {
  MinimalAaveV4Payload public minimal;

  function setUp() public override {
    super.setUp();
    minimal = new MinimalAaveV4Payload(IAaveV4ConfigEngine(address(engine)));
  }

  /// @dev Calling execute() on the minimal payload exercises _preExecute, _postExecute,
  ///   _executeAccessManagerActions, _executeHubActions, _executeSpokeActions, and every
  ///   base virtual getter (all returning empty arrays, so no delegatecalls are made).
  function test_minimalPayload_execute_noReverts() public {
    vm.expectEmit(address(minimal));
    emit MinimalAaveV4Payload.PreExecuteCalled();
    vm.expectEmit(address(minimal));
    emit MinimalAaveV4Payload.PostExecuteCalled();
    minimal.execute();
  }

  function test_hubAssetListings_returnsEmpty() public view {
    assertEq(minimal.hubAssetListings().length, 0);
  }

  function test_hubAssetConfigUpdates_returnsEmpty() public view {
    assertEq(minimal.hubAssetConfigUpdates().length, 0);
  }

  function test_hubSpokeToAssetsAdditions_returnsEmpty() public view {
    assertEq(minimal.hubSpokeToAssetsAdditions().length, 0);
  }

  function test_hubSpokeConfigUpdates_returnsEmpty() public view {
    assertEq(minimal.hubSpokeConfigUpdates().length, 0);
  }

  function test_hubAssetHalts_returnsEmpty() public view {
    assertEq(minimal.hubAssetHalts().length, 0);
  }

  function test_hubAssetDeactivations_returnsEmpty() public view {
    assertEq(minimal.hubAssetDeactivations().length, 0);
  }

  function test_hubAssetCapsResets_returnsEmpty() public view {
    assertEq(minimal.hubAssetCapsResets().length, 0);
  }

  function test_hubSpokeDeactivations_returnsEmpty() public view {
    assertEq(minimal.hubSpokeDeactivations().length, 0);
  }

  function test_hubSpokeCapsResets_returnsEmpty() public view {
    assertEq(minimal.hubSpokeCapsResets().length, 0);
  }

  function test_spokeReserveListings_returnsEmpty() public view {
    assertEq(minimal.spokeReserveListings().length, 0);
  }

  function test_spokeReserveConfigUpdates_returnsEmpty() public view {
    assertEq(minimal.spokeReserveConfigUpdates().length, 0);
  }

  function test_spokeLiquidationConfigUpdates_returnsEmpty() public view {
    assertEq(minimal.spokeLiquidationConfigUpdates().length, 0);
  }

  function test_spokeDynamicReserveConfigAdditions_returnsEmpty() public view {
    assertEq(minimal.spokeDynamicReserveConfigAdditions().length, 0);
  }

  function test_spokeDynamicReserveConfigUpdates_returnsEmpty() public view {
    assertEq(minimal.spokeDynamicReserveConfigUpdates().length, 0);
  }

  function test_spokePositionManagerUpdates_returnsEmpty() public view {
    assertEq(minimal.spokePositionManagerUpdates().length, 0);
  }

  function test_accessManagerRoleMemberships_returnsEmpty() public view {
    assertEq(minimal.accessManagerRoleMemberships().length, 0);
  }

  function test_accessManagerRoleUpdates_returnsEmpty() public view {
    assertEq(minimal.accessManagerRoleUpdates().length, 0);
  }

  function test_accessManagerTargetFunctionRoleUpdates_returnsEmpty() public view {
    assertEq(minimal.accessManagerTargetFunctionRoleUpdates().length, 0);
  }

  function test_accessManagerTargetAdminDelayUpdates_returnsEmpty() public view {
    assertEq(minimal.accessManagerTargetAdminDelayUpdates().length, 0);
  }

  function test_positionManagerSpokeRegistrations_returnsEmpty() public view {
    assertEq(minimal.positionManagerSpokeRegistrations().length, 0);
  }

  function test_positionManagerRoleRenouncements_returnsEmpty() public view {
    assertEq(minimal.positionManagerRoleRenouncements().length, 0);
  }
}
