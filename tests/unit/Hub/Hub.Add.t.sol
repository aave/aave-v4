// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubAddTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  address minDecimalAsset;

  function setUp() public override {
    super.setUp();

    TestnetERC20 usda = new TestnetERC20('USDA', 'USDA', Constants.MIN_ALLOWED_UNDERLYING_DECIMALS);
    minDecimalAsset = address(usda);
    deal(address(usda), alice, MAX_SUPPLY_AMOUNT);

    /// @dev add a minimum decimal asset to test add cap rounding
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      paused: false,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK
    });
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.startPrank(ADMIN);
    hub1.addAsset(
      address(usda),
      Constants.MIN_ALLOWED_UNDERLYING_DECIMALS,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      minDecimalAsset,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    spoke1.addReserve(
      address(hub1),
      minDecimalAsset,
      _deployMockPriceFeed(spoke1, 1e8),
      ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 20_00}),
      ISpoke.DynamicReserveConfig({
        collateralFactor: 78_00,
        maxLiquidationBonus: 100_00,
        liquidationFee: 0
      })
    );
    hub1.addSpoke(minDecimalAsset, address(spoke1), spokeConfig);
    vm.stopPrank();
  }

  function test_add_revertsWith_SpokePaused() public {
    _updateSpokePaused(hub1, address(tokenList.dai), address(spoke1), true);
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), 100e18);

    vm.expectRevert(IHub.SpokePaused.selector);
    hub1.add(address(tokenList.dai), 100e18);
    vm.stopPrank();
  }

  function test_add_revertsWith_SpokeNotActive() public {
    updateSpokeActive(hub1, address(tokenList.dai), address(spoke1), false);
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), 100e18);

    vm.expectRevert(IHub.SpokeNotActive.selector);
    hub1.add(address(tokenList.dai), 100e18);
    vm.stopPrank();
  }

  function test_add_revertsWith_InvalidAmountReceived() public {
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), 90e18);

    vm.expectRevert(IHub.InvalidAmountReceived.selector);
    hub1.add(address(tokenList.dai), 100e18);
    vm.stopPrank();
  }

  function test_add_revertsWith_SharesDowncastOverflow() public {
    uint256 shares = uint256(type(uint120).max) + 1;
    uint256 amount = hub1.previewAddByShares(address(tokenList.dai), shares);
    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 120, shares)
    );
    vm.prank(address(spoke1));
    hub1.add(address(tokenList.dai), amount);
  }

  function test_add_revertsWith_AmountDowncastOverflow() public {
    _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: 1,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: 1,
      skipTime: 365 days
    });

    uint256 shares = type(uint120).max - 2;
    uint256 amount = hub1.previewAddByShares(address(tokenList.dai), shares);
    assertGt(amount, type(uint120).max);

    vm.expectRevert(
      abi.encodeWithSelector(SafeCast.SafeCastOverflowedUintDowncast.selector, 120, amount)
    );
    vm.prank(address(spoke1));
    hub1.add(address(tokenList.dai), amount);
  }

  function test_add_fuzz_revertsWith_AddCapExceeded(uint40 newAddCap) public {
    newAddCap = bound(newAddCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();
    _updateAddCap(address(tokenList.dai), address(spoke1), newAddCap);
    uint256 amount = newAddCap * 10 ** tokenList.dai.decimals() + 1;
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), amount);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    hub1.add(address(tokenList.dai), amount);
    vm.stopPrank();
  }

  function test_add_fuzz_AddCapReachedButNotExceeded(uint40 newAddCap) public {
    newAddCap = bound(newAddCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();
    _updateAddCap(address(tokenList.dai), address(spoke1), newAddCap);
    uint256 amount = newAddCap * 10 ** tokenList.dai.decimals();
    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), amount);
    hub1.add(address(tokenList.dai), amount);
    vm.stopPrank();
    assertEq(hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke1)), amount);
  }

  function test_add_fuzz_revertsWith_AddCapExceeded_due_to_interest(
    uint40 newAddCap,
    uint256 drawAmount,
    uint256 skipTime
  ) public {
    newAddCap = bound(newAddCap, 1, MAX_SUPPLY_AMOUNT / 10 ** tokenList.dai.decimals()).toUint40();
    uint256 daiAmount = newAddCap * 10 ** tokenList.dai.decimals() - 1;
    drawAmount = bound(drawAmount, 1, daiAmount);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    _updateAddCap(address(tokenList.dai), address(spoke2), newAddCap);
    _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });
    vm.assume(hub1.previewAddByAssets(address(tokenList.dai), daiAmount) < daiAmount);

    uint256 addAmount = hub1.previewAddByShares(address(tokenList.dai), 1);
    vm.prank(alice);
    tokenList.dai.approve(address(spoke2), addAmount);
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), addAmount);
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    hub1.add(address(tokenList.dai), addAmount); // cannot add any additional amount
    vm.stopPrank();
  }

  // add succeeds if cap is reached but not exceeded
  function test_add_AddCapReachedButNotExceeded_rounding() public {
    _addLiquidity(minDecimalAsset, 100e18);
    _drawLiquidity(minDecimalAsset, 45e18, true);

    uint256 totalAddedAssets = hub1.getAddedAssets(minDecimalAsset);
    uint256 totalAddedShares = hub1.getAddedShares(minDecimalAsset);

    // Depending on the borrow rate, this may not be true
    // It can be adjusted by changing the amount of assets passed to _addLiquidity and _drawLiquidity
    assertEq(
      uint256(1).toAssetsDown(totalAddedAssets, totalAddedShares).toSharesDown(
        totalAddedAssets,
        totalAddedShares
      ),
      0,
      'share price is a whole number'
    );

    // The asset amount is 1 share worth of assets (rounded down) + 1
    // The added share is 1, which rounded up is equal to the
    // amount of assets added
    uint256 addedAmount = uint256(1).toAssetsDown(totalAddedAssets, totalAddedShares) + 1;

    uint256 spokeAddedShares = hub1.getSpokeAddedShares(minDecimalAsset, address(spoke1));
    uint256 spokeAddedAssetsRoundedUp = spokeAddedShares.toAssetsUp(
      totalAddedAssets,
      totalAddedShares
    );

    uint40 newAddCap = (spokeAddedAssetsRoundedUp + addedAmount).toUint40();
    _updateAddCap(minDecimalAsset, address(spoke1), newAddCap);

    Utils.add({
      hub: hub1,
      asset: minDecimalAsset,
      caller: address(spoke1),
      amount: addedAmount,
      user: alice
    });
  }

  function test_add_single_asset() public {
    test_add_fuzz_single_asset(0, alice, 100e18);
  }

  /// @dev User makes a first add, shares and assets amounts are correct, no precision loss
  function test_add_fuzz_single_asset(uint256 assetIdx, address user, uint256 amount) public {
    _assumeValidSupplier(user);

    assetIdx = bound(assetIdx, 0, hub1.getAssetCount() - 3); // Exclude duplicated DAI and usdy
    address asset = hub1.getUnderlyingAddress(assetIdx);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    IERC20 underlying = IERC20(asset);

    (uint256 drawnBefore, ) = hub1.getAssetOwed(asset);
    uint256 liquidityBefore = hub1.getAssetLiquidity(asset);
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (asset, liquidityBefore + amount, drawnBefore, 0, 0)
      )
    );

    vm.prank(user);
    underlying.approve(address(spoke1), amount);
    deal(address(underlying), user, amount);

    vm.startPrank(address(spoke1));
    underlying.transferFrom(user, address(hub1), amount);

    uint256 shares = hub1.previewAddByAssets(asset, amount);
    vm.expectEmit(address(hub1));
    emit IHubBase.Add(asset, address(spoke1), shares, amount);

    uint256 addedShares = hub1.add(asset, amount);
    vm.stopPrank();

    // hub
    assertEq(addedShares, shares);
    assertEq(hub1.getAddedAssets(asset), amount, 'hub asset addedAmount after');
    assertEq(hub1.getAddedShares(asset), shares, 'hub asset addedShares after');
    assertEq(
      hub1.getSpokeAddedAssets(asset, address(spoke1)),
      amount,
      'hub spoke addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(asset, address(spoke1)),
      shares,
      'hub spoke addedShares after'
    );
    assertEq(hub1.getAsset(asset).lastUpdateTimestamp, vm.getBlockTimestamp());
    assertEq(
      hub1.getAsset(asset).liquidity,
      liquidityBefore + amount,
      'hub available liquidity after'
    );
    (uint256 drawnAfter, ) = hub1.getAssetOwed(asset);
    assertEq(drawnAfter, drawnBefore, 'hub drawn debt after');
    assertBorrowRateSynced(hub1, asset, 'hub1.add');
    assertHubLiquidity(hub1, asset, 'hub1.add');
    // token balance
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance post-add');
    assertEq(underlying.balanceOf(address(hub1)), amount, 'hub token balance post-add');
  }

  /// @dev single user, 2 spokes, 2 assets, 2 amounts
  // test that assets across different spokes don't affect each others' accounting
  function test_add_fuzz_multi_asset_multi_spoke(
    uint256 assetIdx,
    uint256 amount,
    uint256 amount2
  ) public {
    assetIdx = bound(assetIdx, 0, hub1.getAssetCount() - 4); // Exclude duplicated DAI and usdy
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    uint256 assetIdx2 = assetIdx + 1;

    address asset = hub1.getUnderlyingAddress(assetIdx);
    address asset2 = hub1.getUnderlyingAddress(assetIdx2);

    IERC20 underlying = IERC20(asset);
    IERC20 underlying2 = IERC20(asset2);

    vm.startPrank(address(spoke1));
    underlying.transferFrom(alice, address(hub1), amount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(asset, address(spoke1), amount, amount);

    hub1.add(asset, amount);
    vm.stopPrank();

    vm.startPrank(address(spoke2));
    underlying2.transferFrom(alice, address(hub1), amount2);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(asset2, address(spoke2), amount2, amount2);

    hub1.add(asset2, amount2);
    vm.stopPrank();

    uint256 timestamp = vm.getBlockTimestamp();

    // asset1
    assertEq(
      hub1.getAddedShares(asset),
      hub1.previewAddByAssets(asset, amount),
      'asset addedShares after'
    );
    assertEq(hub1.getAddedAssets(asset), amount, 'asset addedAmount after');
    assertEq(hub1.getAssetLiquidity(asset), amount, 'asset liquidity after');
    assertEq(
      hub1.getAsset(asset).lastUpdateTimestamp,
      timestamp,
      'asset lastUpdateTimestamp after'
    );
    assertEq(
      hub1.getSpokeAddedShares(asset, address(spoke1)),
      hub1.previewAddByAssets(asset, amount),
      'spoke1 addedShares after'
    );
    assertEq(hub1.getSpokeAddedAssets(asset, address(spoke1)), amount, 'spoke1 addedAmount after');
    assertEq(underlying.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user asset1 balance after');
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke1 asset1 balance after');
    assertEq(underlying.balanceOf(address(hub1)), amount, 'hub asset1 balance after');
    assertHubLiquidity(hub1, asset, 'hub1.add');
    // asset2
    assertEq(
      hub1.getAddedShares(asset2),
      hub1.previewAddByAssets(asset2, amount2),
      'asset2 addedShares after'
    );
    assertEq(hub1.getAssetLiquidity(asset2), amount2, 'asset2 liquidity after');
    assertEq(
      hub1.getAsset(asset2).lastUpdateTimestamp,
      timestamp,
      'asset2 lastUpdateTimestamp after'
    );
    assertEq(
      hub1.getSpokeAddedShares(asset2, address(spoke2)),
      hub1.previewAddByAssets(asset2, amount2),
      'spoke2 addedShares after'
    );
    assertEq(
      hub1.getSpokeAddedAssets(asset2, address(spoke2)),
      amount2,
      'spoke2 addedAmount after'
    );
    assertEq(
      underlying2.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount2,
      'user asset2 balance after'
    );
    assertEq(underlying2.balanceOf(address(spoke2)), 0, 'spoke2 asset2 balance after');
    assertEq(underlying2.balanceOf(address(hub1)), amount2, 'hub asset2 balance after');
    assertHubLiquidity(hub1, asset2, 'hub1.add');
  }

  function test_add_revertsWith_InvalidAmount() public {
    address asset = address(tokenList.dai);
    uint256 amount = 0;

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(address(spoke1));
    hub1.add(asset, amount);
  }

  function test_add_revertsWith_InvalidShares() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 drawAmount = daiAmount;

    _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: 365 days * 10
    });
    assertLt(hub1.previewAddByAssets(address(tokenList.dai), daiAmount), daiAmount); // index increased

    // add < 1 share
    uint256 amount = 1;
    assertTrue(hub1.previewAddByAssets(address(tokenList.dai), amount) == 0);

    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), amount);

    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.add(address(tokenList.dai), amount);
    vm.stopPrank();
  }

  function test_add_fuzz_revertsWith_InvalidShares_due_to_index(
    uint256 daiAmount,
    uint256 addAmount,
    uint256 skipTime
  ) public {
    // inflate exchange rate using large values
    daiAmount = bound(daiAmount, 1e20, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 365 days, 100 * 365 days);
    _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: skipTime
    });

    uint256 minAllowedAddedAmount = hub1.previewRemoveByShares(address(tokenList.dai), 1);
    // 1 share converts to > 1 amount
    vm.assume(minAllowedAddedAmount > 1);

    // add < 1 share with an amount > 0
    addAmount = bound(addAmount, 1, minAllowedAddedAmount - 1);

    vm.startPrank(address(spoke1));
    tokenList.dai.transferFrom(alice, address(hub1), addAmount);

    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.add(address(tokenList.dai), addAmount);
    vm.stopPrank();
  }

  function test_add_with_increased_index() public {
    uint256 daiAmount = 100e18;

    _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: daiAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: daiAmount,
      skipTime: 365 days
    });

    (, uint256 premium) = hub1.getAssetOwed(address(tokenList.dai));
    assertEq(premium, 0); // zero premium debt

    uint256 addAmount = 10e18; // this can be 0
    uint256 shares = hub1.previewAddByAssets(address(tokenList.dai), addAmount);
    assertLt(shares, addAmount); // index increased, exch rate > 1

    uint256 spokeAddedSharesBefore = hub1.getSpokeAddedShares(
      address(tokenList.dai),
      address(spoke2)
    );
    uint256 addedAssetsBefore = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2));
    uint256 addedSharesBefore = hub1.getAddedShares(address(tokenList.dai));

    (uint256 drawnBefore, ) = hub1.getAssetOwed(address(tokenList.dai));
    uint256 liquidityBefore = hub1.getAssetLiquidity(address(tokenList.dai));
    vm.expectCall(
      address(irStrategy),
      abi.encodeCall(
        IBasicInterestRateStrategy.calculateInterestRate,
        (address(tokenList.dai), liquidityBefore + addAmount, drawnBefore, 0, 0)
      )
    );

    vm.prank(alice);
    tokenList.dai.approve(address(spoke1), addAmount);

    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(alice, address(hub1), addAmount);

    vm.expectEmit(address(hub1));
    emit IHubBase.Add(address(tokenList.dai), address(spoke2), shares, addAmount);

    hub1.add(address(tokenList.dai), addAmount);
    vm.stopPrank();

    assertEq(
      hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2)),
      addedAssetsBefore + addAmount,
      'spoke addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke2)),
      spokeAddedSharesBefore + shares,
      'spoke addedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub1.getAddedAssets(address(tokenList.dai)),
      addedAssetsBefore + addAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAddedShares(address(tokenList.dai)),
      addedSharesBefore + shares,
      'hub addedShares after'
    );
    assertEq(
      hub1.getAsset(address(tokenList.dai)).liquidity,
      liquidityBefore + addAmount,
      'hub available liquidity after'
    );
    (uint256 drawnAfter, ) = hub1.getAssetOwed(address(tokenList.dai));
    assertEq(drawnAfter, drawnBefore, 'hub drawn debt after');
    assertBorrowRateSynced(hub1, address(tokenList.dai), 'hub1.add');
    assertHubLiquidity(hub1, address(tokenList.dai), 'hub1.add');
  }

  function test_add_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    _addLiquidity(address(tokenList.dai), daiAmount);
    _drawLiquidity(address(tokenList.dai), daiAmount, true);
    assertLt(hub1.previewAddByAssets(address(tokenList.dai), daiAmount), daiAmount); // index increased, exch rate > 1

    uint256 addAmount = 10e18;
    uint256 expectedAddedShares = hub1.previewAddByAssets(address(tokenList.dai), addAmount);

    uint256 addedAssetsBefore = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2));
    uint256 addedSharesBefore = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke2));
    // effective add amount (taking into account potential donation)
    uint256 spokeAddedAmount = calculateEffectiveAddedAssets(
      addAmount,
      hub1.getAddedAssets(address(tokenList.dai)),
      hub1.getAddedShares(address(tokenList.dai))
    );

    Utils.add({
      hub: hub1,
      asset: address(tokenList.dai),
      caller: address(spoke2),
      amount: addAmount,
      user: bob
    });

    assertEq(
      hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2)),
      addedAssetsBefore + spokeAddedAmount,
      'spoke addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke2)),
      addedSharesBefore + expectedAddedShares,
      'spoke addedShares after'
    );
    // Hub and Spoke accounting do not match because of liquidity fees
    assertGe(
      hub1.getAddedAssets(address(tokenList.dai)),
      addedAssetsBefore + spokeAddedAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAddedShares(address(tokenList.dai)),
      addedSharesBefore + expectedAddedShares,
      'hub addedShares after'
    );
    assertHubLiquidity(hub1, address(tokenList.dai), 'hub1.add');
  }

  function test_add_multi_add_minimal_shares() public {
    uint256 amount = 100e18;

    (, uint256 drawnAmount) = _addAndDrawLiquidity({
      hub: hub1,
      asset: address(tokenList.dai),
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: 365 days
    });

    uint256 addedAssetsBefore1 = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke1));
    uint256 addedSharesBefore1 = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1));
    uint256 addedAssetsBefore2 = hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2));
    uint256 addedSharesBefore2 = hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke2));
    uint256 addShares = 1; // minimum for 1 share
    uint256 addAmount = minimumAssetsPerAddedShare(hub1, address(tokenList.dai));
    // effective add amount (taking into account potential donation)
    uint256 spokeAddedAmount = calculateEffectiveAddedAssets(
      addAmount,
      hub1.getAddedAssets(address(tokenList.dai)),
      hub1.getAddedShares(address(tokenList.dai))
    );

    Utils.add({
      hub: hub1,
      asset: address(tokenList.dai),
      caller: address(spoke1),
      amount: addAmount,
      user: bob
    });

    // debt exists
    (uint256 drawn, uint256 premium) = hub1.getAssetOwed(address(tokenList.dai));
    assertGt(drawn, 0);
    (drawn, premium) = hub1.getSpokeOwed(address(tokenList.dai), address(spoke1));
    assertGt(drawn, 0);

    // hub
    assertGe(
      hub1.getAddedAssets(address(tokenList.dai)),
      addedAssetsBefore1 + addedAssetsBefore2 + spokeAddedAmount,
      'hub addedAssets after'
    );
    assertGe(
      hub1.getAddedShares(address(tokenList.dai)),
      addedSharesBefore1 + addShares,
      'hub addedShares after'
    );
    assertEq(
      hub1.getAssetLiquidity(address(tokenList.dai)),
      amount + addAmount - drawnAmount,
      'asset liquidity after'
    );
    assertEq(
      hub1.getAsset(address(tokenList.dai)).lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp after'
    );
    // spoke1
    assertEq(
      hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke1)),
      spokeAddedAmount,
      'spoke1 addedAssets after'
    );
    assertEq(
      hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke1)),
      addShares,
      'spoke1 addedShares after'
    );
    // spoke2
    assertGe(
      hub1.getSpokeAddedAssets(address(tokenList.dai), address(spoke2)),
      addedAssetsBefore2,
      'spoke2 addedAmount after'
    );
    assertEq(
      hub1.getSpokeAddedShares(address(tokenList.dai), address(spoke2)),
      addedSharesBefore2,
      'spoke2 addedShares after'
    );
    // token balance
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      addAmount + amount - drawnAmount,
      'hub token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT + drawnAmount,
      'alice token balance after'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - amount - addAmount,
      'bob token balance after'
    );
    assertHubLiquidity(hub1, address(tokenList.dai), 'hub1.add');
  }

  function test_add_fuzz_single_spoke_multi_add(uint256 amount, uint256 skipTime) public {
    address asset = address(tokenList.dai);
    uint256 numAdds = 5;

    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / numAdds);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    TestAddParams memory params;
    (params.assetAddedShares, params.drawnShares) = _addAndDrawLiquidity({
      hub: hub1,
      asset: asset,
      addUser: bob,
      addSpoke: address(spoke2),
      addAmount: amount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: amount,
      skipTime: skipTime
    });
    vm.assume(hub1.previewAddByAssets(asset, amount) < amount);

    params.drawnAmount = amount;
    params.assetAddedAmount = hub1.previewRemoveByShares(asset, params.assetAddedShares);
    params.availableLiq = amount - params.drawnAmount;
    params.spoke2AddedShares = hub1.getSpokeAddedShares(asset, address(spoke2));
    params.spoke2AddedAmount = hub1.previewRemoveByShares(asset, params.spoke2AddedShares);
    params.aliceBalance = MAX_SUPPLY_AMOUNT + params.drawnAmount;
    params.bobBalance = MAX_SUPPLY_AMOUNT - amount;

    uint256 addShares = 1; // minimum for 1 share
    uint256 addAmount;
    for (uint256 i = 0; i < numAdds; i++) {
      addAmount = minimumAssetsPerAddedShare(hub1, asset);

      // bob add minimal amount
      Utils.add({hub: hub1, asset: asset, caller: address(spoke1), amount: addAmount, user: bob});

      (uint256 drawn, ) = hub1.getAssetOwed(asset);
      assertGt(drawn, 0);
      (drawn, ) = hub1.getSpokeOwed(asset, address(spoke1));
      assertGt(drawn, 0);

      params.availableLiq += addAmount;
      params.assetAddedShares += addShares;
      params.assetAddedAmount = hub1.previewRemoveByShares(asset, params.assetAddedShares);
      params.spoke1AddedShares += addShares;
      params.spoke1AddedAmount = hub1.previewRemoveByShares(asset, params.spoke1AddedShares);
      params.bobBalance -= addAmount;

      // hub
      assertGe(hub1.getAddedAssets(asset), params.assetAddedAmount, 'hub addedAmount after');
      assertGe(hub1.getAddedShares(asset), params.assetAddedShares, 'hub addedShares after');
      assertEq(hub1.getAssetLiquidity(asset), params.availableLiq, 'asset liquidity after');
      assertEq(
        hub1.getAsset(asset).lastUpdateTimestamp,
        vm.getBlockTimestamp(),
        'asset lastUpdateTimestamp after'
      );
      assertHubLiquidity(hub1, asset, 'hub1.add');
      // spoke1
      assertEq(
        hub1.getSpokeAddedAssets(asset, address(spoke1)),
        hub1.previewRemoveByShares(asset, params.spoke1AddedShares),
        'spoke1 addedAmount after'
      );
      assertEq(
        hub1.getSpokeAddedShares(asset, address(spoke1)),
        params.spoke1AddedShares,
        'spoke1 addedShares after'
      );
      // spoke2
      assertEq(
        hub1.getSpokeAddedAssets(asset, address(spoke2)),
        hub1.previewRemoveByShares(asset, params.spoke2AddedShares),
        'spoke2 addedAmount after'
      );
      assertEq(
        hub1.getSpokeAddedShares(asset, address(spoke2)),
        params.spoke2AddedShares,
        'spoke2 addedShares after'
      );
      // token balance
      assertEq(
        tokenList.dai.balanceOf(address(hub1)),
        params.availableLiq,
        'hub token balance after'
      );
      assertEq(tokenList.dai.balanceOf(alice), params.aliceBalance, 'alice token balance after');
      assertEq(tokenList.dai.balanceOf(bob), params.bobBalance, 'bob token balance after');

      skip(randomizer(1 days, 365 days));
    }
  }
}
