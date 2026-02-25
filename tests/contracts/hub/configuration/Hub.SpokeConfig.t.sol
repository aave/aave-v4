// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract HubSpokeConfigTest is Base {
  function setUp() public override {
    super.setUp();

    // deploy borrowable liquidity
    _addLiquidity(hub1, usdxAssetId, MAX_SUPPLY_AMOUNT, ADMIN, MAX_ALLOWED_COLLATERAL_RISK);
  }

  function test_mintFeeShares_active_halted_scenarios() public {
    address feeReceiver = _getFeeReceiver(hub1, usdxAssetId);

    // set spoke to active / halted; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokeHalted(hub1, usdxAssetId, feeReceiver, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, true, HUB_ADMIN);

    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to inactive / halted; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokeHalted(hub1, usdxAssetId, feeReceiver, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to active / not halted; succeeds
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokeHalted(hub1, usdxAssetId, feeReceiver, false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, true, HUB_ADMIN);

    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);

    // set spoke to inactive / not halted; reverts
    _accrueLiquidityFees(hub1, spoke1, usdxAssetId);
    _updateSpokeHalted(hub1, usdxAssetId, feeReceiver, false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(HUB_ADMIN);
    hub1.mintFeeShares(usdxAssetId);
  }

  function test_add_active_halted_scenarios() public {
    // set spoke to active / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeHalted.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    HubActions.add(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.add(usdxAssetId, 1);
  }

  function test_remove_active_halted_scenarios() public {
    HubActions.add(hub1, usdxAssetId, address(spoke1), 100, alice);

    // set spoke to active / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeHalted.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    HubActions.remove(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.remove(usdxAssetId, 1, alice);
  }

  function test_draw_active_halted_scenarios() public {
    // set spoke to active / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeHalted.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    HubActions.draw(hub1, usdxAssetId, address(spoke1), alice, 1);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.draw(usdxAssetId, 1, alice);
  }

  function test_restore_active_halted_scenarios() public {
    HubActions.draw(hub1, usdxAssetId, address(spoke1), alice, 100);

    // set spoke to active / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeHalted.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    HubActions.restoreDrawn(hub1, usdxAssetId, address(spoke1), 1, alice);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.restore(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
  }

  function test_reportDeficit_active_halted_scenarios() public {
    // draw usdx liquidity to be restored
    _drawLiquidity({
      hub: hub1,
      assetId: usdxAssetId,
      amount: 1,
      withPremium: true,
      skipTime: true,
      spoke: address(spoke1)
    });

    // set spoke to active / halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive and halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to active and not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);

    // set spoke to inactive and not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.reportDeficit(usdxAssetId, 1, ZERO_PREMIUM_DELTA);
  }

  function test_eliminateDeficit_active_halted_scenarios() public {
    address coveredSpoke = address(spoke1);
    address callerSpoke = address(spoke2);
    _grantDeficitEliminatorRole(hub1, callerSpoke, ADMIN);

    // create reported deficit on spoke1
    _createReportedDeficit(hub1, coveredSpoke, usdxAssetId);
    HubActions.add(hub1, usdxAssetId, callerSpoke, 1e18, alice);

    // covered spoke status does not matter
    _updateSpokeHalted(hub1, usdxAssetId, coveredSpoke, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, coveredSpoke, false, HUB_ADMIN);

    // set caller spoke to active / halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, callerSpoke, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, true, HUB_ADMIN);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, callerSpoke, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, callerSpoke, false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, callerSpoke, true, HUB_ADMIN);

    vm.prank(callerSpoke);
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    _grantDeficitEliminatorRole(hub1, address(spoke1), ADMIN);
    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.eliminateDeficit(usdxAssetId, 1, coveredSpoke);
  }

  function test_refreshPremium_active_halted_scenarios() public {
    // set spoke to active / halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.refreshPremium(usdxAssetId, ZERO_PREMIUM_DELTA);
  }

  function test_payFeeShares_active_halted_scenarios() public {
    address feeReceiver = _getFeeReceiver(hub1, usdxAssetId);
    HubActions.add(hub1, usdxAssetId, address(spoke1), 1e18, alice);

    // set fee receiver to inactive / halted; does not matter
    _updateSpokeHalted(hub1, usdxAssetId, feeReceiver, true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, feeReceiver, false, HUB_ADMIN);

    // set spoke to active / halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to inactive / halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to active / not halted; succeeds
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), true, HUB_ADMIN);

    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);

    // set spoke to inactive / not halted; reverts
    _updateSpokeHalted(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, address(spoke1), false, HUB_ADMIN);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.payFeeShares(usdxAssetId, 1);
  }

  function test_transferShares_fuzz_active_halted_scenarios(
    bool senderPaused,
    bool receiverPaused,
    bool senderActive,
    bool receiverActive
  ) public {
    address sender = address(spoke1);
    address receiver = address(spoke2);
    HubActions.add(hub1, usdxAssetId, sender, 1e18, alice);

    // set sender
    _updateSpokeHalted(hub1, usdxAssetId, sender, senderPaused, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, sender, senderActive, HUB_ADMIN);
    // set receiver
    _updateSpokeHalted(hub1, usdxAssetId, receiver, receiverPaused, HUB_ADMIN);
    _updateSpokeActive(hub1, usdxAssetId, receiver, receiverActive, HUB_ADMIN);

    if (!senderActive || !receiverActive) {
      vm.expectRevert(IHub.SpokeNotActive.selector);
    } else if (senderPaused || receiverPaused) {
      vm.expectRevert(IHub.SpokeHalted.selector);
    }
    vm.prank(sender);
    hub1.transferShares(usdxAssetId, 1, receiver);
  }

  function _accrueLiquidityFees(IHub hub, ISpoke spoke, uint256 assetId) internal {
    HubActions.add(hub, wbtcAssetId, address(spoke), 1e18, alice);
    HubActions.draw(hub, assetId, address(spoke), alice, 1e18);

    skip(365 days);
    HubActions.add(hub, assetId, address(spoke), 1e18, alice);

    assertGt(hub.getAsset(assetId).realizedFees, 0);
  }

  function _createReportedDeficit(IHub hub, address spoke, uint256 assetId) internal {
    HubActions.add(hub, wbtcAssetId, spoke, 1e18, alice);
    HubActions.draw(hub, assetId, spoke, alice, 1e18);

    skip(365 days);
    HubActions.add(hub, assetId, spoke, 1e18, alice);

    vm.prank(spoke);
    hub.reportDeficit(assetId, 1e18, ZERO_PREMIUM_DELTA);

    assertGt(hub.getAssetDeficitRay(assetId), 0);
  }
}
