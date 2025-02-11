// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubSupplyTest is LiquidityHubBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    vm.prank(address(spoke1));
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    hub.supply(daiAssetId, amount, 0, address(spoke1));
  }

  function test_supply_revertsWith_asset_not_active() public {
    uint256 amount = 100e18;

    _updateActive(daiAssetId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.supply(daiAssetId, amount, 0, alice);
  }

  function test_supply_revertsWith_supply_cap_exceeded() public {
    uint256 amount = 100e18;
    _updateSupplyCap(daiAssetId, address(spoke1), amount - 1);

    vm.expectRevert(TestErrors.SUPPLY_CAP_EXCEEDED);
    hub.supply(daiAssetId, amount, 0, alice);
  }

  function test_supply_revertsWith_supply_cap_exceeded_due_to_interest() public {
    uint256 amount = 1;
    _updateSupplyCap(daiAssetId, address(spoke1), amount);

    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 rate = uint256(10_00).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: 0,
      rate: rate
    });
    skip(365 days);

    vm.expectRevert(TestErrors.SUPPLY_CAP_EXCEEDED);
    hub.supply(daiAssetId, amount, 0, alice);
  }

  function test_supply() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'hub total assets pre-supply');
    // asset
    assertEq(assetData.suppliedShares, 0, 'asset total shares pre-supply');
    assertEq(assetData.availableLiquidity, 0, 'asset availableLiquidity pre-supply');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt pre-supply');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium pre-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex pre-supply');
    assertEq(assetData.baseBorrowRate, 0, 'asset baseBorrowRate pre-supply');
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad pre-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'asset lastUpdateTimestamp pre-supply'
    );
    // spoke
    assertEq(spokeData.suppliedShares, assetData.suppliedShares, 'spoke suppliedShares pre-supply');
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'spoke baseDebt pre-supply');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium pre-supply'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex pre-supply'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad pre-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp pre-supply'
    );

    assertEq(tokenList.dai.balanceOf(alice), MAX_SUPPLY_AMOUNT, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');

    vm.expectEmit(address(hub));
    emit Supply(assetId, address(spoke1), amount);

    vm.prank(address(spoke1));
    hub.supply(assetId, amount, 0, alice);

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'total assets post-supply');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    // spoke
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, 0, 'baseDebt post-supply');
    assertEq(spokeData.outstandingPremium, 0, 'spoke outstandingPremium post-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'spoke baseBorrowIndex post-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-supply');
    assertEq(spokeData.lastUpdateTimestamp, timestamp, 'spoke lastUpdateTimestamp post-supply');
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_supply_fuzz(uint256 assetId, uint256 amount, uint256 riskPremiumRad) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    riskPremiumRad = bound(riskPremiumRad, 0, maxRiskPremiumRad); // no effect on supply

    IERC20 asset = hub.assetsList(assetId);

    vm.expectEmit(address(asset));
    emit Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit Supply(assetId, address(spoke1), amount);

    vm.prank(address(spoke1));
    hub.supply({assetId: assetId, amount: amount, riskPremiumRad: riskPremiumRad, supplier: alice});

    uint256 timestamp = vm.getBlockTimestamp();

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'total assets post-supply');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'baseDebt post-supply');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-supply'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-supply'
    );
    assertEq(spokeData.riskPremiumRad, riskPremiumRad, 'spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-supply'
    );
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
    assetId = bound(assetId, 0, hub.assetCount() - 3); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT);

    uint256 assetId2 = assetId + 1;

    IERC20 asset = hub.assetsList(assetId);
    IERC20 asset2 = hub.assetsList(assetId2);

    vm.expectEmit(address(asset));
    emit Transfer(alice, address(hub), amount);
    vm.expectEmit(address(hub));
    emit Supply(assetId, address(spoke1), amount);

    vm.prank(address(spoke1));
    hub.supply(assetId, amount, 0, alice);

    vm.expectEmit(address(asset2));
    emit Transfer(alice, address(hub), amount2);
    vm.expectEmit(address(hub));
    emit Supply(assetId2, address(spoke2), amount2);

    vm.prank(address(spoke2));
    hub.supply(assetId2, amount2, 0, alice);

    uint256 timestamp = vm.getBlockTimestamp();

    Asset memory assetData = hub.getAsset(assetId);
    Asset memory asset2Data = hub.getAsset(assetId2);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(assetId2, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'total assets post-supply');
    // asset1
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'baseDebt post-supply');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'spoke outstandingPremium post-supply'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'spoke baseBorrowIndex post-supply'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-supply'
    );
    assertEq(asset.balanceOf(alice), MAX_SUPPLY_AMOUNT - amount, 'user token balance post-supply');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(asset.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    // asset2
    assertEq(
      asset2Data.suppliedShares,
      hub.convertToSharesUp(assetId2, amount2),
      'asset2 suppliedShares post-supply'
    );
    assertEq(asset2Data.availableLiquidity, amount2, 'asset2 availableLiquidity post-supply');
    assertEq(asset2Data.baseDebt, 0, 'asset2 baseDebt post-supply');
    assertEq(asset2Data.outstandingPremium, 0, 'asset2 outstandingPremium post-supply');
    assertEq(asset2Data.baseBorrowIndex, WadRayMath.RAY, 'asset2 baseBorrowIndex post-supply');
    assertEq(
      asset2Data.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset2 baseBorrowRate post-supply'
    );
    assertEq(asset2Data.riskPremiumRad, 0, 'asset2 riskPremiumRad post-supply');
    assertEq(asset2Data.lastUpdateTimestamp, timestamp, 'asset2 lastUpdateTimestamp post-supply');
    // spoke2
    assertEq(
      spoke2Data.suppliedShares,
      asset2Data.suppliedShares,
      'spoke2 suppliedShares post-supply'
    );
    assertEq(spoke2Data.baseDebt, asset2Data.baseDebt, 'baseDebt post-supply');
    assertEq(
      spoke2Data.outstandingPremium,
      asset2Data.outstandingPremium,
      'spoke2 outstandingPremium post-supply'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      asset2Data.baseBorrowIndex,
      'spoke2 baseBorrowIndex post-supply'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'spoke2 riskPremiumRad post-supply');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      asset2Data.lastUpdateTimestamp,
      'spoke2 lastUpdateTimestamp post-supply'
    );
    assertEq(
      asset2.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount2,
      'alice token balance post-supply'
    );
    assertEq(asset2.balanceOf(address(spoke2)), 0, 'spoke2 token balance post-supply');
    assertEq(asset2.balanceOf(address(hub)), amount2, 'hub token2 balance post-supply');
  }

  function test_supply_revertsWith_invalid_amount() public {
    uint256 assetId = 0;
    uint256 amount = 0;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_SUPPLY_AMOUNT);
    hub.supply(assetId, amount, 0, alice);
  }

  function test_supply_revertsWith_invalid_shares_amount() public {
    // inflate exchange rate
    uint256 daiAmount = 1e9 * 1e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount;
    uint256 rate = uint256(100_00).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: 0,
      rate: rate
    });
    skip(365 days * 10);

    // trigger exchange rate update
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, 1e18, 0, alice);

    // supply < 1 share
    uint256 amount = 1;
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_SHARES_AMOUNT);
    hub.supply(daiAssetId, amount, 0, alice);
  }

  function test_supply_with_increased_index() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 rate = uint256(10_00).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: 0,
      rate: rate
    });
    skip(365 days);

    Asset memory daiData = hub.getAsset(daiAssetId);
    uint256 accruedBase = daiData.baseDebt.rayMul(rate);
    uint256 initialTotalAssets = hub.getTotalAssets(daiAssetId);

    uint256 supply2Amount = 10e18;
    uint256 expectedSupply2Shares = supply2Amount.toSharesDown(
      hub.getTotalAssets(daiAssetId) + accruedBase,
      daiData.suppliedShares
    );
    uint256 initialSupplyShares = daiData.suppliedShares;

    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke2));

    assertEq(
      hub.getTotalAssets(daiAssetId),
      initialTotalAssets + accruedBase + supply2Amount,
      'hub totalAssets'
    );
    assertEq(
      daiData.suppliedShares,
      expectedSupply2Shares + initialSupplyShares,
      'suppliedShares post-supply'
    );
    assertTrue(
      expectedSupply2Shares < supply2Amount,
      'increased index should lead to lower number of shares'
    );
    assertEq(spokeData.suppliedShares, daiData.suppliedShares, 'spoke suppliedShares post-supply');
  }

  function test_supply_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 riskPremiumRad = uint256(20_00).bpsToRad();
    uint256 rate = uint256(10_00).bpsToRay();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });
    skip(365 days);

    Asset memory daiData = hub.getAsset(daiAssetId);
    uint256 accruedBase = daiData.baseDebt.rayMul(rate);
    uint256 accruedPremium = accruedBase.radMul(riskPremiumRad);
    uint256 initialTotalAssets = hub.getTotalAssets(daiAssetId);

    uint256 supply2Amount = 10e18;
    uint256 expectedSupply2Shares = supply2Amount.toSharesDown(
      hub.getTotalAssets(daiAssetId) + accruedBase + accruedPremium,
      daiData.suppliedShares
    );
    uint256 initialSupplyShares = daiData.suppliedShares;

    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke2));

    assertEq(
      hub.getTotalAssets(daiAssetId),
      initialTotalAssets + accruedBase + accruedPremium + supply2Amount,
      'hub totalAssets'
    );
    assertEq(
      daiData.suppliedShares,
      expectedSupply2Shares + initialSupplyShares,
      'suppliedShares post-supply'
    );
    assertTrue(
      expectedSupply2Shares < supply2Amount,
      'increased index should lead to lower number of shares'
    );
    assertEq(spokeData.suppliedShares, daiData.suppliedShares, 'spoke suppliedShares post-supply');
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
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    // Time flies, no interest acc
    skip(1e4);

    // total assets do not change because no interest acc yet
    uint256 prevTotalAssets = hub.getTotalAssets(assetId);

    // state update due to operation
    // TODO helper for reserve state update
    uint256 spoke2SupplyShares = 1; // minimum for 1 share
    uint256 spoke2SupplyAssets = hub.convertToAssetsDown(assetId, spoke2SupplyShares);

    // bob action with minimal supply shares
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: spoke2SupplyAssets,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(assetId, address(spoke2));

    // hub
    assertEq(
      hub.getTotalAssets(assetId),
      prevTotalAssets + spoke2SupplyAssets,
      'final total assets'
    );
    // asset
    assertEq(assetData.suppliedShares, amount + spoke2SupplyShares, 'asset final suppliedShares');
    assertEq(
      assetData.availableLiquidity,
      prevTotalAssets + spoke2SupplyAssets,
      'asset final availableLiquidity'
    );
    assertEq(assetData.baseDebt, 0, 'asset final baseDebt');
    assertEq(assetData.outstandingPremium, 0, 'asset final outstandingPremium');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset final baseBorrowIndex');
    assertEq(assetData.baseBorrowRate, uint256(5_00).bpsToRay(), 'asset final baseBorrowRate');
    assertEq(assetData.riskPremiumRad, 0, 'asset final riskPremiumRad');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset final lastUpdateTimestamp');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'final spoke suppliedShares'
    );
    assertEq(spokeData.baseDebt, 0, 'final spoke baseDebt');
    assertEq(spokeData.outstandingPremium, 0, 'final spoke outstandingPremium');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'final spoke baseBorrowIndex');
    assertEq(spokeData.riskPremiumRad, 0, 'final spoke riskPremiumRad');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'final spoke lastUpdateTimestamp'
    );
    // spoke2
    assertEq(spoke2Data.suppliedShares, spoke2SupplyShares, 'final spoke2 totalShares');
    assertEq(spoke2Data.baseDebt, 0, 'final spoke2 baseDebt');
    assertEq(spoke2Data.outstandingPremium, 0, 'spoke2 outstandingPremium');
    assertEq(spoke2Data.baseBorrowIndex, WadRayMath.RAY, 'spoke2 baseBorrowIndex');
    assertEq(spoke2Data.riskPremiumRad, 0, 'spoke2 riskPremiumRad');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke2 lastUpdateTimestamp'
    );
    // users
    assertEq(
      tokenList.dai.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - amount,
      'alice token balance post-supply'
    );
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT - spoke2SupplyAssets,
      'bob token balance post-supply'
    );
  }

  function test_supply_fuzz_single_spoke_multi_supply(uint256 assetId, uint256 amount) public {
    assetId = bound(assetId, 0, hub.assetCount() - 2); // Exclude duplicated DAI
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);

    uint256 timestamp = vm.getBlockTimestamp();

    IERC20 asset = hub.assetsList(assetId);

    // initial supply
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    TestSupplyUserParams memory p = TestSupplyUserParams({
      totalAssets: amount,
      suppliedShares: amount,
      userAssets: 0,
      userShares: 0
    });
    Asset memory assetData;
    SpokeData memory spokeData;

    uint256 runningBalance = asset.balanceOf(alice);

    for (uint256 i = 0; i < 5; i++) {
      assetData = hub.getAsset(assetId);
      spokeData = hub.getSpoke(assetId, address(spoke1));

      // hub
      assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'total assets post-supply');
      // asset
      assertEq(assetData.suppliedShares, p.suppliedShares, 'asset suppliedShares post-supply');
      assertEq(assetData.availableLiquidity, p.totalAssets, 'asset availableLiquidity post-supply');
      assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
      assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
      assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
      assertEq(
        assetData.baseBorrowRate,
        uint256(5_00).bpsToRay(),
        'asset baseBorrowRate post-supply'
      );
      assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
      assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
      // spoke
      assertEq(
        spokeData.suppliedShares,
        assetData.suppliedShares,
        'spoke suppliedShares post-supply'
      );
      assertEq(spokeData.baseDebt, 0, 'baseDebt post-supply');
      assertEq(spokeData.outstandingPremium, 0, 'spoke outstandingPremium post-supply');
      assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'spoke baseBorrowIndex post-supply');
      assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-supply');
      assertEq(
        spokeData.lastUpdateTimestamp,
        assetData.lastUpdateTimestamp,
        'spoke lastUpdateTimestamp post-supply'
      );
      assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
      assertEq(
        asset.balanceOf(address(hub)),
        hub.getTotalAssets(assetId),
        'hub token balance post-supply'
      );
      assertEq(asset.balanceOf(alice), runningBalance, 'user token balance post-supply');

      // time flies
      uint256 elapsedTime = randomizer(1 days, 30 days, i);
      skip(elapsedTime);

      p.userShares = 1; // minimum for 1 share
      p.userAssets = p.userShares.toAssetsUp(hub.getTotalAssets(assetId), assetData.suppliedShares);

      p.totalAssets += p.userAssets;
      p.suppliedShares += p.userShares;

      // force update with action from separate user
      Utils.supply({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke1),
        amount: p.userAssets,
        riskPremiumRad: 0,
        user: alice,
        to: address(spoke1)
      });

      runningBalance -= p.userAssets;
    }

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'total assets post-supply');
    // asset
    assertEq(assetData.suppliedShares, p.suppliedShares, 'asset suppliedShares post-supply');
    assertEq(assetData.availableLiquidity, p.totalAssets, 'asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'asset riskPremiumRad post-supply');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'asset lastUpdateTimestamp post-supply');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, 0, 'baseDebt post-supply');
    assertEq(spokeData.outstandingPremium, 0, 'spoke outstandingPremium post-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'spoke baseBorrowIndex post-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'spoke lastUpdateTimestamp post-supply'
    );
    assertEq(asset.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(
      asset.balanceOf(address(hub)),
      hub.getTotalAssets(assetId),
      'hub token balance post-supply'
    );
    assertEq(asset.balanceOf(alice), runningBalance, 'user token balance post-supply');
  }
}
