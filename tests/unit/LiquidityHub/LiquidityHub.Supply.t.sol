// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBase.t.sol';

contract LiquidityHubSupplyTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, address(spoke1));
  }

  function test_supply_fuzz_revertsWith_ERC20InsufficientAllowance(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, address(spoke1));
  }

  function test_supply_revertsWith_AssetNotActive() public {
    uint256 amount = 100e18;

    updateAssetActive(hub, daiAssetId, false);
    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_AssetNotActive(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetActive(hub, daiAssetId, false);
    assertFalse(hub.getAsset(daiAssetId).config.active);

    vm.expectRevert(ILiquidityHub.AssetNotActive.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetPaused() public {
    uint256 amount = 100e18;

    updateAssetPaused(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_AssetPaused(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetPaused(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.paused);

    vm.expectRevert(ILiquidityHub.AssetPaused.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetFrozen() public {
    uint256 amount = 100e18;

    updateAssetFrozen(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_AssetFrozen(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateAssetFrozen(hub, daiAssetId, true);
    assertTrue(hub.getAsset(daiAssetId).config.frozen);

    vm.expectRevert(ILiquidityHub.AssetFrozen.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_supply_cap_exceeded() public {
    uint256 amount = 100e18;

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_supply_cap_exceeded(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 newSupplyCap = amount - 1;
    _updateSupplyCap(daiAssetId, address(spoke1), newSupplyCap);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_revertsWith_supply_cap_exceeded_due_to_interest() public {
    uint256 daiAmount = 100e18;
    uint256 newSupplyCap = daiAmount + 1;

    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);
    _increaseSupplyIndex(daiAmount);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.supply(daiAssetId, 1, alice);
  }

  function test_supply_fuzz_revertsWith_supply_cap_exceeded_due_to_interest(
    uint256 daiAmount,
    uint256 drawAmount,
    uint256 rate,
    uint256 skipTime
  ) public {
    daiAmount = bound(daiAmount, 1, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 newSupplyCap = daiAmount + 1;
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay(); // 0.01% to 1000%

    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);
    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      daiDrawAmount: drawAmount,
      rate: rate,
      skipTime: skipTime
    });
    vm.assume(hub.convertToSuppliedShares(daiAssetId, daiAmount) < daiAmount);

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke2));
    hub.supply(daiAssetId, 1, alice); // cannot supply any additional amount
  }

  function test_supply_single_asset() public {
    uint256 amount = 100e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);

    // hub
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), 0);
    assertEq(hub.getAssetSuppliedShares(daiAssetId), 0);
    assertEq(hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)), 0);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)), 0);
    assertEq(hub.getAsset(daiAssetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);
    assertEq(tokenList.dai.balanceOf(address(hub)), 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.Supply(daiAssetId, address(spoke1), amount);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);

    // hub
    assertEq(hub.getAssetSuppliedAmount(daiAssetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(daiAssetId, address(spoke1)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)),
      expectedSupplyShares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(daiAssetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_supply_fuzz_single_asset(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, amount);
    IERC20 asset = hub.assetsList(assetId);
    vm.expectEmit(address(asset));
    emit IERC20.Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit ILiquidityHub.Supply(assetId, address(spoke1), amount);

    vm.prank(address(spoke1));
    hub.supply({assetId: assetId, amount: amount, supplier: alice});

    // hub
    assertEq(hub.getAssetSuppliedAmount(assetId), amount, 'hub asset suppliedAmount after');
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      expectedSupplyShares,
      'hub asset suppliedShares after'
    );
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
      amount,
      'hub spoke suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      expectedSupplyShares,
      'hub spoke suppliedShares after'
    );
    assertEq(hub.getAsset(assetId).lastUpdateTimestamp, vm.getBlockTimestamp());
    // token balance
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user token balance post-supply');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_supply_fuzz_multi_asset_multi_spoke(
    uint256 assetId,
    uint256 amount,
    uint256 amount2
  ) public {
    vm.skip(true, 'pending refactor');

    //     assetId = bound(assetId, 0, hub.assetCount() - 3); // Exclude duplicated DAI
    //     amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    //     amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    //     uint256 assetId2 = assetId + 1;

    //     IERC20 asset = hub.assetsList(assetId);
    //     IERC20 asset2 = hub.assetsList(assetId2);

    //     vm.expectEmit(address(asset));
    //     emit IERC20.Transfer(alice, address(hub), amount);
    //     vm.expectEmit(address(hub));
    //     emit ILiquidityHub.Supply(assetId, address(spoke1), amount);

    //     vm.prank(address(spoke1));
    //     hub.supply(assetId, amount, 0, alice);

    //     vm.expectEmit(address(asset2));
    //     emit IERC20.Transfer(alice, address(hub), amount2);
    //     vm.expectEmit(address(hub));
    //     emit ILiquidityHub.Supply(assetId2, address(spoke2), amount2);

    //     vm.prank(address(spoke2));
    //     hub.supply(assetId2, amount2, 0, alice);

    //     uint256 timestamp = vm.getBlockTimestamp();

    //     DataTypes.Asset memory assetData = hub.getAsset(assetId);
    //     DataTypes.Asset memory asset2Data = hub.getAsset(assetId2);
    //     DataTypes.SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));
    //     DataTypes.SpokeData memory spoke2Data = hub.getSpoke(assetId2, address(spoke2));

    //     // hub
    //     assertEq(hub.getTotalAssets(assetId), amount, 'total assets post-supply');
    //     // asset1
    //     assertEq(
    //       assetData.suppliedShares,
    //       hub.convertToShares(assetId, amount),
    //       'asset suppliedShares post-supply'
    //     );
    //     assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity post-supply');
    //     assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    //     assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    //     assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
    //     assertEq(
    //       assetData.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset baseBorrowRate post-supply'
    //     );
    //     assertEq(assetData.riskPremium, 0, 'asset riskPremium post-supply');
    //     assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    //     // spoke
    //     assertEq(
    //       spokeData.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares post-supply'
    //     );
    //     assertEq(spokeData.baseDebt, assetData.baseDebt, 'baseDebt post-supply');
    //     assertEq(
    //       spokeData.outstandingPremium,
    //       assetData.outstandingPremium,
    //       'spoke outstandingPremium post-supply'
    //     );
    //     assertEq(
    //       spokeData.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex post-supply'
    //     );
    //     assertEq(spokeData.riskPremium, 0, 'spoke riskPremium post-supply');
    //     assertEq(
    //       spokeData.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp post-supply'
    //     );
    //     assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user token balance post-supply');
    //     assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    //     assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    //     // asset2
    //     assertEq(
    //       asset2Data.suppliedShares,
    //       hub.convertToShares(assetId2, amount2),
    //       'asset2 suppliedShares post-supply'
    //     );
    //     assertEq(asset2Data.availableLiquidity, amount2, 'asset2 availableLiquidity post-supply');
    //     assertEq(asset2Data.baseDebt, 0, 'asset2 baseDebt post-supply');
    //     assertEq(asset2Data.outstandingPremium, 0, 'asset2 outstandingPremium post-supply');
    //     assertEq(asset2Data.baseBorrowIndex, WadRayMath.RAY, 'asset2 baseBorrowIndex post-supply');
    //     assertEq(
    //       asset2Data.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset2 baseBorrowRate post-supply'
    //     );
    //     assertEq(asset2Data.riskPremium, 0, 'asset2 riskPremium post-supply');
    //     assertEq(asset2Data.lastUpdateTimestamp, timestamp, 'asset2 lastUpdateTimestamp post-supply');
    //     // spoke2
    //     assertEq(
    //       spoke2Data.suppliedShares,
    //       asset2Data.suppliedShares,
    //       'spoke2 suppliedShares post-supply'
    //     );
    //     assertEq(spoke2Data.baseDebt, asset2Data.baseDebt, 'baseDebt post-supply');
    //     assertEq(
    //       spoke2Data.outstandingPremium,
    //       asset2Data.outstandingPremium,
    //       'spoke2 outstandingPremium post-supply'
    //     );
    //     assertEq(
    //       spoke2Data.baseBorrowIndex,
    //       asset2Data.baseBorrowIndex,
    //       'spoke2 baseBorrowIndex post-supply'
    //     );
    //     assertEq(spoke2Data.riskPremium, 0, 'spoke2 riskPremium post-supply');
    //     assertEq(
    //       spoke2Data.lastUpdateTimestamp,
    //       asset2Data.lastUpdateTimestamp,
    //       'spoke2 lastUpdateTimestamp post-supply'
    //     );
    //     assertEq(
    //       asset2.balanceOf(alice),
    //       MAX_SUPPLY_AMOUNT - amount2,
    //       'alice token balance post-supply'
    //     );
    //     assertEq(asset2.balanceOf(address(spoke2)), 0, 'spoke2 token balance post-supply');
    //     assertEq(asset2.balanceOf(address(hub)), amount2, 'hub token2 balance post-supply');
  }

  function test_supply_revertsWith_InvalidSharesAmount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.supply(assetId, amount, alice);
  }

  function test_supply_revertsWith_InvalidSharesAmount_due_to_index() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;
    uint256 rate = uint256(MAX_BORROW_RATE).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      daiDrawAmount: drawAmount,
      rate: rate,
      skipTime: 365 days * 10
    });
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // index increased

    // supply < 1 share
    uint256 amount = 1;
    assertTrue(hub.convertToSuppliedShares(daiAssetId, amount) == 0);

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, amount, alice);
  }

  function test_supply_fuzz_revertsWith_InvalidSharesAmount_due_to_index(
    uint256 daiAmount,
    uint256 supplyAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
    rate = bound(rate, MAX_BORROW_RATE / 10, MAX_BORROW_RATE).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      daiDrawAmount: daiAmount,
      rate: rate,
      skipTime: skipTime
    });

    uint256 minAllowedSupplyAmount = hub.convertToSuppliedAssets(daiAssetId, 1);
    vm.assume(minAllowedSupplyAmount > 1);

    // supply < 1 share
    supplyAmount = bound(supplyAmount, 1, minAllowedSupplyAmount - 1);

    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, supplyAmount, alice);
  }

  function test_supply_with_increased_index() public {
    uint256 daiAmount = 100e18;
    _increaseSupplyIndex(daiAmount);
    uint256 initialSuppliedAssets = hub.getAssetSuppliedAmount(daiAssetId);
    uint256 initialSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    uint256 supplyAmount = 10e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    (, uint256 premiumDebt) = hub.getAssetDebt(daiAssetId);
    assertEq(premiumDebt, 0); // zero premium debt

    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      initialSuppliedAssets + supplyAmount,
      'hub suppliedAssets after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares + initialSuppliedShares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      'spoke suppliedShares after'
    );
  }

  function test_supply_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    _createPremiumDebt(spoke2, daiAmount);
    assertLt(hub.convertToSuppliedShares(daiAssetId, daiAmount), daiAmount); // less shares than assets, index increased

    uint256 initialSuppliedAssets = hub.getAssetSuppliedAmount(daiAssetId);
    uint256 initialSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);

    uint256 supplyAmount = 10e18;
    uint256 expectedSupplyShares = hub.convertToSuppliedShares(daiAssetId, supplyAmount);

    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    assertEq(
      hub.getAssetSuppliedAmount(daiAssetId),
      initialSuppliedAssets + supplyAmount,
      'hub suppliedAssets after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      expectedSupplyShares + initialSuppliedShares,
      'hub suppliedShares after'
    );
    assertEq(
      hub.getAssetSuppliedShares(daiAssetId),
      hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)),
      'spoke suppliedShares after'
    );
  }

  function test_supply_multi_supply_minimal_shares() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;
    uint256 timestamp = vm.getBlockTimestamp();

    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      user: alice,
      to: address(spoke1)
    });

    // Time flies, no interest acc
    skip(1e4);

    // supplied amount does not change because no interest acc yet
    assertEq(hub.getAssetSuppliedAmount(assetId), amount);

    uint256 supplyShares = 1; // minimum for 1 share
    uint256 supplyAmount = hub.convertToSuppliedAssets(assetId, supplyShares);

    // bob supply minimal amount
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: supplyAmount,
      user: bob,
      to: address(spoke2)
    });

    // no debt exists
    uint256 baseDebt;
    uint256 premiumDebt;
    (baseDebt, premiumDebt) = hub.getAssetDebt(assetId);
    assertEq(baseDebt, 0);
    assertEq(premiumDebt, 0);
    (baseDebt, premiumDebt) = hub.getSpokeDebt(assetId, address(spoke1));
    assertEq(baseDebt, 0);
    assertEq(premiumDebt, 0);

    // hub
    assertEq(
      hub.getAssetSuppliedAmount(assetId),
      amount + supplyAmount,
      'asset suppliedAmount after'
    );
    assertEq(
      hub.getAssetSuppliedShares(assetId),
      amount + supplyShares,
      'asset suppliedShares after'
    );
    assertEq(
      hub.getAvailableLiquidity(assetId),
      amount + supplyAmount,
      'asset availableLiquidity after'
    );
    assertEq(
      hub.getAsset(assetId).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke1
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke1)),
      amount,
      'spoke1 suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke1)),
      amount,
      'spoke1 suppliedShares after'
    );
    // spoke2
    assertEq(
      hub.getSpokeSuppliedAmount(assetId, address(spoke2)),
      supplyAmount,
      'spoke2 suppliedAmount after'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(spoke2)),
      supplyShares,
      'spoke2 suppliedShares after'
    );
    // token balance
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      supplyAmount + amount,
      'hub token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'alice token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - supplyAmount,
      'bob token balance after'
    );
  }

  function test_supply_fuzz_single_spoke_multi_supply(uint256 assetId, uint256 amount) public {
    vm.skip(true, 'pending refactor');

    //     assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    //     amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);

    //     uint256 timestamp = vm.getBlockTimestamp();

    //     IERC20 asset = hub.assetsList(assetId);

    //     // initial supply
    //     Utils.supply({
    //       hub: hub,
    //       assetId: assetId,
    //       spoke: address(spoke1),
    //       amount: amount,
    //       riskPremium: 0,
    //       user: alice,
    //       to: address(spoke1)
    //     });

    //     TestSupplyUserParams memory p = TestSupplyUserParams({
    //       totalAssets: amount,
    //       suppliedShares: amount,
    //       userAssets: 0,
    //       userShares: 0
    //     });
    //     DataTypes.Asset memory assetData;
    //     DataTypes.SpokeData memory spokeData;
    //     DataTypes.Asset memory prevAssetData = hub.getAsset(assetId);

    //     uint256 runningBalance = asset.balanceOf(alice);
    //     uint256 cumulatedBaseInterest;

    //     for (uint256 i = 0; i < 5; i++) {
    //       assetData = hub.getAsset(assetId);
    //       spokeData = hub.getSpoke(assetId, address(spoke1));

    //       cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //         prevAssetData.baseBorrowRate,
    //         uint40(timestamp)
    //       );

    //       // hub
    //       assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'total assets post-supply');
    //       // asset
    //       assertEq(assetData.suppliedShares, p.suppliedShares, 'asset suppliedShares post-supply');
    //       assertEq(assetData.availableLiquidity, p.totalAssets, 'asset availableLiquidity post-supply');
    //       assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    //       assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    //       assertEq(
    //         assetData.baseBorrowIndex,
    //         prevAssetData.baseBorrowIndex.rayMul(cumulatedBaseInterest),
    //         'asset baseBorrowIndex post-supply'
    //       );
    //       assertEq(
    //         assetData.baseBorrowRate,
    //         uint256(5_00).bpsToRay(),
    //         'asset baseBorrowRate post-supply'
    //       );
    //       assertEq(assetData.riskPremium, 0, 'asset riskPremium post-supply');
    //       assertEq(
    //         assetData.lastUpdateTimestamp,
    //         vm.getBlockTimestamp(),
    //         'asset lastUpdateTimestamp post-supply'
    //       );
    //       // spoke
    //       assertEq(
    //         spokeData.suppliedShares,
    //         assetData.suppliedShares,
    //         'spoke suppliedShares post-supply'
    //       );
    //       assertEq(spokeData.baseDebt, 0, 'baseDebt post-supply');
    //       assertEq(spokeData.outstandingPremium, 0, 'spoke outstandingPremium post-supply');
    //       assertEq(
    //         spokeData.baseBorrowIndex,
    //         assetData.baseBorrowIndex,
    //         'spoke baseBorrowIndex post-supply'
    //       );
    //       assertEq(spokeData.riskPremium, 0, 'spoke riskPremium post-supply');
    //       assertEq(
    //         spokeData.lastUpdateTimestamp,
    //         assetData.lastUpdateTimestamp,
    //         'spoke lastUpdateTimestamp post-supply'
    //       );
    //       assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    //       assertEq(
    //         asset.balanceOf(address(hub)),
    //         hub.getTotalAssets(assetId),
    //         'hub token balance post-supply'
    //       );
    //       assertEq(asset.balanceOf(alice), runningBalance, 'user token balance post-supply');

    //       timestamp = vm.getBlockTimestamp();
    //       prevAssetData = assetData;

    //       // time flies
    //       uint256 elapsedTime = randomizer(1 days, 30 days, i);
    //       skip(elapsedTime);

    //       p.userShares = 1; // minimum for 1 share
    //       p.userAssets = p.userShares.toAssetsUp(hub.getTotalAssets(assetId), assetData.suppliedShares);

    //       p.totalAssets += p.userAssets;
    //       p.suppliedShares += p.userShares;

    //       // force update with action from separate user
    //       Utils.supply({
    //         hub: hub,
    //         assetId: assetId,
    //         spoke: address(spoke1),
    //         amount: p.userAssets,
    //         riskPremium: 0,
    //         user: alice,
    //         to: address(spoke1)
    //       });

    //       runningBalance -= p.userAssets;
    //     }

    //     assetData = hub.getAsset(assetId);
    //     spokeData = hub.getSpoke(assetId, address(spoke1));

    //     cumulatedBaseInterest = MathUtils.calculateLinearInterest(
    //       prevAssetData.baseBorrowRate,
    //       uint40(timestamp)
    //     );

    //     // hub
    //     assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'total assets post-supply');
    //     // asset
    //     assertEq(assetData.suppliedShares, p.suppliedShares, 'asset suppliedShares post-supply');
    //     assertEq(assetData.availableLiquidity, p.totalAssets, 'asset availableLiquidity post-supply');
    //     assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    //     assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    //     assertEq(
    //       assetData.baseBorrowIndex,
    //       prevAssetData.baseBorrowIndex.rayMul(cumulatedBaseInterest),
    //       'asset baseBorrowIndex post-supply'
    //     );
    //     assertEq(
    //       assetData.baseBorrowRate,
    //       uint256(5_00).bpsToRay(),
    //       'asset baseBorrowRate post-supply'
    //     );
    //     assertEq(assetData.riskPremium, 0, 'asset riskPremium post-supply');
    //     assertEq(
    //       assetData.lastUpdateTimestamp,
    //       vm.getBlockTimestamp(),
    //       'asset lastUpdateTimestamp post-supply'
    //     );
    //     // spoke
    //     assertEq(
    //       spokeData.suppliedShares,
    //       assetData.suppliedShares,
    //       'spoke suppliedShares post-supply'
    //     );
    //     assertEq(spokeData.baseDebt, 0, 'baseDebt post-supply');
    //     assertEq(spokeData.outstandingPremium, 0, 'spoke outstandingPremium post-supply');
    //     assertEq(
    //       spokeData.baseBorrowIndex,
    //       assetData.baseBorrowIndex,
    //       'spoke baseBorrowIndex post-supply'
    //     );
    //     assertEq(spokeData.riskPremium, 0, 'spoke riskPremium post-supply');
    //     assertEq(
    //       spokeData.lastUpdateTimestamp,
    //       assetData.lastUpdateTimestamp,
    //       'spoke lastUpdateTimestamp post-supply'
    //     );
    //     assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    //     assertEq(
    //       asset.balanceOf(address(hub)),
    //       hub.getTotalAssets(assetId),
    //       'hub token balance post-supply'
    //     );
    //     assertEq(asset.balanceOf(alice), runningBalance, 'user token balance post-supply');
  }
}
