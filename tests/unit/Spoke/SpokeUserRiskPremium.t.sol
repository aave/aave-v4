// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';
import {KeyValueListInMemory} from 'src/contracts/KeyValueListInMemory.sol';
import 'tests/Base.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeUserRiskPremiumTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using KeyValueListInMemory for KeyValueListInMemory.List;

  struct TestInfo {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    uint256 dai2ReserveId;
    uint256 borrowAmount;
    uint256 supplyAmount;
    uint256 daiSupplyAmount;
    uint256 usdxSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 dai2SupplyAmount;
    uint256 daiBorrowAmount;
    uint256 usdxBorrowAmount;
    uint256 wethBorrowAmount;
    uint256 wbtcBorrowAmount;
    uint256 dai2BorrowAmount;
    uint256 daiPrice;
    uint256 wethPrice;
    uint256 usdxPrice;
    uint256 wbtcPrice;
    uint256 daiLP;
    uint256 wethLP;
    uint256 usdxLP;
    uint256 wbtcLP;
    uint256 dai2LP;
  }

  struct ReserveLP {
    uint256 reserveId;
    uint256 lp;
  }

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_getUserRiskPremium_no_collateral() public view {
    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral_borrowed() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    DataTypes.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_fuzz_single_asset_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT);

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.borrowAmount = borrowAmount;
    params.supplyAmount = borrowAmount * 2;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, params.supplyAmount);
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    if (_normalizedValue(params.borrowAmount, daiAssetId) > 0) {
      // With single collateral, user rp will match liquidity premium of collateral
      assertEq(spoke1.getUserRiskPremium(bob), params.daiLP, 'user risk premium');
    } else {
      // Dust amount borrowed, no risk premium
      assertEq(spoke1.getUserRiskPremium(bob), 0, 'user risk premium');
    }
  }

  function test_getUserRiskPremium_fuzz_supply_does_not_impact(
    uint256 borrowAmount,
    uint256 additionalSupplyAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    additionalSupplyAmount = bound(additionalSupplyAmount, 1, MAX_SUPPLY_AMOUNT);

    TestInfo memory params;
    params.borrowAmount = borrowAmount;
    params.supplyAmount = borrowAmount * 2;

    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob draw dai
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    if (_normalizedValue(params.borrowAmount, daiAssetId) > 0) {
      // With single collateral, user rp will match liquidity premium of collateral
      assertEq(userRiskPremium, params.daiLP, 'user risk premium');
    } else {
      // Dust amount borrowed, no risk premium
      assertEq(userRiskPremium, 0, 'user risk premium');
    }

    // Supplying more risky asset (usdx) should not impact user risk premium
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, additionalSupplyAmount, bob);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'user risk premium after supply');
  }

  function test_getUserRiskPremium_multi_asset_collateral() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 1000e18;
    params.usdxSupplyAmount = 1000e6;
    params.wethSupplyAmount = 1000e18;
    params.daiBorrowAmount = 1000e18;
    params.usdxBorrowAmount = 1000e6;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiBorrowAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxBorrowAmount, bob);

    // Weth is enough to cover the total debt
    uint256 expectedUserRiskPremium = params.wethLP;

    DataTypes.UserPosition memory userConfig = spoke1.getUserPosition(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.daiSupplyAmount);

    userConfig = spoke1.getUserPosition(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.usdxSupplyAmount);

    userConfig = spoke1.getUserPosition(params.wethReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(wethAssetId, params.wethSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_multi_asset_collateral_weth_partial_cover() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 2000e6;
    params.wethSupplyAmount = 1e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);

    DataTypes.UserPosition memory userConfig = spoke1.getUserPosition(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.daiSupplyAmount);

    userConfig = spoke1.getUserPosition(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.usdxSupplyAmount);

    userConfig = spoke1.getUserPosition(params.wethReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(wethAssetId, params.wethSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    assertEq(
      params.wethSupplyAmount * oracle.getAssetPrice(wethAssetId),
      2000e26,
      'weth supply amount'
    );
    assertEq(
      params.daiSupplyAmount * oracle.getAssetPrice(daiAssetId),
      2000e26,
      'dai supply amount'
    );

    // Weth covers half the debt, dai covers the rest
    uint256 expectedUserRiskPremium = (params.wethLP *
      params.wethSupplyAmount *
      oracle.getAssetPrice(wethAssetId) +
      params.daiLP *
      params.daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId)) /
      (params.wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        params.daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId));

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_two_assets_equal_parts() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 6000e6;
    params.wethSupplyAmount = 10e18;

    params.wethBorrowAmount = 2e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, alice, params.wethSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.wethReserveId, true);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    DataTypes.UserPosition memory userConfig = spoke1.getUserPosition(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUserPosition(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUserPosition(params.wethReserveId, bob);
    assertEq(userConfig.baseDebt, params.wethBorrowAmount);

    userConfig = spoke1.getUserPosition(params.wethReserveId, alice);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(wethAssetId, params.wethSupplyAmount)
    );

    // Dai and usdx will each cover half the debt
    uint256 usdxContribution = 2000e6;
    uint256 expectedUserRiskPremium = (params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(usdxContribution, usdxAssetId)) /
      (_normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(usdxContribution, usdxAssetId));

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'user risk premium');
  }

  function test_getUserRiskPremium_fuzz_two_assets_diff_amounts(uint256 daiSupplyAmount) public {
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, 4000e18);
    uint256 usdxLpContributionAmount = (4000e18 - daiSupplyAmount) / 1e12;

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = 6000e6;
    params.wethSupplyAmount = 10e18;

    params.wethBorrowAmount = 2e18;

    params.daiLP = spoke1.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke1.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke1.getLiquidityPremium(params.wethReserveId);

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, alice, params.wethSupplyAmount, alice);
    setUsingAsCollateral(spoke1, alice, params.wethReserveId, true);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    // Dai and usdx will each cover half the debt
    uint256 expectedUserRiskPremium = (params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(usdxLpContributionAmount, usdxAssetId)) /
      (_normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(usdxLpContributionAmount, usdxAssetId));

    assertApproxEqAbs(
      spoke1.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );
  }

  /// @dev Supply with a high value lp asset so it's ignored in rp calcs, but allows user to borrow large amounts.
  /// @dev Borrow with any asset because only its value is important, its lp is ignored.
  /// @dev Fix borrow amount, and fuzz the supply amounts, checking rp calc is correct.
  function test_getUserRiskPremium_fuzz_two_assets_supply_and_borrow(
    uint256 daiSupplyAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, totalBorrowAmount);

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = totalBorrowAmount - daiSupplyAmount;
    params.wethSupplyAmount = MAX_SUPPLY_AMOUNT;

    // Borrow all value in weth. Each weth is 2000 stablecoins
    params.wethBorrowAmount = totalBorrowAmount / 2000;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    assertEq(params.daiSupplyAmount + params.usdxSupplyAmount, totalBorrowAmount, 'supply amounts');

    // Bob supply dai into spoke3
    Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);

    // Bob draw weth
    Utils.spokeBorrow(spoke3, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    // Dai and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = (params.daiLP *
      params.daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId) +
      params.usdxLP *
      params.usdxSupplyAmount *
      oracle.getAssetPrice(usdxAssetId)) /
      (params.daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        params.usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    assertApproxEqAbs(
      spoke3.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_three_assets_supply_and_borrow(
    uint256 daiSupplyAmount,
    uint256 usdxSupplyAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    daiSupplyAmount = bound(daiSupplyAmount, 0, totalBorrowAmount);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, totalBorrowAmount - daiSupplyAmount) / 1e12;

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke3].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke3].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke3].wbtc.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount = usdxSupplyAmount;
    params.wethSupplyAmount = totalBorrowAmount - daiSupplyAmount - usdxSupplyAmount * 1e12;
    params.wbtcSupplyAmount = MAX_SUPPLY_AMOUNT;

    // Each weth is 2000 stablecoins; each wbtc is 50000
    params.wbtcBorrowAmount =
      (params.daiSupplyAmount *
        1e8 +
        params.usdxSupplyAmount *
        1e12 +
        (params.wethSupplyAmount * 2000e8)) /
      50000e8;

    params.daiLP = spoke3.getLiquidityPremium(params.daiReserveId);
    params.usdxLP = spoke3.getLiquidityPremium(params.usdxReserveId);
    params.wethLP = spoke3.getLiquidityPremium(params.wethReserveId);

    vm.assume(
      params.daiSupplyAmount + params.usdxSupplyAmount * 1e12 + params.wethSupplyAmount ==
        totalBorrowAmount
    );
    assertEq(
      params.daiSupplyAmount + params.usdxSupplyAmount * 1e12 + params.wethSupplyAmount,
      totalBorrowAmount,
      'supply amounts'
    );

    // Bob supply dai into spoke3
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke3
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.usdxReserveId, true);
    }

    // Bob supply weth into spoke3
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke3, bob, params.wethReserveId, true);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);

    // Bob draw wbtc
    Utils.spokeBorrow(spoke3, params.wbtcReserveId, bob, params.wbtcBorrowAmount, bob);

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = (params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(params.usdxSupplyAmount, usdxAssetId) +
      params.wethLP *
      _normalizedValue(params.wethSupplyAmount, wethAssetId)) /
      (_normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId) +
        _normalizedValue(params.wethSupplyAmount, wethAssetId));

    assertApproxEqAbs(
      spoke3.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_four_assets_supply_and_borrow(
    uint256 wbtcSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 daiSupplyAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    /// @dev The multiplications & divisions are to normalize asset values to stablecoin prices to ensure we stay under limits
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000e10);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000e10) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000e10 - wethSupplyAmount * 2000
    );

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.usdxSupplyAmount =
      (totalBorrowAmount -
        wbtcSupplyAmount *
        50000e10 -
        wethSupplyAmount *
        2000 -
        daiSupplyAmount) /
      1e12;
    params.wethSupplyAmount = wethSupplyAmount;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    vm.assume(
      params.wbtcSupplyAmount *
        50000e10 +
        params.wethSupplyAmount *
        2000 +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12 <=
        totalBorrowAmount
    );
    assertLe(
      params.wbtcSupplyAmount *
        50000e10 +
        params.wethSupplyAmount +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12,
      totalBorrowAmount,
      'supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    params.dai2BorrowAmount =
      params.daiSupplyAmount +
      params.usdxSupplyAmount *
      1e12 +
      params.wethSupplyAmount *
      2000 +
      params.wbtcSupplyAmount *
      50000e10;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = ((params.wbtcLP *
      _normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
      params.wethLP *
      _normalizedValue(params.wethSupplyAmount, wethAssetId) +
      params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(params.usdxSupplyAmount, usdxAssetId)) /
      (_normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
        _normalizedValue(params.wethSupplyAmount, wethAssetId) +
        _normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId)));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_four_assets_change_one_price(
    uint256 wbtcSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 daiSupplyAmount,
    uint256 newUsdxPrice
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    newUsdxPrice = bound(newUsdxPrice, 0, 2000e8);
    /// @dev The multiplications & divisions are to normalize asset values to stablecoin prices to ensure we stay under limits
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000e10);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000e10) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000e10 - wethSupplyAmount * 2000
    );

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.usdxSupplyAmount =
      (totalBorrowAmount -
        wbtcSupplyAmount *
        50000e10 -
        wethSupplyAmount *
        2000 -
        daiSupplyAmount) /
      1e12;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    vm.assume(
      params.wbtcSupplyAmount *
        50000e10 +
        params.wethSupplyAmount *
        2000 +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12 <=
        totalBorrowAmount
    );
    assertLe(
      params.wbtcSupplyAmount +
        params.wethSupplyAmount +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12,
      totalBorrowAmount,
      'supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    params.dai2BorrowAmount =
      params.daiSupplyAmount +
      params.usdxSupplyAmount *
      1e12 +
      params.wethSupplyAmount *
      2000 +
      params.wbtcSupplyAmount *
      50000e10;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);
    params.dai2LP = spoke2.getLiquidityPremium(params.dai2ReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = ((params.wbtcLP *
      _normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
      params.wethLP *
      _normalizedValue(params.wethSupplyAmount, wethAssetId) +
      params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(params.usdxSupplyAmount, usdxAssetId)) /
      (_normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
        _normalizedValue(params.wethSupplyAmount, wethAssetId) +
        _normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId)));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );

    // Now change the price of usdx
    oracle.setAssetPrice(usdxAssetId, newUsdxPrice);

    if (newUsdxPrice >= 1e8) {
      // If price is greater, calc remains the same
      assertApproxEqAbs(
        spoke2.getUserRiskPremium(bob),
        expectedUserRiskPremium,
        1,
        'user risk premium'
      );
    } else {
      // Otherwise, the difference from old contribution becomes dai2 contribution (100% lp)
      uint256 dai2Contribution = params.usdxSupplyAmount *
        1e8 *
        1e12 -
        params.usdxSupplyAmount *
        1e12 *
        newUsdxPrice;
      expectedUserRiskPremium = ((params.wbtcLP *
        _normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
        params.wethLP *
        _normalizedValue(params.wethSupplyAmount, wethAssetId) +
        params.daiLP *
        _normalizedValue(params.daiSupplyAmount, daiAssetId) +
        params.usdxLP *
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId) +
        params.dai2LP *
        _normalizedValue(dai2Contribution, daiAssetId)) /
        (_normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
          _normalizedValue(params.wethSupplyAmount, wethAssetId) +
          _normalizedValue(params.daiSupplyAmount, daiAssetId) +
          _normalizedValue(params.usdxSupplyAmount, usdxAssetId) +
          _normalizedValue(dai2Contribution, daiAssetId)));
    }
  }

  function test_getUserRiskPremium_fuzz_four_assets_change_lp(
    uint256 wbtcSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 daiSupplyAmount,
    uint256 newLpValue
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    // Bound LP to below dai2 so asset is still used in rp calc
    newLpValue = bound(newLpValue, 0, 99_99);
    /// @dev The multiplications & divisions are to normalize asset values to stablecoin prices to ensure we stay under limits
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000e10);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000e10) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000e10 - wethSupplyAmount * 2000
    );

    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke2].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke2].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke2].weth.reserveId;
    params.wbtcReserveId = spokeInfo[spoke2].wbtc.reserveId;
    params.dai2ReserveId = spokeInfo[spoke2].dai2.reserveId;

    params.daiSupplyAmount = daiSupplyAmount;
    params.wethSupplyAmount = wethSupplyAmount;
    params.usdxSupplyAmount =
      (totalBorrowAmount -
        wbtcSupplyAmount *
        50000e10 -
        wethSupplyAmount *
        2000 -
        daiSupplyAmount) /
      1e12;
    params.wbtcSupplyAmount = wbtcSupplyAmount;

    vm.assume(
      params.wbtcSupplyAmount *
        50000e10 +
        params.wethSupplyAmount *
        2000 +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12 <=
        totalBorrowAmount
    );
    assertLe(
      params.wbtcSupplyAmount *
        5000e10 +
        params.wethSupplyAmount *
        2000 +
        params.daiSupplyAmount +
        params.usdxSupplyAmount *
        1e12,
      totalBorrowAmount,
      'supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    params.dai2BorrowAmount =
      params.daiSupplyAmount +
      params.usdxSupplyAmount *
      1e12 +
      params.wethSupplyAmount *
      2000 +
      params.wbtcSupplyAmount *
      50000e10;

    params.daiLP = spoke2.getLiquidityPremium(params.daiReserveId);
    params.wethLP = spoke2.getLiquidityPremium(params.wethReserveId);
    params.usdxLP = spoke2.getLiquidityPremium(params.usdxReserveId);
    params.wbtcLP = spoke2.getLiquidityPremium(params.wbtcReserveId);
    params.dai2LP = spoke2.getLiquidityPremium(params.dai2ReserveId);

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wbtcReserveId, bob, params.wbtcSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wbtcReserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.wethReserveId, bob, params.wethSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.wethReserveId, true);
    }

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.daiReserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.daiReserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, params.usdxReserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, params.dai2ReserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    setUsingAsCollateral(spoke2, bob, params.dai2ReserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, params.dai2ReserveId, bob, params.dai2BorrowAmount, bob);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = ((params.wbtcLP *
      _normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
      params.wethLP *
      _normalizedValue(params.wethSupplyAmount, wethAssetId) +
      params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(params.usdxSupplyAmount, usdxAssetId)) /
      (_normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
        _normalizedValue(params.wethSupplyAmount, wethAssetId) +
        _normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId)));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );

    // Change the liquidity premium of wbtc
    spoke2.updateReserveConfig(
      params.wbtcReserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: newLpValue,
        borrowable: true,
        collateral: true
      })
    );

    expectedUserRiskPremium = ((newLpValue *
      _normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
      params.wethLP *
      _normalizedValue(params.wethSupplyAmount, wethAssetId) +
      params.daiLP *
      _normalizedValue(params.daiSupplyAmount, daiAssetId) +
      params.usdxLP *
      _normalizedValue(params.usdxSupplyAmount, usdxAssetId)) /
      (_normalizedValue(params.wbtcSupplyAmount, wbtcAssetId) +
        _normalizedValue(params.wethSupplyAmount, wethAssetId) +
        _normalizedValue(params.daiSupplyAmount, daiAssetId) +
        _normalizedValue(params.usdxSupplyAmount, usdxAssetId)));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'user risk premium'
    );
  }

  function test_getUserRiskPremium_fuzz_four_assets_prices_supply_debt(
    TestInfo memory params
  ) public {
    params.daiSupplyAmount = bound(params.daiSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.wethSupplyAmount = bound(params.wethSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.usdxSupplyAmount = bound(params.usdxSupplyAmount, 0, MAX_SUPPLY_AMOUNT);
    params.wbtcSupplyAmount = bound(params.wbtcSupplyAmount, 0, MAX_SUPPLY_AMOUNT);

    params.daiBorrowAmount = bound(params.daiBorrowAmount, 0, params.daiSupplyAmount / 2);
    params.wethBorrowAmount = bound(params.wethBorrowAmount, 0, params.wethSupplyAmount / 2);
    params.usdxBorrowAmount = bound(params.usdxBorrowAmount, 0, params.usdxSupplyAmount / 2);
    params.wbtcBorrowAmount = bound(params.wbtcBorrowAmount, 0, params.wbtcSupplyAmount / 2);

    vm.assume(
      params.daiSupplyAmount +
        params.wethSupplyAmount +
        params.usdxSupplyAmount +
        params.wbtcSupplyAmount <=
        MAX_SUPPLY_AMOUNT
    );
    vm.assume(
      params.daiBorrowAmount +
        params.wethBorrowAmount +
        params.usdxBorrowAmount +
        params.wbtcBorrowAmount <=
        MAX_SUPPLY_AMOUNT / 2
    );

    params.daiPrice = bound(params.daiPrice, 0, 1e16);
    params.wethPrice = bound(params.wethPrice, 0, 1e16);
    params.usdxPrice = bound(params.usdxPrice, 0, 1e16);
    params.wbtcPrice = bound(params.wbtcPrice, 0, 1e16);

    params.daiLP = bound(params.daiLP, 0, 1000_00);
    params.wethLP = bound(params.wethLP, 0, 1000_00);
    params.usdxLP = bound(params.usdxLP, 0, 1000_00);
    params.wbtcLP = bound(params.wbtcLP, 0, 1000_00);

    // Bob supply dai into spoke2
    if (params.daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai.reserveId, bob, params.daiSupplyAmount, bob);
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (params.wethSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].weth.reserveId,
        bob,
        params.wethSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].weth.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (params.usdxSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].usdx.reserveId,
        bob,
        params.usdxSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].usdx.reserveId, true);
    }

    // Bob supply wbtc into spoke2
    if (params.wbtcSupplyAmount > 0) {
      Utils.spokeSupply(
        spoke2,
        spokeInfo[spoke2].wbtc.reserveId,
        bob,
        params.wbtcSupplyAmount,
        bob
      );
      setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].wbtc.reserveId, true);
    }

    // Update prices
    oracle.setAssetPrice(daiAssetId, params.daiPrice);
    oracle.setAssetPrice(wethAssetId, params.wethPrice);
    oracle.setAssetPrice(usdxAssetId, params.usdxPrice);
    oracle.setAssetPrice(wbtcAssetId, params.wbtcPrice);

    // Update LPs
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].dai.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.daiLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].weth.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.wethLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].usdx.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.usdxLP,
        borrowable: true,
        collateral: true
      })
    );
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].wbtc.reserveId,
      DataTypes.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: params.wbtcLP,
        borrowable: true,
        collateral: true
      })
    );

    // Check user risk premium
    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke2),
      1,
      'user risk premium'
    );
  }

  function _normalizedValue(uint256 amount, uint256 assetId) internal returns (uint256) {
    return (amount * oracle.getAssetPrice(assetId)) / (10 ** hub.getAssetConfig(assetId).decimals);
  }

  function _calculateExpectedUserRP(address user, ISpoke spoke) internal returns (uint256) {
    uint256 assetId;
    uint256 totalDebt;
    uint256 suppliedReservesCount;
    uint256 userRP;
    DataTypes.UserPosition memory userPosition;

    // Find all reserves user has supplied, adding up total debt
    for (uint256 i; i < spoke.reserveCount(); ++i) {
      userPosition = spoke.getUserPosition(i, user);
      if (userPosition.usingAsCollateral) {
        ++suppliedReservesCount;
      }
      (assetId, ) = getAsset(spoke, i);
      totalDebt += _normalizedValue(
        userPosition.baseDebt + userPosition.outstandingPremium,
        assetId
      );
    }

    if (totalDebt == 0) {
      return 0;
    }

    // Gather up list of reserves as collateral to sort by LP
    KeyValueListInMemory.List memory reserveLP = KeyValueListInMemory.init(suppliedReservesCount);
    uint256 idx = 0;
    for (uint256 i; i < spoke.reserveCount(); ++i) {
      userPosition = spoke.getUserPosition(i, user);
      if (userPosition.usingAsCollateral) {
        reserveLP.add(idx, spoke.getLiquidityPremium(i), i);
        ++idx;
      }
    }

    // Sort supplied reserves by LP
    reserveLP.sortByKey();

    // While user's normalized debt amount is non-zero, iterate through supplied reserves, and add up LP
    idx = 0;
    uint256 originalTotalDebt = totalDebt;
    while (totalDebt > 0) {
      (uint256 lp, uint256 reserveId) = reserveLP.get(idx);
      userPosition = spoke.getUserPosition(reserveId, user);
      (assetId, ) = getAsset(spoke, reserveId);
      uint256 supplyAmount = _normalizedValue(
        hub.convertToSharesDown(assetId, userPosition.suppliedShares),
        assetId
      );

      if (supplyAmount >= totalDebt) {
        userRP += totalDebt * lp;
        break;
      } else {
        userRP += supplyAmount * lp;
        totalDebt -= supplyAmount;
      }

      ++idx;
    }

    return userRP / originalTotalDebt;
  }
}
