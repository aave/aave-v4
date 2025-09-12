// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubRestoreTest is HubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  HubConfigurator public hubConfigurator;
  address public HUB_CONFIGURATOR_ADMIN = makeAddr('HUB_CONFIGURATOR_ADMIN');

  function setUp() public override {
    super.setUp();

    // Set up a hub configurator to test freezing and pausing assets
    hubConfigurator = new HubConfigurator(HUB_CONFIGURATOR_ADMIN);
    IAccessManager accessManager = IAccessManager(hub1.authority());
    // Grant hubConfigurator hub admin role with 0 delay
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
  }

  function test_restore_revertsWith_SurplusAmountRestored() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 add weth
    Utils.add({
      hub: hub1,
      assetId: wethAssetId,
      caller: address(spoke1),
      amount: wethAmount,
      user: alice
    });

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: 0
    });

    // alice restore invalid amount > drawn
    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, drawAmount));
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawn + 1, premium, premiumDelta, alice);
  }

  function test_restore_revertsWith_InvalidAmount_zero() public {
    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: 0
    });

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, 0, 0, premiumDelta, alice);
  }

  function test_restore_revertsWith_SpokeNotActive_whenPaused() public {
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.pauseAsset(address(hub1), daiAssetId);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: 0
    });

    vm.expectRevert(IHub.SpokeNotActive.selector);
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, 1, 0, premiumDelta, alice);
  }

  /// @dev It's possible to restore even when asset is frozen
  function test_restore_when_asset_frozen() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    // Freeze asset
    vm.prank(HUB_CONFIGURATOR_ADMIN);
    hubConfigurator.freezeAsset(address(hub1), daiAssetId);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn / 2;
    uint256 restoreAmount = drawnRestored + premium;

    // no premium accrued in the same block
    assertEq(premium, 0);
    uint256 drawnShares = hub1.previewRestoreByAssets(daiAssetId, drawnRestored);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });

    vm.expectEmit(address(hub1));
    emit IHubBase.Restore(
      daiAssetId,
      address(spoke1),
      hub1.convertToDrawnShares(daiAssetId, drawnRestored),
      premiumDelta,
      drawnRestored,
      premium
    );

    vm.prank(address(spoke1));
    uint256 restoredShares = hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);

    assertEq(restoredShares, drawnShares);
    AssetPosition memory daiData = getAssetPosition(hub1, daiAssetId);
    // hub dai data
    assertEq(daiData.addedAmount, daiAmount, 'hub dai total assets post-restore');
    assertEq(
      daiData.addedShares,
      hub1.convertToAddedShares(daiAssetId, daiAmount),
      'hub dai total shares post-restore'
    );
    assertEq(
      daiData.liquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai liquidity post-restore'
    );
    assertEq(daiData.drawn, drawAmount - restoreAmount, 'hub dai drawn post-restore');
    assertEq(daiData.premium, 0, 'hub dai premium post-restore');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub dai lastUpdateTimestamp post-restore'
    );
    // spoke1 dai data
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1)),
      0,
      'spoke1 total dai shares post-restore'
    );
    (uint256 spoke1DaiDrawn, uint256 spoke1DaiPremium) = hub1.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );
    assertEq(spoke1DaiDrawn, daiData.drawn, 'spoke1 drawn dai post-restore');
    assertEq(spoke1DaiPremium, daiData.premium, 'spoke1 dai premium post-restore');

    // dai token balance
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      daiAmount - restoreAmount,
      'hub dai final balance'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      drawAmount - restoreAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
  }

  function test_restore_revertsWith_SurplusAmountRestored_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;

    test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest(
      daiAmount,
      drawAmount,
      skipTime
    );
  }

  /// @dev Restore an amount greater than drawn, with drawn interest accrued (no premium).
  function test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, 1000e18); // max 1000 DAI
    drawAmount = bound(drawAmount, 1, daiAmount); // within added dai amount
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke2),
      amount: daiAmount,
      user: bob
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    skip(skipTime);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    assertEq(premium, 0);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: 0
    });

    // alice restore invalid amount > drawn
    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, drawn));
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawn + 1, premium, premiumDelta, alice);
  }

  function test_restore_revertsWith_SurplusAmountRestored_with_interest_and_premium() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days;
    uint256 premiumRestored = 1;

    test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest_and_premium(
      daiAmount,
      drawAmount,
      skipTime,
      premiumRestored
    );
  }

  /// @dev Restore an amount greater than the drawn, with drawn interest and premium accrued.
  function test_restore_fuzz_revertsWith_SurplusAmountRestored_with_interest_and_premium(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint256 premiumRestored
  ) public {
    daiAmount = bound(daiAmount, 1, 1000e18);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 wethAmount = daiAmount; // to ensure enough collateralization

    // spoke1 add weth
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: wethAmount,
      onBehalfOf: alice
    });

    // spoke2 add dai
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      caller: bob,
      amount: daiAmount,
      onBehalfOf: bob
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      onBehalfOf: alice,
      amount: drawAmount,
      caller: alice
    });

    skip(skipTime);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    assertGt(premium, 0);

    premiumRestored = bound(premiumRestored, 1, premium);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premiumRestored
    });

    // alice restore invalid drawn
    vm.expectRevert(abi.encodeWithSelector(IHub.SurplusAmountRestored.selector, drawn));
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawn + 1, premiumRestored, premiumDelta, alice);
  }

  function test_restore_premiumDeltas_twoWeiIncrease_realizedDelta() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn;
    uint256 restoreAmount = drawnRestored + premium;

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });
    premiumDelta.realizedDelta += vm.randomUint(0, 2).toInt256();

    vm.expectEmit(address(hub1));
    emit IHubBase.Restore(
      daiAssetId,
      address(spoke1),
      hub1.convertToDrawnShares(daiAssetId, drawnRestored),
      premiumDelta,
      drawnRestored,
      premium
    );

    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);
  }

  function test_restore_revertsWith_InvalidPremiumChange_premiumIncrease() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn;
    uint256 restoreAmount = drawnRestored + premium;

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });
    premiumDelta.realizedDelta += 3;

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);
  }

  function test_restore_revertsWith_underflow_offsetIncrease() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn;
    uint256 restoreAmount = drawnRestored + premium;

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });
    premiumDelta.offsetDelta += 1;

    vm.expectRevert(stdError.arithmeticError);
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);
  }

  function test_restore_two_wei_shares_delta_increase() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn;
    uint256 restoreAmount = drawnRestored + premium;

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });
    premiumDelta.sharesDelta += vm.randomUint(0, 2).toInt256();

    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);
  }

  function test_restore_revertsWith_InvalidPremiumChange_premiumSharesIncrease() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn;
    uint256 restoreAmount = drawnRestored + premium;

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });
    premiumDelta.sharesDelta += 3;

    vm.expectRevert(IHub.InvalidPremiumChange.selector);
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);
  }

  /// @dev Restore partial amount of drawn after time has passed (no premium).
  function test_restore_partial_drawn() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addAmount: daiAmount,
      addSpoke: address(spoke2),
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days
    });
    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 restoreDrawnAmount = drawn / 2;

    // no premium accrued
    assertEq(premium, 0);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });

    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, restoreDrawnAmount, premium, premiumDelta, alice);

    AssetPosition memory daiData = getAssetPosition(hub1, daiAssetId);
    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // hub
    assertApproxEqAbs(
      hub1.getAssetAddedAmount(daiAssetId),
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke2)) +
        hub1.getSpokeAddedAssets(daiAssetId, feeReceiver) +
        _calculateBurntInterest(hub1, daiAssetId),
      1,
      'hub dai total addedAmount'
    );
    assertApproxEqAbs(daiData.drawn, drawn - restoreDrawnAmount, 1, 'dai asset drawn');
    assertEq(daiData.premium, 0, 'dai premium');
    assertEq(daiData.liquidity, daiAmount - drawAmount + restoreDrawnAmount, 'hub dai liquidity');
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    // spoke1
    assertEq(hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)), 0, 'hub spoke1 addedAmount');
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), 0, 'hub spoke1 addedShares');
    (uint256 spoke1DaiDrawn, uint256 spoke1DaiPremium) = hub1.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );
    assertEq(spoke1DaiDrawn, daiData.drawn, 'hub spoke1 drawn');
    assertEq(spoke1DaiPremium, daiData.premium, 'hub spoke1 premium');
  }

  /// @dev Restore partial amount of drawn in the same block as draw action.
  function test_restore_partial_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke2 add dai
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      amount: daiAmount,
      user: bob,
      caller: address(spoke2)
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: alice,
      caller: address(spoke1),
      amount: drawAmount
    });

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 drawnRestored = drawn / 2;
    uint256 restoreAmount = drawnRestored + premium;

    // no premium accrued in the same block
    assertEq(premium, 0);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });

    vm.expectEmit(address(hub1));
    emit IHubBase.Restore(
      daiAssetId,
      address(spoke1),
      hub1.convertToDrawnShares(daiAssetId, drawnRestored),
      premiumDelta,
      drawnRestored,
      premium
    );

    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawnRestored, premium, premiumDelta, alice);

    AssetPosition memory daiData = getAssetPosition(hub1, daiAssetId);

    // hub dai data
    assertEq(daiData.addedAmount, daiAmount, 'hub dai total assets post-restore');
    assertEq(
      daiData.addedShares,
      hub1.convertToAddedShares(daiAssetId, daiAmount),
      'hub dai total shares post-restore'
    );
    assertEq(
      daiData.liquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai liquidity post-restore'
    );
    assertEq(daiData.drawn, drawAmount - restoreAmount, 'hub dai drawn post-restore');
    assertEq(daiData.premium, 0, 'hub dai premium post-restore');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'hub dai lastUpdateTimestamp post-restore'
    );
    // spoke1 dai data
    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1)),
      0,
      'spoke1 total dai shares post-restore'
    );
    (uint256 spoke1DaiDrawn, uint256 spoke1DaiPremium) = hub1.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );
    assertEq(spoke1DaiDrawn, daiData.drawn, 'spoke1 drawn dai post-restore');
    assertEq(spoke1DaiPremium, daiData.premium, 'spoke1 dai premium post-restore');

    IERC20 dai = IERC20(hub1.getAsset(daiAssetId).underlying);

    // dai token balance
    assertEq(dai.balanceOf(address(hub1)), daiAmount - restoreAmount, 'hub dai final balance');
    assertEq(
      dai.balanceOf(alice),
      drawAmount - restoreAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
  }

  function test_restore_full_amount_with_interest() public {
    uint256 daiAmount = 1000e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days;

    test_restore_fuzz_full_amount_with_interest(daiAmount, drawAmount, skipTime);
  }

  /// @dev Restore full drawn amount after time has passed, with drawn interest accrued (no premium).
  function test_restore_fuzz_full_amount_with_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, 1000e18); // max 1000 DAI
    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    // spoke2 add dai
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      amount: daiAmount,
      caller: bob,
      onBehalfOf: bob
    });

    // spoke1 draw liquidity
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: address(spoke1),
      caller: address(spoke1),
      amount: drawAmount
    });

    skip(skipTime);
    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));

    // no premium accrued
    assertEq(premium, 0);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premium
    });

    // spoke1 restore full drawn
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawn, premium, premiumDelta, alice);

    AssetPosition memory daiData = getAssetPosition(hub1, daiAssetId);
    address daiFeeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // asset
    assertEq(daiData.drawn, 0, 'asset drawn');
    assertEq(daiData.premium, 0, 'asset premium');

    // spoke
    assertApproxEqAbs(
      daiData.addedAmount,
      hub1.getSpokeAddedAssets(daiAssetId, daiFeeReceiver) +
        hub1.getSpokeAddedAssets(daiAssetId, address(spoke2)),
      1,
      'spoke addedAmount'
    );
    assertApproxEqAbs(
      daiData.addedShares,
      hub1.getSpokeAddedShares(daiAssetId, daiFeeReceiver) +
        hub1.getSpokeAddedShares(daiAssetId, address(spoke2)),
      1,
      'spoke addedShares'
    );
    (uint256 spoke1DaiDrawn, uint256 spoke1DaiPremium) = hub1.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );
    assertEq(spoke1DaiDrawn, 0, 'spoke1 drawn');
    assertEq(spoke1DaiPremium, 0, 'spoke1 premium');
  }

  function test_restore_full_amount_with_interest_and_premium() public {
    uint256 daiAmount = 100e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days;
    uint256 premiumRestored = 1;

    test_restore_fuzz_full_amount_with_interest_and_premium(
      daiAmount,
      drawAmount,
      skipTime,
      premiumRestored
    );
  }

  /// @dev Restore full drawn amount after time has passed, with drawn interest and premium accrued.
  function test_restore_fuzz_full_amount_with_interest_and_premium(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint256 premiumRestored
  ) public {
    daiAmount = bound(daiAmount, 1, 1000e18); // max 1000 DAI
    drawAmount = bound(drawAmount, 1, daiAmount); // within added dai amount
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 wethAmount = daiAmount; // to ensure collateralization

    // spoke1 add weth
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: wethAmount,
      onBehalfOf: alice
    });

    // spoke2 add dai
    Utils.supplyCollateral({
      spoke: spoke2,
      reserveId: _daiReserveId(spoke2),
      caller: bob,
      amount: daiAmount,
      onBehalfOf: bob
    });

    // spoke1 draw liquidity
    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: drawAmount,
      onBehalfOf: alice
    });

    skip(skipTime);

    (uint256 drawn, uint256 premium) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    assertGt(premium, 0);

    premiumRestored = bound(premiumRestored, 1, premium);

    DataTypes.PremiumDelta memory premiumDelta = _getExpectedPremiumDelta({
      spoke: spoke1,
      user: alice,
      reserveId: daiAssetId,
      premiumRestored: premiumRestored
    });

    AssetPosition memory daiDataBefore = getAssetPosition(hub1, daiAssetId);

    // spoke1 restore full drawn
    vm.prank(address(spoke1));
    hub1.restore(daiAssetId, drawn, premiumRestored, premiumDelta, alice);

    AssetPosition memory daiData = getAssetPosition(hub1, daiAssetId);
    address daiFeeReceiver = _getFeeReceiver(hub1, daiAssetId);

    // asset
    assertEq(daiData.drawn, 0, 'asset drawn');
    assertApproxEqAbs(daiData.premium, premium - premiumRestored, 2, 'asset premium');

    // spoke
    assertApproxEqAbs(
      daiData.addedAmount,
      hub1.getSpokeAddedAssets(daiAssetId, daiFeeReceiver) +
        hub1.getSpokeAddedAssets(daiAssetId, address(spoke2)),
      1,
      'spoke addedAmount'
    );
    assertApproxEqAbs(
      daiData.addedShares,
      hub1.getSpokeAddedShares(daiAssetId, daiFeeReceiver) +
        hub1.getSpokeAddedShares(daiAssetId, address(spoke2)),
      1,
      'spoke addedShares'
    );
    (uint256 spoke1DaiDrawn, uint256 spoke1DaiPremium) = hub1.getSpokeOwed(
      daiAssetId,
      address(spoke1)
    );
    assertEq(spoke1DaiDrawn, 0, 'spoke1 drawn');
    assertApproxEqAbs(spoke1DaiPremium, premium - premiumRestored, 2, 'spoke1 premium');
  }
}
