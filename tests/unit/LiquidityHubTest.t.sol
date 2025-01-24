// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();

    address[] memory spokes = new address[](2);
    spokes[0] = address(spoke1);
    spokes[1] = address(spoke2);
    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    spokeConfigs[1] = DataTypes.SpokeConfig({
      supplyCap: type(uint256).max,
      drawCap: type(uint256).max
    });
    Spoke.ReserveConfig[] memory reserveConfigs = new Spoke.ReserveConfig[](2);
    reserveConfigs[0] = Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false});
    reserveConfigs[1] = Spoke.ReserveConfig({lt: 0, lb: 0, borrowable: true, collateral: false});

    // Add dai
    uint256 daiAssetId = 0;
    Utils.addAssetAndSpokes(
      hub,
      address(dai),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(daiAssetId, 1e8);

    // Add eth
    uint256 ethAssetId = 1;
    Utils.addAssetAndSpokes(
      hub,
      address(eth),
      DataTypes.AssetConfig({decimals: 18, active: true, irStrategy: address(irStrategy)}),
      spokes,
      spokeConfigs,
      reserveConfigs
    );
    oracle.setAssetPrice(ethAssetId, 2000e8);

    irStrategy.setInterestRateParams(
      daiAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    irStrategy.setInterestRateParams(
      ethAssetId,
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 daiId = 0;
    uint256 amount = 100e18;

    deal(address(dai), address(spoke1), amount);
    vm.prank(address(spoke1));
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        0,
        amount
      )
    );
    hub.supply(daiId, amount, 0, address(spoke1));
  }

  function test_supply_revertsWith_asset_not_active() public {
    uint256 daiId = 0;
    uint256 amount = 100e18;

    _updateActive(daiId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.supply(daiId, amount, 0, USER1);
  }

  function test_supply_revertsWith_supply_cap_exceeded() public {
    uint256 daiId = 0;
    uint256 amount = 100e18;
    _updateSupplyCap(daiId, address(spoke1), amount - 1);

    vm.expectRevert(TestErrors.SUPPLY_CAP_EXCEEDED);
    hub.supply(daiId, amount, 0, USER1);
  }

  function test_supply() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
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
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    deal(address(dai), USER1, amount);
    vm.prank(USER1);
    dai.approve(address(hub), amount);

    deal(address(dai), USER1, amount);
    vm.prank(USER1);
    dai.approve(address(hub), amount);

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
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
  }

  /// @dev User makes a first supply, shares and assets amounts are correct, no precision loss
  function test_fuzz_first_supply(uint256 assetId, address user, uint256 amount) public {
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

  function test_fuzz_supply_events(
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

  function test_supply_with_increased_index() public {
    vm.skip(true);
    // TODO User supplies X and gets accounted X assets and less than X shares.
    // - do this after draw is resolved, amount is drawn, and then skip time, baseDebt grows
    // - exchange rate increases
    // - supply2 happens, supplies X and gets less than X shares
  }

  function test_supply_multiple() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
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
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-supply');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance pre-supply');

    deal(address(dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
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
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-supply');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance post-supply');
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');

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

    deal(address(dai), USER2, spoke2SupplyAssets);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke2),
      amount: spoke2SupplyAssets,
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
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance post-supply');
    assertEq(dai.balanceOf(USER2), 0, 'wrong user token balance post-supply');
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
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
      user: USER1,
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
    // dai
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance pre-withdraw');
    assertEq(dai.balanceOf(address(hub)), amount, 'wrong hub token balance pre-withdraw');
    assertEq(dai.balanceOf(USER1), 0, 'wrong user token balance pre-withdraw');

    vm.expectEmit(address(dai));
    emit Transfer(address(hub), USER1, amount);
    vm.expectEmit(address(hub));
    emit Withdraw(assetId, address(spoke1), USER1, amount);

    vm.startPrank(address(spoke1));
    hub.withdraw({assetId: assetId, to: USER1, amount: amount, riskPremiumRad: 0});
    vm.stopPrank();

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
    // dai
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke token balance post-withdraw');
    assertEq(dai.balanceOf(address(hub)), 0, 'wrong hub token balance post-withdraw');
    assertEq(dai.balanceOf(USER1), amount, 'wrong user token balance post-withdraw');
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

    Utils.withdraw({hub: hub, assetId: assetId, spoke: address(spoke1), amount: amount, to: user});

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
    vm.skip(true);
    // TODO User supplies X and withdraws more than X because there is some yield
    // - do this after draw method is done
    // - user1 supply, then user2 draw amount, time flies, base debt grows
    // - user1 withdraws, should have interest
  }

  function test_withdraw_revertsWith_zero_supplied() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 1;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(assetId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 assetId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), USER1, amount);
    Utils.supply({
      hub: hub,
      assetId: assetId,
      spoke: address(spoke1),
      amount: amount,
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
    uint256 daiId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), address(spoke1), amount);
    Utils.supply(hub, daiId, address(spoke1), amount, address(spoke1), address(spoke1));

    // spoke1 draw all of dai reserve liquidity
    Utils.draw(hub, daiId, address(spoke1), address(spoke1), amount, address(spoke1));

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw(daiId, address(spoke1), amount, 0);
  }

  function test_withdraw_revertsWith_asset_not_active() public {
    uint256 daiId = 0; // TODO: Add getter of asset id based on address
    uint256 amount = 100e18;

    // User supply
    deal(address(dai), address(spoke1), amount);
    Utils.supply(hub, daiId, address(spoke1), amount, address(spoke1), address(spoke1));

    _updateActive(daiId, false);

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.withdraw(daiId, address(spoke1), amount, 0);
  }

  // TODO after RP logic is implemented
  function test_user_riskPremium() public {
    vm.skip(true);

    uint256 amount = 100e18;
    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;

    deal(address(eth), USER1, amount);
    Utils.supply(hub, ethAssetId, USER1, amount, USER1, USER1);
    spoke1.getUserDebt(ethAssetId, USER1);
    spoke1.getUserDebt(ethAssetId, USER2);
    spoke1.getUserDebt(daiAssetId, USER1);
    spoke1.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 0);

    deal(address(dai), USER2, amount);
    Utils.supply(hub, daiAssetId, USER1, amount, USER2, USER2);
    spoke1.getUserDebt(ethAssetId, USER1);
    spoke1.getUserDebt(ethAssetId, USER2);
    spoke1.getUserDebt(daiAssetId, USER1);
    spoke1.getUserDebt(daiAssetId, USER2);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // assertEq(hub.getUserRiskPremium(USER2), 10_00);
  }

  // TODO after RP logic is implemented
  function test_user_riskPremium_update_affects_positions() public {
    vm.skip(true);

    uint256 assetId = 1;
    uint256 amount = 100e18;

    uint256 calcRiskPremium;

    // 100 collateral of ETH - 0 liquidityPremium
    // _updateLiquidityPremium(assetId, 0);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    deal(address(eth), USER1, amount);
    Utils.supply(hub, assetId, USER1, amount, USER1, USER1);
    calcRiskPremium = 0;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);

    // ETH liquidityPremium changes to 100_00
    // _updateLiquidityPremium(assetId, 100_00);
    // assertEq(hub.getUserRiskPremium(USER1), 0);
    // hub.refreshUserRiskPremium(USER1);
    calcRiskPremium = 100_00;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
  }

  // TODO after RP logic is implemented
  function test_user_riskPremium_weighted() public {
    vm.skip(true);

    uint256 ethAssetId = 1;
    uint256 daiAssetId = 0;
    uint256 ethAmount = 1e18;
    uint256 daiAmount = 2000e18;
    // ETH liquidityPremium to 0, DAI liquidityPremium to 50% liquidityPremium
    // _updateLiquidityPremium(daiAssetId, 50_00);
    // _updateLiquidityPremium(ethAssetId, 0);

    deal(address(dai), USER1, daiAmount);
    Utils.supply(hub, daiAssetId, USER1, daiAmount, USER1, USER1);
    deal(address(eth), USER1, ethAmount);
    Utils.supply(hub, ethAssetId, USER1, ethAmount, USER1, USER1);

    uint256 calcRiskPremium = 25_00;
    // assertEq(hub.getUserRiskPremium(USER1), calcRiskPremium);
  }

  function test_first_draw() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(hub, ethId, address(spoke1), ethAmount, address(spoke1), address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(hub, daiId, address(spoke2), daiAmount, address(spoke2), address(spoke2));

    Asset memory daiData = hub.getAsset(daiId);
    Asset memory ethData = hub.getAsset(ethId);
    SpokeData memory spoke1Data = hub.getSpoke(ethId, address(spoke1));
    SpokeData memory spoke2Data = hub.getSpoke(daiId, address(spoke2));

    // assertEq(
    //   daiData.totalShares,
    //   hub.convertToSharesUp(daiId, daiAmount),
    //   'wrong hub dai total shares pre-draw'
    // );
    // assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets pre-draw');
    // assertEq(daiData.drawnShares, 0, 'wrong hub dai total assets pre-draw');
    // assertEq(
    //   ethData.totalShares,
    //   hub.convertToSharesUp(ethId, ethAmount),
    //   'wrong hub eth total shares pre-draw'
    // );
    // assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets pre-draw');
    // assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn assets pre-draw');
    // assertEq(
    //   spoke1Data.totalShares,
    //   hub.convertToSharesDown(ethId, ethAmount),
    //   'wrong spoke1 total shares pre-draw'
    // );
    // assertEq(spoke1Data.drawnShares, 0, 'wrong spoke1 drawn shares pre-draw');
    // assertEq(
    //   spoke2Data.totalShares,
    //   hub.convertToSharesDown(daiId, daiAmount),
    //   'wrong spoke2 total shares pre-draw'
    // );
    // assertEq(spoke2Data.drawnShares, 0, 'wrong spoke2 drawn shares pre-draw');
    // assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai balance pre-draw');
    // assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth balance pre-draw');

    // spoke1 draw half of dai reserve liquidity
    vm.prank(address(spoke1));
    vm.expectEmit(address(hub));
    emit Draw(daiId, address(spoke1), address(spoke1), daiAmount / 2);
    hub.draw(daiId, address(spoke1), daiAmount / 2, 0);

    daiData = hub.getAsset(daiId);
    ethData = hub.getAsset(ethId);
    spoke1Data = hub.getSpoke(ethId, address(spoke1));
    spoke2Data = hub.getSpoke(daiId, address(spoke2));

    // assertEq(
    //   daiData.totalShares,
    //   hub.convertToSharesUp(daiId, daiAmount),
    //   'wrong hub dai total shares post-draw'
    // );
    // assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets post-draw');
    // assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets post-draw');
    // assertEq(
    //   ethData.totalShares,
    //   hub.convertToSharesUp(ethId, ethAmount),
    //   'wrong hub eth total shares post-draw'
    // );
    // assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn shares post-draw');

    assertEq(dai.balanceOf(address(spoke1)), daiAmount / 2, 'wrong spoke1 dai final balance');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_draw_revertsWith_asset_not_active() public {
    uint256 daiId = 2;
    uint256 drawnAmount = 1;
    _updateActive(daiId, false);
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_draw_revertsWith_not_available_liquidity() public {
    uint256 daiId = 0;
    uint256 drawnAmount = 1;
    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.NOT_AVAILABLE_LIQUIDITY);
    hub.draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_draw_revertsWith_cap_exceeded() public {
    uint256 daiId = 0;
    uint256 daiAmount = 100e18;
    uint256 drawCap = 1;
    uint256 drawnAmount = drawCap + 1;

    _updateDrawCap(daiId, address(spoke1), drawCap);

    // User2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(hub, daiId, address(spoke2), daiAmount, address(spoke2), address(spoke2));

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.DRAW_CAP_EXCEEDED);
    hub.draw(daiId, address(spoke1), drawnAmount, 0);
  }

  function test_restore_revertsWith_asset_not_active() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply eth
    deal(address(eth), address(spoke1), ethAmount);
    Utils.supply(hub, ethId, address(spoke1), ethAmount, address(spoke1), address(spoke1));

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply(hub, daiId, address(spoke2), daiAmount, address(spoke2), address(spoke2));

    // spoke1 draw half of dai reserve liquidity
    Utils.draw(hub, daiId, address(spoke1), address(spoke1), drawAmount, address(spoke1));

    _updateActive(daiId, false);

    // spoke1 restore all of drawn dai liquidity
    vm.startPrank(address(spoke1));
    IERC20(address(dai)).transfer(address(hub), drawAmount);
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);
    hub.restore(daiId, 0, drawAmount, USER1);
    vm.stopPrank();
  }

  function test_restore_revertsWith_invalid_restore_amount() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.supply({
      hub: hub,
      assetId: ethId,
      spoke: address(spoke1),
      amount: ethAmount,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: address(spoke2),
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiId,
      to: USER1,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    vm.prank(USER1);
    dai.approve(address(hub), drawAmount + 1);

    // user1 restore invalid amount > drawn amount
    vm.startPrank(address(spoke1));
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);
    hub.restore({assetId: daiId, amount: drawAmount + 1, riskPremiumRad: 0, repayer: USER1});
    vm.stopPrank();
  }

  function test_restore() public {
    uint256 daiId = 0;
    uint256 ethId = 1;
    uint256 daiAmount = 100e18;
    uint256 ethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = daiAmount / 4;

    // spoke1 supply eth
    deal(address(eth), USER1, ethAmount);
    Utils.supply({
      hub: hub,
      assetId: ethId,
      spoke: address(spoke1),
      amount: ethAmount,
      user: USER1,
      onBehalfOf: address(spoke1)
    });

    // spoke2 supply dai
    deal(address(dai), address(spoke2), daiAmount);
    Utils.supply({
      hub: hub,
      assetId: daiId,
      spoke: address(spoke2),
      amount: daiAmount,
      user: address(spoke2),
      onBehalfOf: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiId,
      to: USER1,
      spoke: address(spoke1),
      amount: drawAmount,
      onBehalfOf: address(spoke1)
    });

    // spoke1 restore half of drawn dai liquidity on behalf of user1
    vm.prank(USER1);
    dai.approve(address(hub), restoreAmount);
    vm.startPrank(address(spoke1));
    vm.expectEmit(address(hub));
    emit Restore(daiId, address(spoke1), restoreAmount);
    hub.restore({assetId: daiId, amount: restoreAmount, riskPremiumRad: 0, repayer: USER1});
    vm.stopPrank();

    // Asset memory daiData = hub.getAsset(daiId);
    // Asset memory ethData = hub.getAsset(ethId);
    // SpokeData memory spoke1EthData = hub.getSpoke(ethId, address(spoke1));
    // SpokeData memory spoke1DaiData = hub.getSpoke(daiId, address(spoke1));
    // SpokeData memory spoke2EthData = hub.getSpoke(ethId, address(spoke2));
    // SpokeData memory spoke2DaiData = hub.getSpoke(daiId, address(spoke2));

    // assertEq(
    //   daiData.totalShares,
    //   hub.convertToSharesUp(daiId, daiAmount),
    //   'wrong hub dai total shares post-restore'
    // );
    // assertEq(daiData.totalAssets, daiAmount, 'wrong hub dai total assets post-restore');
    // assertEq(ethData.totalAssets, ethAmount, 'wrong hub eth total assets post-restore');
    // assertEq(
    //   ethData.totalShares,
    //   hub.convertToSharesUp(ethId, ethAmount),
    //   'wrong hub eth total shares post-restore'
    // );
    // assertEq(ethData.drawnShares, 0, 'wrong hub eth drawn shares post-restore');
    // assertEq(
    //   spoke1EthData.totalShares,
    //   hub.convertToSharesUp(ethId, ethAmount),
    //   'wrong spoke1 total eth shares post-restore'
    // );
    // assertEq(spoke1EthData.drawnShares, 0, 'wrong spoke1 drawn eth shares post-restore');
    // assertEq(spoke1DaiData.totalShares, 0, 'wrong spoke1 total dai shares post-restore');
    // assertEq(
    //   spoke1DaiData.drawnShares,
    //   hub.convertToSharesUp(daiId, drawAmount - restoreAmount),
    //   'wrong spoke1 drawn dai shares post-restore'
    // );
    // assertEq(spoke2EthData.totalShares, 0, 'wrong spoke2 total eth shares post-restore');
    // assertEq(spoke2EthData.drawnShares, 0, 'wrong spoke2 drawn eth shares post-restore');
    // assertEq(
    //   spoke2DaiData.totalShares,
    //   hub.convertToSharesDown(daiId, daiAmount),
    //   'wrong spoke2 total dai shares post-restore'
    // );
    // assertEq(spoke2DaiData.drawnShares, 0, 'wrong spoke2 drawn dai shares post-restore');

    assertEq(dai.balanceOf(address(hub)), daiAmount - restoreAmount, 'wrong hub dai final balance');
    assertEq(dai.balanceOf(USER1), drawAmount - restoreAmount, 'wrong spoke1 dai final balance');
    assertEq(dai.balanceOf(address(spoke1)), 0, 'wrong spoke1 dai final balance');
    assertEq(dai.balanceOf(address(spoke2)), 0, 'wrong spoke2 dai final balance');

    assertEq(eth.balanceOf(address(hub)), ethAmount, 'wrong hub eth final balance');
    assertEq(eth.balanceOf(USER1), 0, 'wrong user eth final balance');
    assertEq(eth.balanceOf(address(spoke1)), 0, 'wrong spoke1 eth final balance');
    assertEq(eth.balanceOf(address(spoke2)), 0, 'wrong spoke2 eth final balance');
  }

  function test_addSpoke() public {
    uint256 daiId = 0;

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiId, address(spoke1));
    hub.addSpoke(daiId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(spoke1));

    DataTypes.SpokeConfig memory spokeData = hub.getSpokeConfig(daiId, address(spoke1));
    assertEq(spokeData.supplyCap, 1, 'wrong spoke supply cap');
    assertEq(spokeData.drawCap, 1, 'wrong spoke draw cap');
  }

  function test_addSpoke_revertsWith_invalid_spoke() public {
    uint256 daiId = 0;
    vm.expectRevert(TestErrors.INVALID_SPOKE);
    hub.addSpoke(daiId, DataTypes.SpokeConfig({supplyCap: 1, drawCap: 1}), address(0));
  }

  function test_addSpokes() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiId;
    assetIds[1] = ethId;

    DataTypes.SpokeConfig memory daiSpokeConfig = DataTypes.SpokeConfig({supplyCap: 1, drawCap: 2});
    DataTypes.SpokeConfig memory ethSpokeConfig = DataTypes.SpokeConfig({supplyCap: 3, drawCap: 4});

    DataTypes.SpokeConfig[] memory spokeConfigs = new DataTypes.SpokeConfig[](2);
    spokeConfigs[0] = daiSpokeConfig;
    spokeConfigs[1] = ethSpokeConfig;

    vm.expectEmit(address(hub));
    emit SpokeAdded(daiId, address(spoke1));
    emit SpokeAdded(ethId, address(spoke1));
    hub.addSpokes(assetIds, spokeConfigs, address(spoke1));

    DataTypes.SpokeConfig memory daiSpokeData = hub.getSpokeConfig(daiId, address(spoke1));
    DataTypes.SpokeConfig memory ethSpokeData = hub.getSpokeConfig(ethId, address(spoke1));

    assertEq(daiSpokeData.supplyCap, daiSpokeConfig.supplyCap, 'wrong dai spoke supply cap');
    assertEq(daiSpokeData.drawCap, daiSpokeConfig.drawCap, 'wrong dai spoke draw cap');

    assertEq(ethSpokeData.supplyCap, ethSpokeConfig.supplyCap, 'wrong eth spoke supply cap');
    assertEq(ethSpokeData.drawCap, ethSpokeConfig.drawCap, 'wrong eth spoke draw cap');
  }

  function test_addSpokes_revertsWith_invalid_spoke() public {
    uint256 daiId = 0;
    uint256 ethId = 1;

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = daiId;
    assetIds[1] = ethId;

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
