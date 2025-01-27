// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  uint256 daiAssetId = 2;
  uint256 wbtcAssetId = 3;

  uint256 spoke1RiskPremiumRad = uint256(50_00).bpsToRad();
  uint256 spoke2RiskPremiumRad = uint256(20_00).bpsToRad();
  uint256 spoke3RiskPremiumRad = uint256(30_00).bpsToRad();

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    deal(address(tokenList.dai), address(spoke1), amount);
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
    hub.supply(daiAssetId, amount, 0, USER1);
  }

  function test_supply_revertsWith_supply_cap_exceeded() public {
    uint256 amount = 100e18;
    _updateSupplyCap(daiAssetId, address(spoke1), amount - 1);

    vm.expectRevert(TestErrors.SUPPLY_CAP_EXCEEDED);
    hub.supply(daiAssetId, amount, 0, USER1);
  }

  function test_supply() public {
    uint256 assetId = daiAssetId;
    uint256 amount = 100e18;

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'wrong hub total assets pre-supply');
    // asset
    assertEq(assetData.suppliedShares, 0, 'wrong asset total shares pre-supply');
    assertEq(assetData.availableLiquidity, 0, 'wrong asset availableLiquidity pre-supply');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt pre-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium pre-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex pre-supply');
    assertEq(assetData.baseBorrowRate, 0, 'wrong asset baseBorrowRate pre-supply');
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad pre-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong asset lastUpdateTimestamp pre-supply'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares pre-supply'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong spoke baseDebt pre-supply');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium pre-supply'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex pre-supply'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad pre-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp pre-supply'
    );

    deal(address(tokenList.dai), USER1, amount);
    vm.prank(USER1);
    tokenList.dai.approve(address(hub), amount);

    assertEq(tokenList.dai.balanceOf(USER1), amount, 'wrong user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    deal(address(tokenList.dai), USER1, amount);
    vm.prank(USER1);
    tokenList.dai.approve(address(hub), amount);

    vm.startPrank(address(spoke1));
    vm.expectEmit(address(hub));
    emit Supply(assetId, address(spoke1), amount);
    hub.supply(assetId, amount, 0, USER1);
    vm.stopPrank();

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong total assets post-supply');
    // asset
    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong total assets post-supply');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'wrong asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-supply'
    );
    // spoke
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-supply'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'wrong spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, 0, 'wrong baseDebt post-supply');
    assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium post-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke baseBorrowIndex post-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      timestamp,
      'wrong spoke lastUpdateTimestamp post-supply'
    );
    assertEq(tokenList.dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_supply_fuzz(uint256 assetId, address user, uint256 amount) public {
    vm.assume(user != address(hub) && user != address(0) && user != address(spoke1));
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    IERC20 asset = hub.assetsList(assetId);

    deal(address(asset), user, amount);

    // initial supply
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: user,
      onBehalfOf: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong total assets post-supply');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'wrong asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-supply'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong baseDebt post-supply');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium post-supply'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex post-supply'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp post-supply'
    );
    assertEq(asset.balanceOf(user), 0, 'wrong user token balance post-supply');
    assertEq(asset.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(asset.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
  }

  function test_supply_events_fuzz(
    uint256 assetId,
    address spoke,
    uint256 amount,
    address onBehalfOf
  ) public {
    vm.assume(spoke != address(hub) && spoke != address(0) && onBehalfOf != address(0));

    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    hub.addSpoke(
      assetId,
      DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max}),
      spoke
    );

    IERC20 asset = hub.assetsList(assetId);
    deal(address(asset), USER1, amount);
    vm.prank(USER1);
    asset.approve(address(hub), amount);

    vm.startPrank(spoke);
    vm.expectEmit(address(asset));
    emit Transfer(USER1, address(hub), amount);
    vm.expectEmit(address(hub));
    emit Supply(assetId, spoke, amount);
    hub.supply(assetId, amount, 0, USER1);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_amount() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 0;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_AMOUNT);
    hub.supply(assetId, amount, 0, USER1);
  }

  function test_supply_revertsWith_invalid_shares_amount() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 1;

    deal(address(dai), USER1, amount);
    vm.prank(USER1);
    dai.approve(address(hub), amount);

    // update storage slots to create 0 shares calc
    bytes32 baseSlot = keccak256(abi.encode(uint256(assetId), uint256(0))); // key: assetId, slot: 0, ie _assets mapping, dai assetId key
    vm.store(address(hub), bytes32(uint256(baseSlot) + 1), bytes32(uint256(1))); // suppliedShares slot
    vm.store(address(hub), bytes32(uint256(baseSlot) + 2), bytes32(uint256(WadRayMath.RAD))); // availableLiquidity slot

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_SHARES_AMOUNT);
    hub.supply(assetId, amount, 0, USER1);
  }

  /// @dev spoke1 (USER1) supplies dai, spoke2 (USER2) supplies weth, spoke1 (USER1) draws dai
  function _setUpIncreasedIndex(
    uint256 daiAmount,
    uint256 riskPremiumRad,
    uint256 wethAmount,
    uint256 drawAmount
  ) internal returns (uint256 rate) {
    rate = uint256(10_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(tokenList.dai), USER2, daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: USER1,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      onBehalfOf: address(spoke1)
    });
  }

  function test_supply_with_increased_index() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;

    uint256 rate = _setUpIncreasedIndex(daiAmount, 0, wethAmount, drawAmount);
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

    deal(address(tokenList.dai), USER2, supply2Amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke2));

    assertEq(
      hub.getTotalAssets(daiAssetId),
      initialTotalAssets + accruedBase + supply2Amount,
      'wrong hub totalAssets'
    );
    assertEq(
      daiData.suppliedShares,
      expectedSupply2Shares + initialSupplyShares,
      'wrong suppliedShares post-supply'
    );
    assertTrue(
      expectedSupply2Shares < supply2Amount,
      'increased index should lead to lower number of shares'
    );
    assertEq(
      spokeData.suppliedShares,
      daiData.suppliedShares,
      'wrong spoke suppliedShares post-supply'
    );
  }

  function test_supply_with_increased_index_with_premium() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 riskPremiumRad = uint256(20_00).bpsToRad();

    uint256 rate = _setUpIncreasedIndex(daiAmount, riskPremiumRad, wethAmount, drawAmount);
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

    deal(address(tokenList.dai), USER2, supply2Amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke2));

    assertEq(
      hub.getTotalAssets(daiAssetId),
      initialTotalAssets + accruedBase + accruedPremium + supply2Amount,
      'wrong hub totalAssets'
    );
    assertEq(
      daiData.suppliedShares,
      expectedSupply2Shares + initialSupplyShares,
      'wrong suppliedShares post-supply'
    );
    assertTrue(
      expectedSupply2Shares < supply2Amount,
      'increased index should lead to lower number of shares'
    );
    assertEq(
      spokeData.suppliedShares,
      daiData.suppliedShares,
      'wrong spoke suppliedShares post-supply'
    );
  }

  function test_supply_multiple() public {
    uint256 assetId = daiAssetId; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'wrong hub total assets pre-supply');
    // asset
    assertEq(assetData.suppliedShares, 0, 'wrong asset total shares pre-supply');
    assertEq(assetData.availableLiquidity, 0, 'wrong asset availableLiquidity pre-supply');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt pre-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium pre-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex pre-supply');
    assertEq(assetData.baseBorrowRate, 0, 'wrong asset baseBorrowRate pre-supply');
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad pre-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp pre-supply'
    );
    // spoke
    assertEq(spokeData.suppliedShares, 0, 'wrong spoke suppliedShares pre-supply');
    assertEq(spokeData.baseDebt, 0, 'wrong spoke baseDebt pre-supply');
    assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium pre-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke baseBorrowIndex pre-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad pre-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      timestamp,
      'wrong spoke lastUpdateTimestamp pre-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    deal(address(tokenList.dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong total assets post-supply');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'wrong asset suppliedShares post-supply'
    );
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity post-supply');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-supply'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'wrong spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, 0, 'wrong baseDebt post-supply');
    assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium post-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke baseBorrowIndex post-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      timestamp,
      'wrong spoke lastUpdateTimestamp post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');

    // Time flies, no interest acc
    skip(1e4);

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong total assets post-skip');
    // asset
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity post-skip');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-skip');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-skip');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex post-skip');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-skip'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-skip');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'wrong asset lastUpdateTimestamp post-skip');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'wrong spoke total shares post-skip'
    );
    assertEq(spokeData.baseDebt, 0, 'wrong spoke drawn shares post-skip');
    assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium post-skip');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke baseBorrowIndex post-skip');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-skip');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp post-skip'
    );

    // total assets do not change because no interest acc yet
    uint256 prevTotalAssets = hub.getTotalAssets(assetId);

    // state update due to operation
    // TODO helper for reserve state update
    uint256 spoke2SupplyShares = 1; // minimum for 1 share
    uint256 spoke2SupplyAssets = hub.convertToAssetsDown(assetId, spoke2SupplyShares);

    uint256 newTotalAssets = amount.toAssetsDown(
      hub.getTotalAssets(assetId) + spoke2SupplyAssets,
      assetData.suppliedShares + spoke2SupplyShares
    );

    deal(address(tokenList.dai), USER2, spoke2SupplyAssets);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: spoke2SupplyAssets,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(assetId, address(spoke2));

    // hub
    assertEq(
      hub.getTotalAssets(assetId),
      prevTotalAssets + spoke2SupplyAssets,
      'wrong final total assets'
    );
    // asset
    assertEq(
      assetData.suppliedShares,
      amount + spoke2SupplyShares,
      'wrong asset final suppliedShares'
    );
    assertEq(
      assetData.availableLiquidity,
      prevTotalAssets + spoke2SupplyAssets,
      'wrong asset final availableLiquidity'
    );
    assertEq(assetData.baseDebt, 0, 'wrong asset final baseDebt');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset final outstandingPremium');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset final baseBorrowIndex');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset final baseBorrowRate'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset final riskPremiumRad');
    assertEq(assetData.lastUpdateTimestamp, timestamp, 'wrong asset final lastUpdateTimestamp');
    // spoke
    assertEq(
      spokeData.suppliedShares,
      hub.convertToSharesDown(assetId, amount),
      'wrong final spoke suppliedShares'
    );
    assertEq(spokeData.baseDebt, 0, 'wrong final spoke baseDebt');
    assertEq(spokeData.outstandingPremium, 0, 'wrong final spoke outstandingPremium');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong final spoke baseBorrowIndex');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong final spoke riskPremiumRad');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong final spoke lastUpdateTimestamp'
    );
    // spoke2
    assertEq(spoke2Data.suppliedShares, spoke2SupplyShares, 'wrong final spoke2 totalShares');
    assertEq(spoke2Data.baseDebt, 0, 'wrong final spoke2 baseDebt');
    assertEq(spoke2Data.outstandingPremium, 0, 'wrong spoke2 outstandingPremium');
    assertEq(spoke2Data.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke2 baseBorrowIndex');
    assertEq(spoke2Data.riskPremiumRad, 0, 'wrong spoke2 riskPremiumRad');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke2 lastUpdateTimestamp'
    );
    // users
    assertEq(tokenList.dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(USER2), 0, 'wrong user token balance post-supply');
  }

  struct TestSupplyUserParams {
    uint256 totalAssets;
    uint256 suppliedShares;
    uint256 userAssets;
    uint256 userShares;
  }

  function test_supply_fuzz_multi(uint256 assetId, address user, uint256 amount) public {
    vm.assume(user != address(hub) && user != address(spoke1) && user != address(0));
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    uint256 timestamp = vm.getBlockTimestamp();

    IERC20 asset = hub.assetsList(assetId);

    deal(address(asset), USER1, amount);
    // initial supply
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    TestSupplyUserParams memory p = TestSupplyUserParams({
      totalAssets: amount,
      suppliedShares: amount,
      userAssets: 0,
      userShares: 0
    });
    Asset memory assetData;
    SpokeData memory spokeData;

    for (uint256 i = 0; i < 5; i++) {
      assetData = hub.getAsset(assetId);
      spokeData = hub.getSpoke(assetId, address(spoke1));

      // hub
      assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'wrong total assets post-supply');
      // asset
      assertEq(
        assetData.suppliedShares,
        p.suppliedShares,
        'wrong asset suppliedShares post-supply'
      );
      assertEq(
        assetData.availableLiquidity,
        p.totalAssets,
        'wrong asset availableLiquidity post-supply'
      );
      assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-supply');
      assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-supply');
      assertEq(
        assetData.baseBorrowIndex,
        WadRayMath.RAY,
        'wrong asset baseBorrowIndex post-supply'
      );
      assertEq(
        assetData.baseBorrowRate,
        uint256(5_00).bpsToRay(),
        'wrong asset baseBorrowRate post-supply'
      );
      assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
      assertEq(
        assetData.lastUpdateTimestamp,
        timestamp,
        'wrong asset lastUpdateTimestamp post-supply'
      );
      // spoke
      assertEq(
        spokeData.suppliedShares,
        assetData.suppliedShares,
        'wrong spoke suppliedShares post-supply'
      );
      assertEq(spokeData.baseDebt, 0, 'wrong baseDebt post-supply');
      assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium post-supply');
      assertEq(
        spokeData.baseBorrowIndex,
        WadRayMath.RAY,
        'wrong spoke baseBorrowIndex post-supply'
      );
      assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-supply');
      assertEq(
        spokeData.lastUpdateTimestamp,
        assetData.lastUpdateTimestamp,
        'wrong spoke lastUpdateTimestamp post-supply'
      );
      assertEq(asset.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
      assertEq(
        asset.balanceOf(address(hub)),
        hub.getTotalAssets(assetId),
        'wrong hub token balance post-supply'
      );
      assertEq(asset.balanceOf(USER1), 0, 'wrong user token balance post-supply');

      // time flies
      uint256 elapsedTime = randomizer(1 days, 30 days, i);
      skip(elapsedTime);

      p.userShares = 1; // minimum for 1 share
      p.userAssets = p.userShares.toAssetsUp(hub.getTotalAssets(assetId), assetData.suppliedShares);

      p.totalAssets += p.userAssets;
      p.suppliedShares += p.userShares;

      deal(address(asset), user, p.userAssets);
      // force update with action
      Utils.supply({
        hub: hub,
        assetId: assetId,
        spoke: address(spoke1),
        amount: p.userAssets,
        riskPremiumRad: 0,
        user: user,
        onBehalfOf: address(spoke1)
      });
    }

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), p.totalAssets, 'wrong total assets post-supply');
    // asset
    assertEq(assetData.suppliedShares, p.suppliedShares, 'wrong asset suppliedShares post-supply');
    assertEq(
      assetData.availableLiquidity,
      p.totalAssets,
      'wrong asset availableLiquidity post-supply'
    );
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-supply');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-supply');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex post-supply');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-supply'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-supply');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-supply'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares post-supply'
    );
    assertEq(spokeData.baseDebt, 0, 'wrong baseDebt post-supply');
    assertEq(spokeData.outstandingPremium, 0, 'wrong spoke outstandingPremium post-supply');
    assertEq(spokeData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke baseBorrowIndex post-supply');
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-supply');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp post-supply'
    );
    assertEq(asset.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(
      asset.balanceOf(address(hub)),
      hub.getTotalAssets(assetId),
      'wrong hub token balance post-supply'
    );
    assertEq(asset.balanceOf(USER1), 0, 'wrong user token balance post-supply');
  }

  /// User makes a first supply, which increases overtime as yield accrues
  // TODO: to be fixed, there is precision loss
  // TODO: after draw is completed. Draw some debt and skip time to change index
  function test_supply_fuzz_index_increase(uint256 assetId, address user, uint256 amount) public {
    vm.skip(true);
  }

  function test_withdraw() public {
    uint256 amount = 100e18;

    // User supply
    deal(address(tokenList.dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(daiAssetId);
    SpokeData memory spokeData = hub.getSpoke(daiAssetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), amount, 'wrong hub total assets pre-withdraw');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, amount),
      'wrong asset total shares pre-withdraw'
    );
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity pre-withdraw');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt pre-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium pre-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex pre-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate pre-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad pre-withdraw');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp pre-withdraw'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares pre-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong spoke baseDebt pre-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium pre-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex pre-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad pre-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp pre-withdraw'
    );
    // dai
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    assertEq(tokenList.dai.balanceOf(USER1), 0, 'wrong user token balance pre-withdraw');

    vm.expectEmit(address(tokenList.dai));
    emit Transfer(address(hub), USER1, amount);
    vm.expectEmit(address(hub));
    emit Withdraw(daiAssetId, address(spoke1), USER1, amount);

    vm.startPrank(address(spoke1));
    hub.withdraw({assetId: daiAssetId, to: USER1, amount: amount, riskPremiumRad: 0});
    vm.stopPrank();

    assetData = hub.getAsset(daiAssetId);
    spokeData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), 0, 'wrong hub total assets post-withdraw');
    // asset
    assertEq(assetData.suppliedShares, 0, 'wrong asset total shares post-withdraw');
    assertEq(assetData.availableLiquidity, 0, 'wrong asset availableLiquidity post-withdraw');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-withdraw');
    assertEq(
      assetData.baseBorrowIndex,
      WadRayMath.RAY,
      'wrong asset baseBorrowIndex post-withdraw'
    );
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-withdraw');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-withdraw'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares post-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong spoke baseDebt post-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp post-withdraw'
    );
    // dai
    assertEq(
      tokenList.dai.balanceOf(address(spoke1)),
      0,
      'wrong spoke token balance post-withdraw'
    );
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    assertEq(tokenList.dai.balanceOf(USER1), amount, 'wrong user token balance post-withdraw');
  }

  function test_withdraw_fuzz(uint256 assetId, address user, uint256 amount) public {
    vm.assume(user != address(0) && user != address(hub) && user != address(spoke1));
    assetId = bound(assetId, 0, hub.assetCount() - 1);
    amount = bound(amount, 1, type(uint128).max);

    IERC20 asset = hub.assetsList(assetId);

    // User supply
    deal(address(asset), user, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: user,
      onBehalfOf: address(spoke1)
    });

    Asset memory assetData = hub.getAsset(assetId);
    SpokeData memory spokeData = hub.getSpoke(assetId, address(spoke1));

    uint256 timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(assetId), amount, 'wrong hub total assets pre-withdraw');
    // asset
    assertEq(
      assetData.suppliedShares,
      hub.convertToSharesUp(assetId, amount),
      'wrong asset total shares pre-withdraw'
    );
    assertEq(assetData.availableLiquidity, amount, 'wrong asset availableLiquidity pre-withdraw');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt pre-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium pre-withdraw');
    assertEq(assetData.baseBorrowIndex, WadRayMath.RAY, 'wrong asset baseBorrowIndex pre-withdraw');
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate pre-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad pre-withdraw');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp pre-withdraw'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares pre-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong spoke baseDebt pre-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium pre-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex pre-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad pre-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp pre-withdraw'
    );
    // asset
    assertEq(asset.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    assertEq(asset.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    assertEq(asset.balanceOf(user), 0, 'wrong user token balance pre-withdraw');

    vm.expectEmit(address(asset));
    emit Transfer(address(hub), user, amount);

    vm.expectEmit(address(hub));
    emit Withdraw(assetId, address(spoke1), user, amount);

    Utils.withdraw({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      to: user
    });

    assetData = hub.getAsset(assetId);
    spokeData = hub.getSpoke(assetId, address(spoke1));

    // hub
    assertEq(hub.getTotalAssets(assetId), 0, 'wrong hub total assets post-withdraw');
    // asset
    assertEq(assetData.suppliedShares, 0, 'wrong asset total shares post-withdraw');
    assertEq(assetData.availableLiquidity, 0, 'wrong asset availableLiquidity post-withdraw');
    assertEq(assetData.baseDebt, 0, 'wrong asset baseDebt post-withdraw');
    assertEq(assetData.outstandingPremium, 0, 'wrong asset outstandingPremium post-withdraw');
    assertEq(
      assetData.baseBorrowIndex,
      WadRayMath.RAY,
      'wrong asset baseBorrowIndex post-withdraw'
    );
    assertEq(
      assetData.baseBorrowRate,
      uint256(5_00).bpsToRay(),
      'wrong asset baseBorrowRate post-withdraw'
    );
    assertEq(assetData.riskPremiumRad, 0, 'wrong asset riskPremiumRad post-withdraw');
    assertEq(
      assetData.lastUpdateTimestamp,
      timestamp,
      'wrong asset lastUpdateTimestamp post-withdraw'
    );
    // spoke
    assertEq(
      spokeData.suppliedShares,
      assetData.suppliedShares,
      'wrong spoke suppliedShares post-withdraw'
    );
    assertEq(spokeData.baseDebt, assetData.baseDebt, 'wrong spoke baseDebt post-withdraw');
    assertEq(
      spokeData.outstandingPremium,
      assetData.outstandingPremium,
      'wrong spoke outstandingPremium post-withdraw'
    );
    assertEq(
      spokeData.baseBorrowIndex,
      assetData.baseBorrowIndex,
      'wrong spoke baseBorrowIndex post-withdraw'
    );
    assertEq(spokeData.riskPremiumRad, 0, 'wrong spoke riskPremiumRad post-withdraw');
    assertEq(
      spokeData.lastUpdateTimestamp,
      assetData.lastUpdateTimestamp,
      'wrong spoke lastUpdateTimestamp post-withdraw'
    );
    // asset
    assertEq(asset.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-withdraw');
    assertEq(asset.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    assertEq(asset.balanceOf(user), amount, 'wrong user token balance post-withdraw');
  }

  function test_withdraw_all_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 riskPremiumRad = uint256(20_00).bpsToRad();
    uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

    uint256 rate = _setUpIncreasedIndex(daiAmount, riskPremiumRad, wethAmount, drawAmount);

    skip(365 days);
    Asset memory daiData = hub.getAsset(daiAssetId);

    uint256 accruedBase = daiData.baseDebt.rayMul(rate);
    uint256 initialAvailableLiquidity = daiData.availableLiquidity;
    uint256 initialSupplyShares = daiData.suppliedShares;

    uint256 supply2Amount = 10e18;
    uint256 expectedSupply2Shares = supply2Amount.toSharesDown(
      hub.getTotalAssets(daiAssetId) + accruedBase,
      daiData.suppliedShares
    );

    // USER2 supplies more DAI to trigger accrual
    deal(address(tokenList.dai), USER2, supply2Amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: supply2Amount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    daiData = hub.getAsset(daiAssetId);

    uint256 restoreAmount = daiData.baseDebt + daiData.outstandingPremium;
    uint256 newBaseBorrowIndex = WadRayMath.RAY +
      WadRayMath.RAY.rayMul(
        MathUtils.calculateLinearInterest(daiData.baseBorrowRate, uint40(lastUpdateTimestamp)) -
          WadRayMath.RAY
      );

    // USER1 restores all debt including accrual
    deal(address(tokenList.dai), USER1, restoreAmount);
    vm.prank(USER1);
    tokenList.dai.approve(address(hub), restoreAmount);
    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: USER1});

    daiData = hub.getAsset(daiAssetId);
    assertEq(
      daiData.availableLiquidity,
      initialAvailableLiquidity + restoreAmount + supply2Amount,
      'wrong dai availableLiquidity'
    );

    // USER2 withdraws all liquidity with interest
    vm.prank(address(spoke2));
    hub.withdraw({
      assetId: daiAssetId,
      to: USER2,
      amount: daiData.availableLiquidity,
      riskPremiumRad: 0
    });

    // USER2 withdraws all liquidity with interest
    assertEq(tokenList.dai.balanceOf(USER2), daiData.availableLiquidity, 'wrong user2 dai balance');

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    SpokeData memory spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(daiAssetId), 0, 'wrong hub totalAssets');
    assertEq(daiData.suppliedShares, 0, 'wrong dai suppliedShares');
    assertEq(daiData.availableLiquidity, 0, 'wrong dai availableLiquidity');
    assertEq(daiData.baseDebt, 0, 'wrong dai baseDebt');
    assertEq(daiData.outstandingPremium, 0, 'wrong dai outstandingPremium');
    assertEq(daiData.baseBorrowIndex, newBaseBorrowIndex, 'wrong dai baseBorrowIndex');
    assertEq(daiData.baseBorrowRate, rate, 'wrong dai baseBorrowRate');
    assertEq(daiData.riskPremiumRad, 0, 'wrong dai riskPremiumRad');
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'wrong dai lastUpdateTimestamp');
    // spoke1
    assertEq(spoke1DaiData.suppliedShares, 0, 'wrong spoke1 suppliedShares');
    assertEq(spoke1DaiData.baseDebt, 0, 'wrong spoke1 baseDebt');
    assertEq(spoke1DaiData.outstandingPremium, 0, 'wrong spoke1 outstandingPremium');
    assertEq(spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'wrong spoke1 baseBorrowIndex');
    assertEq(spoke1DaiData.riskPremiumRad, 0, 'wrong spoke1 riskPremiumRad');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong spoke1 lastUpdateTimestamp'
    );
    // spoke2
    assertEq(spoke2DaiData.suppliedShares, 0, 'wrong spoke2 suppliedShares');
    assertEq(spoke2DaiData.baseDebt, 0, 'wrong spoke2 baseDebt');
    assertEq(spoke2DaiData.outstandingPremium, 0, 'wrong spoke2 outstandingPremium');
    assertEq(spoke2DaiData.baseBorrowIndex, WadRayMath.RAY, 'wrong spoke2 baseBorrowIndex');
    assertEq(spoke2DaiData.riskPremiumRad, 0, 'wrong spoke2 riskPremiumRad');
    assertEq(
      spoke2DaiData.lastUpdateTimestamp,
      lastUpdateTimestamp,
      'wrong spoke2 lastUpdateTimestamp'
    );
    // dai - all to USER1
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai balance');
    assertEq(tokenList.dai.balanceOf(USER1), 0, 'wrong USER1 dai balance');
  }

  // TODO: test with restore partial amount, check premium paid off first

  function test_withdraw_revertsWith_zero_supplied() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 1;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(assetId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 assetId = daiAssetId; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(tokenList.dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, to: USER1, amount: amount + 1, riskPremiumRad: 0});

    uint256 timestamp = vm.getBlockTimestamp();

    // advance time, but no accumulation
    skip(1e18);
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, to: USER1, amount: amount + 1, riskPremiumRad: 0});
  }

  function test_withdraw_revertsWith_not_available_liquidity() public {
    uint256 amount = 100e18;

    // User supply
    deal(address(tokenList.dai), address(spoke1), amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: address(spoke1),
      onBehalfOf: address(spoke1)
    });

    // spoke1 draw all of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      to: address(spoke1),
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(daiAssetId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_asset_not_active() public {
    uint256 amount = 100e18;

    // User supply
    deal(address(tokenList.dai), address(spoke1), amount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke1),
      amount: amount,
      riskPremiumRad: 0,
      user: address(spoke1),
      onBehalfOf: address(spoke1)
    });

    _updateActive(daiAssetId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.withdraw(daiAssetId, address(spoke1), amount, 0);
  }

  function test_draw_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;

    // spoke1, USER1 supply weth
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2, USER2 supply dai
    deal(address(tokenList.dai), USER2, daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    vm.expectEmit(address(hub));
    emit Draw(daiAssetId, address(spoke1), USER1, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, to: USER1, amount: drawAmount, riskPremiumRad: 0});

    Asset memory wethData = hub.getAsset(wethAssetId);
    Asset memory daiData = hub.getAsset(daiAssetId);

    SpokeData memory spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'wrong hub weth total assets post-draw');
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'wrong hub dai total assets post-draw');
    // weth
    assertEq(
      wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'wrong hub weth suppliedShares post-draw'
    );
    assertEq(wethData.baseDebt, 0, 'wrong hub weth baseDebt post-draw');
    assertEq(wethData.outstandingPremium, 0, 'wrong hub weth outstandingPremium post-draw');
    assertEq(wethData.baseBorrowIndex, WadRayMath.RAY, 'wrong hub weth baseBorrowIndex post-draw');
    assertEq(wethData.riskPremiumRad, 0, 'wrong hub weth riskPremiumRad post-draw');
    assertEq(
      wethData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong hub weth lastUpdateTimestamp post-draw'
    );
    // dai
    assertEq(
      daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'wrong hub dai suppliedShares post-draw'
    );
    assertEq(daiData.baseDebt, drawAmount, 'wrong hub dai baseDebt post-draw');
    assertEq(daiData.outstandingPremium, 0, 'wrong hub dai outstandingPremium post-draw');
    assertEq(daiData.baseBorrowIndex, WadRayMath.RAY, 'wrong hub dai baseBorrowIndex post-draw');
    assertEq(daiData.riskPremiumRad, 0, 'wrong hub dai riskPremiumRad post-draw');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong hub dai lastUpdateTimestamp post-draw'
    );
    // spoke1 weth
    assertEq(
      spoke1WethData.suppliedShares,
      wethData.suppliedShares,
      'wrong hub spoke1 suppliedShares post-draw'
    );
    assertEq(spoke1WethData.baseDebt, wethData.baseDebt, 'wrong hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1WethData.outstandingPremium,
      wethData.outstandingPremium,
      'wrong hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1WethData.baseBorrowIndex,
      wethData.baseBorrowIndex,
      'wrong hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1WethData.riskPremiumRad, 0, 'wrong hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1WethData.lastUpdateTimestamp,
      wethData.lastUpdateTimestamp,
      'wrong hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke1 dai
    assertEq(spoke1DaiData.suppliedShares, 0, 'wrong hub spoke1 suppliedShares post-draw');
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'wrong hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'wrong hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1DaiData.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'wrong hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1DaiData.riskPremiumRad, 0, 'wrong hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'wrong hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke2
    assertEq(
      spoke2Data.suppliedShares,
      daiData.suppliedShares,
      'wrong hub spoke2 suppliedShares post-draw'
    );
    assertEq(spoke2Data.baseDebt, 0, 'wrong hub spoke2 baseDebt post-draw');
    assertEq(
      spoke2Data.outstandingPremium,
      daiData.outstandingPremium,
      'wrong hub spoke2 outstandingPremium post-draw'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'wrong hub spoke2 baseBorrowIndex post-draw'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'wrong hub spoke2 riskPremiumRad post-draw');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'wrong hub spoke2 lastUpdateTimestamp post-draw'
    );
    // dai balance
    assertEq(tokenList.dai.balanceOf(USER1), drawAmount, 'wrong USER1 dai final balance');
    assertEq(tokenList.dai.balanceOf(USER2), 0, 'wrong USER2 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai final balance');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - drawAmount,
      'wrong hub dai final balance'
    );
    // weth balance
    assertEq(tokenList.weth.balanceOf(USER1), 0, 'wrong USER1 weth final balance');
    assertEq(tokenList.weth.balanceOf(USER2), 0, 'wrong USER2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'wrong spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'wrong spoke2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'wrong hub weth final balance');
  }

  function test_draw_fuzz_amounts_same_block(uint256 daiAmount) public {
    daiAmount = bound(daiAmount, 10, 1e30); // TODO: update with max allowed amount when precision resolved
    uint256 wethAmount = daiAmount / 10;
    uint256 drawAmount = daiAmount / 2;

    // spoke1, USER1 supply weth
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2, USER2 supply dai
    deal(address(tokenList.dai), USER2, daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    vm.expectEmit(address(hub));
    emit Draw(daiAssetId, address(spoke1), USER1, drawAmount);
    vm.prank(address(spoke1));
    hub.draw({assetId: daiAssetId, to: USER1, amount: drawAmount, riskPremiumRad: 0});

    Asset memory wethData = hub.getAsset(wethAssetId);
    Asset memory daiData = hub.getAsset(daiAssetId);

    SpokeData memory spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(daiAssetId, address(spoke2));

    // hub
    assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'wrong hub weth total assets post-draw');
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'wrong hub dai total assets post-draw');
    // weth
    assertEq(
      wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'wrong hub weth suppliedShares post-draw'
    );
    assertEq(wethData.baseDebt, 0, 'wrong hub weth baseDebt post-draw');
    assertEq(wethData.outstandingPremium, 0, 'wrong hub weth outstandingPremium post-draw');
    assertEq(wethData.baseBorrowIndex, WadRayMath.RAY, 'wrong hub weth baseBorrowIndex post-draw');
    assertEq(wethData.riskPremiumRad, 0, 'wrong hub weth riskPremiumRad post-draw');
    assertEq(
      wethData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong hub weth lastUpdateTimestamp post-draw'
    );
    // dai
    assertEq(
      daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'wrong hub dai suppliedShares post-draw'
    );
    assertEq(daiData.baseDebt, drawAmount, 'wrong hub dai baseDebt post-draw');
    assertEq(daiData.outstandingPremium, 0, 'wrong hub dai outstandingPremium post-draw');
    assertEq(daiData.baseBorrowIndex, WadRayMath.RAY, 'wrong hub dai baseBorrowIndex post-draw');
    assertEq(daiData.riskPremiumRad, 0, 'wrong hub dai riskPremiumRad post-draw');
    assertEq(
      daiData.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'wrong hub dai lastUpdateTimestamp post-draw'
    );
    // spoke1 weth
    assertEq(
      spoke1WethData.suppliedShares,
      wethData.suppliedShares,
      'wrong hub spoke1 suppliedShares post-draw'
    );
    assertEq(spoke1WethData.baseDebt, wethData.baseDebt, 'wrong hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1WethData.outstandingPremium,
      wethData.outstandingPremium,
      'wrong hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1WethData.baseBorrowIndex,
      wethData.baseBorrowIndex,
      'wrong hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1WethData.riskPremiumRad, 0, 'wrong hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1WethData.lastUpdateTimestamp,
      wethData.lastUpdateTimestamp,
      'wrong hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke1 dai
    assertEq(spoke1DaiData.suppliedShares, 0, 'wrong hub spoke1 suppliedShares post-draw');
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'wrong hub spoke1 baseDebt post-draw');
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'wrong hub spoke1 outstandingPremium post-draw'
    );
    assertEq(
      spoke1DaiData.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'wrong hub spoke1 baseBorrowIndex post-draw'
    );
    assertEq(spoke1DaiData.riskPremiumRad, 0, 'wrong hub spoke1 riskPremiumRad post-draw');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'wrong hub spoke1 lastUpdateTimestamp post-draw'
    );
    // spoke2
    assertEq(
      spoke2Data.suppliedShares,
      daiData.suppliedShares,
      'wrong hub spoke2 suppliedShares post-draw'
    );
    assertEq(spoke2Data.baseDebt, 0, 'wrong hub spoke2 baseDebt post-draw');
    assertEq(
      spoke2Data.outstandingPremium,
      daiData.outstandingPremium,
      'wrong hub spoke2 outstandingPremium post-draw'
    );
    assertEq(
      spoke2Data.baseBorrowIndex,
      daiData.baseBorrowIndex,
      'wrong hub spoke2 baseBorrowIndex post-draw'
    );
    assertEq(spoke2Data.riskPremiumRad, 0, 'wrong hub spoke2 riskPremiumRad post-draw');
    assertEq(
      spoke2Data.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'wrong hub spoke2 lastUpdateTimestamp post-draw'
    );
    // dai balance
    assertEq(tokenList.dai.balanceOf(USER1), drawAmount, 'wrong USER1 dai final balance');
    assertEq(tokenList.dai.balanceOf(USER2), 0, 'wrong USER2 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai final balance');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - drawAmount,
      'wrong hub dai final balance'
    );
    // weth balance
    assertEq(tokenList.weth.balanceOf(USER1), 0, 'wrong USER1 weth final balance');
    assertEq(tokenList.weth.balanceOf(USER2), 0, 'wrong USER2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'wrong spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'wrong spoke2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'wrong hub weth final balance');
  }

  function test_draw_revertsWith_asset_not_active() public {
    uint256 drawAmount = 1;
    _updateActive(daiAssetId, false);
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.draw(daiAssetId, address(spoke1), drawAmount, 0);
  }

  function test_draw_revertsWith_not_available_liquidity() public {
    uint256 drawAmount = 1;
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.draw(daiAssetId, address(spoke1), drawAmount, 0);
  }

  function test_draw_revertsWith_cap_exceeded() public {
    uint256 daiAmount = 100e18;
    uint256 drawCap = 1;
    uint256 drawAmount = drawCap + 1;

    _updateDrawCap(daiAssetId, address(spoke1), drawCap);

    // spoke2 supply dai
    deal(address(tokenList.dai), address(spoke2), daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: address(spoke2),
      onBehalfOf: address(spoke2)
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    hub.draw(daiAssetId, address(spoke1), drawAmount, 0);
  }

  function test_restore_revertsWith_asset_not_active() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply weth
    deal(address(tokenList.weth), address(spoke1), wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: address(spoke1),
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(tokenList.dai), address(spoke2), daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: address(spoke2),
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: address(spoke1),
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    _updateActive(daiAssetId, false);

    // spoke1 restore all of drawn dai liquidity
    vm.startPrank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.restore(daiAssetId, 0, drawAmount, USER1);
    vm.stopPrank();
  }

  function test_restore_revertsWith_invalid_restore_amount() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply weth
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(tokenList.dai), address(spoke2), daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: address(spoke2),
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: USER1,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    vm.prank(USER1);
    tokenList.dai.approve(address(hub), drawAmount + 1);

    // user1 restore invalid amount > drawn amount AND premium
    vm.startPrank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);
    hub.restore({assetId: daiAssetId, amount: drawAmount + 1, riskPremiumRad: 0, repayer: USER1});
    vm.stopPrank();
  }

  // function test_restore_revertsWith_invalid_restore_amount_with_interest() public {
  //   uint256 daiAmount = 100e18;
  //   uint256 wethAmount = 10e18;

  //   uint256 drawAmount = daiAmount / 2;

  //   // spoke1 supply weth
  //   deal(address(tokenList.weth), USER1, wethAmount);
  //   Utils.supply({
  //     hub: hub,
  //     assetId: wethAssetId,
  //     spoke: address(spoke1),
  //     amount: wethAmount,
  //     riskPremiumRad: 0,
  //     user: USER1,
  //     onBehalfOf: address(spoke1)
  //   });

  //   // spoke2 supply dai
  //   deal(address(tokenList.dai), address(spoke2), daiAmount);
  //   Utils.supply({
  //     hub: hub,
  //     assetId: daiAssetId,
  //     spoke: address(spoke2),
  //     amount: daiAmount,
  //     riskPremiumRad: 0,
  //     user: address(spoke2),
  //     onBehalfOf: address(spoke2)
  //   });

  //   // spoke1 draw half of dai reserve liquidity
  //   Utils.draw({
  //     hub: hub,
  //     assetId: daiAssetId,
  //     to: USER1,
  //     spoke: address(spoke1),
  //     amount: drawAmount,
  //     riskPremiumRad: 0,
  //     onBehalfOf: address(spoke1)
  //   });

  //   skip(365 days / 2);

  //   // spoke2 supply more dai to trigger accrual
  //   deal(address(tokenList.dai), address(spoke2), daiAmount/5);
  //   Utils.supply({
  //     hub: hub,
  //     assetId: daiAssetId,
  //     spoke: address(spoke2),
  //     amount: daiAmount/5,
  //     riskPremiumRad: uint256(5_00).bpsToRad(),
  //     user: address(spoke2),
  //     onBehalfOf: address(spoke2)
  //   });

  //   vm.prank(USER1);
  //   tokenList.dai.approve(address(hub), drawAmount + 1);

  //   // user1 restore invalid amount > drawn amount AND premium
  //   vm.startPrank(address(spoke1));
  //   vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);
  //   hub.restore({assetId: daiAssetId, amount: drawAmount + 1, riskPremiumRad: 0, repayer: USER1});
  //   vm.stopPrank();
  // }

  // TODO: test_restore_revertsWith_invalid_restore_amount_with_interest_and_premium

  struct HubData {
    Asset daiData;
    Asset wethData;
    SpokeData spoke1WethData;
    SpokeData spoke1DaiData;
    SpokeData spoke2WethData;
    SpokeData spoke2DaiData;
    uint256 timestamp;
  }

  function test_restore_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = daiAmount / 4;

    uint256 rate = uint256(15_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    deal(address(tokenList.weth), USER1, wethAmount);
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(tokenList.dai), USER2, daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: USER2,
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: USER1,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    // spoke1 restore half of drawn dai liquidity on behalf of user1
    vm.prank(USER1);
    tokenList.dai.approve(address(hub), restoreAmount);

    vm.expectEmit(address(hub));
    emit Restore(daiAssetId, address(spoke1), restoreAmount);

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: USER1});

    HubData memory hubData;
    hubData.daiData = hub.getAsset(daiAssetId);
    hubData.wethData = hub.getAsset(wethAssetId);
    hubData.spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    hubData.timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(
      hub.getTotalAssets(wethAssetId),
      wethAmount,
      'wrong hub weth total assets post-restore'
    );
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'wrong hub dai total assets post-restore');
    // dai
    assertEq(
      hubData.daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'wrong hub dai total shares post-restore'
    );
    assertEq(
      hubData.daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'wrong hub dai availableLiquidity post-restore'
    );
    assertEq(
      hubData.daiData.baseDebt,
      drawAmount - restoreAmount,
      'wrong hub dai baseDebt post-restore'
    );
    assertEq(
      hubData.daiData.outstandingPremium,
      0,
      'wrong hub dai outstandingPremium post-restore'
    );
    assertEq(
      hubData.daiData.baseBorrowIndex,
      WadRayMath.RAY,
      'wrong hub dai baseBorrowIndex post-restore'
    );
    assertEq(hubData.daiData.baseBorrowRate, rate, 'wrong hub dai baseBorrowRate post-restore');
    assertEq(hubData.daiData.riskPremiumRad, 0, 'wrong hub dai riskPremiumRad post-restore');
    assertEq(
      hubData.daiData.lastUpdateTimestamp,
      hubData.timestamp,
      'wrong hub dai lastUpdateTimestamp post-restore'
    );
    // weth
    assertEq(
      hubData.wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'wrong hub weth total shares post-restore'
    );
    assertEq(
      hubData.wethData.availableLiquidity,
      wethAmount,
      'wrong hub weth availableLiquidity post-restore'
    );
    assertEq(hubData.wethData.baseDebt, 0, 'wrong hub weth baseDebt post-restore');
    assertEq(
      hubData.wethData.outstandingPremium,
      0,
      'wrong hub weth outstandingPremium post-restore'
    );
    assertEq(
      hubData.wethData.baseBorrowIndex,
      WadRayMath.RAY,
      'wrong hub weth baseBorrowIndex post-restore'
    );
    assertEq(hubData.wethData.baseBorrowRate, rate, 'wrong hub weth baseBorrowRate post-restore');
    assertEq(hubData.wethData.riskPremiumRad, 0, 'wrong hub weth riskPremiumRad post-restore');
    assertEq(
      hubData.wethData.lastUpdateTimestamp,
      hubData.timestamp,
      'wrong hub weth lastUpdateTimestamp post-restore'
    );
    // spoke1 weth
    assertEq(
      hubData.spoke1WethData.suppliedShares,
      hubData.wethData.suppliedShares,
      'wrong spoke1 total weth shares post-restore'
    );
    assertEq(
      hubData.spoke1WethData.baseDebt,
      hubData.wethData.baseDebt,
      'wrong spoke1 base weth debt'
    );
    assertEq(
      hubData.spoke1WethData.outstandingPremium,
      hubData.wethData.outstandingPremium,
      'wrong spoke1 weth outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke1WethData.baseBorrowIndex,
      hubData.wethData.baseBorrowIndex,
      'wrong spoke1 weth baseBorrowIndex post-restore'
    );
    assertEq(
      hubData.spoke1WethData.riskPremiumRad,
      0,
      'wrong spoke1 weth riskPremiumRad post-restore'
    );
    assertEq(
      hubData.spoke1WethData.lastUpdateTimestamp,
      hubData.wethData.lastUpdateTimestamp,
      'wrong spoke1 weth lastUpdateTimestamp post-restore'
    );
    // spoke1 dai
    assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'wrong spoke1 total dai shares post-restore');
    assertEq(
      hubData.spoke1DaiData.baseDebt,
      hubData.daiData.baseDebt,
      'wrong spoke1 base dai debt post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.outstandingPremium,
      hubData.daiData.outstandingPremium,
      'wrong spoke1 dai outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.baseBorrowIndex,
      hubData.daiData.baseBorrowIndex,
      'wrong spoke1 dai baseBorrowIndex post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.riskPremiumRad,
      0,
      'wrong spoke1 dai riskPremiumRad post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.lastUpdateTimestamp,
      hubData.daiData.lastUpdateTimestamp,
      'wrong spoke1 dai lastUpdateTimestamp post-restore'
    );
    // spoke2 dai
    assertEq(
      hubData.spoke2DaiData.suppliedShares,
      hubData.daiData.suppliedShares,
      'wrong spoke2 total dai shares post-restore'
    );
    assertEq(hubData.spoke2DaiData.baseDebt, 0, 'wrong spoke2 base dai debt post-restore');
    assertEq(
      hubData.spoke2DaiData.outstandingPremium,
      hubData.daiData.outstandingPremium,
      'wrong spoke2 dai outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke2DaiData.baseBorrowIndex,
      hubData.daiData.baseBorrowIndex,
      'wrong spoke2 dai baseBorrowIndex post-restore'
    );
    assertEq(
      hubData.spoke2DaiData.riskPremiumRad,
      0,
      'wrong spoke2 dai riskPremiumRad post-restore'
    );
    assertEq(
      hubData.spoke2DaiData.lastUpdateTimestamp,
      hubData.daiData.lastUpdateTimestamp,
      'wrong spoke2 dai lastUpdateTimestamp post-restore'
    );

    // token balance
    // dai
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - restoreAmount,
      'wrong hub dai final balance'
    );
    assertEq(
      tokenList.dai.balanceOf(USER1),
      drawAmount - restoreAmount,
      'wrong USER1 dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(USER2), 0, 'wrong USER2 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai final balance');
    // weth
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'wrong hub weth final balance');
    assertEq(tokenList.weth.balanceOf(USER1), 0, 'wrong USER1 weth final balance');
    assertEq(tokenList.weth.balanceOf(USER2), 0, 'wrong USER2 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'wrong spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'wrong spoke2 weth final balance');
  }

  function test_addSpoke() public {
    uint256 assetId = hub.assetCount();

    vm.expectEmit(address(hub));
    emit SpokeAdded(assetId, address(spoke1));
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(assetId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'wrong spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'wrong spoke draw cap');
  }

  function test_addSpoke_revertsWith_invalid_spoke() public {
    uint256 assetId = hub.assetCount();
    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpoke(assetId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  }

  function test_addSpokes() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    DataTypes.SpokeConfig memory ethSpokeConfig = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = ethSpokeConfig;

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiAssetId, address(spoke1));
    emit SpokeAdded(wethAssetId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiAssetId, address(spoke1));
    DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(wethAssetId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'wrong dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'wrong dai spoke draw cap');

    assertEq(ethSpokeData.supplyCap, ethSpokeConfig.supplyCap, 'wrong eth spoke supply cap');
    assertEq(ethSpokeData.drawCap, ethSpokeConfig.drawCap, 'wrong eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_invalid_spoke() public {
    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiAssetId;
    assetIds[1] = wethAssetId;

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    spokeConfigs[1] = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpokes(assetIds, spokeConfigs, address(0));
  }

  // function _updateLiquidityPremium(uint256 assetId, uint256 newLiquidityPremium) internal {
  //   DataTypes.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
  //   reserveConfig.liquidityPremium = newLiquidityPremium;
  //   hub.updateAsset(assetId, reserveConfig);
  // }

  function _updateActive(uint256 assetId, bool newActive) internal {
    DataTypes.AssetConfig memory reserveConfig = hub.getAsset(assetId).config;
    reserveConfig.active = newActive;
    hub.updateAssetConfig(assetId, reserveConfig);
  }

  function _updateDrawCap(uint256 assetId, address spoke, uint256 newDrawCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.drawCap = newDrawCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }

  function _updateSupplyCap(uint256 assetId, address spoke, uint256 newSupplyCap) internal {
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
    spokeConfig.supplyCap = newSupplyCap;
    hub.updateSpokeConfig(assetId, spoke, spokeConfig);
  }
}
