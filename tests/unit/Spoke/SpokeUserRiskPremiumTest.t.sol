// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeUserRiskPremiumTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // TODO: Use new getters to retrieve information
  // TODO: Create structs to clean up these tests

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
    uint256 daiLP;
    uint256 wethLP;
    uint256 usdxLP;
    uint256 wbtcLP;
    uint256 dai2LP;
  }

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_getUserRiskPremium_no_collateral() public view {
    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 daiAmount = 100e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, true);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, 0, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_single_asset_collateral_borrowed() public {
    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 supplyAmount = 100e18;
    uint256 borrowAmount = 50e18;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, true);
    Utils.spokeBorrow(spoke1, daiReserveId, bob, borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, daiInfo.config.liquidityPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_single_asset_collateral_borrowed_amount(
    uint256 borrowAmount
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT);

    TestInfo memory params;
    params.borrowAmount = borrowAmount;

    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.supplyAmount = borrowAmount * 2;

    params.daiLP = spoke1.getReserve(params.daiReserveId).config.liquidityPremium;

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, params.supplyAmount);
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(spoke1.getUserRiskPremium(bob), params.daiLP, 'wrong user risk premium');
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

    params.daiLP = spoke1.getReserve(params.daiReserveId).config.liquidityPremium;

    // Bob supply dai into spoke1
    deal(address(tokenList.dai), bob, params.supplyAmount);
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.supplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.borrowAmount, bob);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);

    // With single collateral, user rp will match liquidity premium of collateral
    assertEq(userRiskPremium, params.daiLP, 'wrong user risk premium');

    // Supplying more risky asset (usdx) should not impact user risk premium
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, additionalSupplyAmount, bob);
    assertEq(spoke1.getUserRiskPremium(bob), userRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_multi_asset_collateral() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 1000e18;
    params.usdxSupplyAmount = 1000e18;
    params.wethSupplyAmount = 1000e18;
    params.daiBorrowAmount = 1000e18;
    params.usdxBorrowAmount = 1000e18;

    params.daiLP = spoke1.getReserve(params.daiReserveId).config.liquidityPremium;
    params.usdxLP = spoke1.getReserve(params.usdxReserveId).config.liquidityPremium;
    params.wethLP = spoke1.getReserve(params.wethReserveId).config.liquidityPremium;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiBorrowAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxBorrowAmount, bob);

    // Weth is enough to cover the total debt
    uint256 expectedUserRiskPremium = params.wethLP;

    Spoke.UserConfig memory userConfig = spoke1.getUser(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.daiSupplyAmount);

    userConfig = spoke1.getUser(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.usdxSupplyAmount);

    userConfig = spoke1.getUser(params.wethReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(wethAssetId, params.wethSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_multi_asset_collateral_weth_partial_cover() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 2000e18;
    params.wethSupplyAmount = 1e18;

    params.daiLP = spoke1.getReserve(params.daiReserveId).config.liquidityPremium;
    params.usdxLP = spoke1.getReserve(params.usdxReserveId).config.liquidityPremium;
    params.wethLP = spoke1.getReserve(params.wethReserveId).config.liquidityPremium;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Bob supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, bob, params.wethSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.wethReserveId, true);

    // Bob draw 2000 total dai + usdx
    Utils.spokeBorrow(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.spokeBorrow(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);

    Spoke.UserConfig memory userConfig = spoke1.getUser(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.daiSupplyAmount);

    userConfig = spoke1.getUser(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, params.usdxSupplyAmount);

    userConfig = spoke1.getUser(params.wethReserveId, bob);
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

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_two_assets_equal_parts() public {
    TestInfo memory params;
    params.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    params.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    params.wethReserveId = spokeInfo[spoke1].weth.reserveId;

    params.daiSupplyAmount = 2000e18;
    params.usdxSupplyAmount = 6000e18;
    params.wethSupplyAmount = 10e18;

    params.wethBorrowAmount = 2e18;

    params.daiLP = spoke1.getReserve(params.daiReserveId).config.liquidityPremium;
    params.usdxLP = spoke1.getReserve(params.usdxReserveId).config.liquidityPremium;
    params.wethLP = spoke1.getReserve(params.wethReserveId).config.liquidityPremium;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, params.daiReserveId, bob, params.daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.daiReserveId, true);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, params.usdxReserveId, bob, params.usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, params.usdxReserveId, true);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, params.wethReserveId, alice, params.wethSupplyAmount, alice);
    Utils.setUsingAsCollateral(spoke1, alice, params.wethReserveId, true);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, params.wethReserveId, bob, params.wethBorrowAmount, bob);

    Spoke.UserConfig memory userConfig = spoke1.getUser(params.daiReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(daiAssetId, params.daiSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUser(params.usdxReserveId, bob);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(usdxAssetId, params.usdxSupplyAmount)
    );
    assertEq(userConfig.baseDebt, 0);

    userConfig = spoke1.getUser(params.wethReserveId, bob);
    assertEq(userConfig.baseDebt, params.wethBorrowAmount);

    userConfig = spoke1.getUser(params.wethReserveId, alice);
    assertEq(
      userConfig.suppliedShares,
      hub.convertToSharesDown(wethAssetId, params.wethSupplyAmount)
    );

    // Dai and usdx will each cover half the debt
    uint256 equalDebtContribution = 2000e18;
    uint256 expectedUserRiskPremium = (params.daiLP *
      equalDebtContribution *
      oracle.getAssetPrice(daiAssetId) +
      params.usdxLP *
      equalDebtContribution *
      oracle.getAssetPrice(usdxAssetId)) /
      (equalDebtContribution *
        oracle.getAssetPrice(daiAssetId) +
        equalDebtContribution *
        oracle.getAssetPrice(usdxAssetId));

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_two_assets_diff_amounts(uint256 daiSupplyAmount) public {
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, 4000e18);
    uint256 usdxLpContributionAmount = 4000e18 - daiSupplyAmount;

    uint256 daiReserveId = spokeInfo[spoke1].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke1].weth.reserveId;

    uint256 usdxSupplyAmount = 6000e18;
    uint256 wethSupplyAmount = 10e18;

    uint256 wethBorrowAmount = 2e18;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke1
    Utils.spokeSupply(spoke1, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke1
    Utils.spokeSupply(spoke1, usdxReserveId, bob, usdxSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke1, bob, usdxReserveId, usingAsCollateral);

    // Alice supply weth into spoke1
    Utils.spokeSupply(spoke1, wethReserveId, alice, wethSupplyAmount, alice);
    Utils.setUsingAsCollateral(spoke1, alice, wethReserveId, usingAsCollateral);

    // Bob draw $4000 total in weth
    Utils.spokeBorrow(spoke1, wethReserveId, bob, wethBorrowAmount, bob);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke1.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke1.getReserve(wethReserveId);

    // Dai and usdx will each cover half the debt
    uint256 expectedUserRiskPremium = (daiInfo.config.liquidityPremium *
      daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId) +
      usdxInfo.config.liquidityPremium *
      usdxLpContributionAmount *
      oracle.getAssetPrice(usdxAssetId)) /
      (daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxLpContributionAmount *
        oracle.getAssetPrice(usdxAssetId));

    uint256 userRiskPremium = spoke1.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_two_assets_supply_and_borrow(
    uint256 daiSupplyAmount
  ) public {
    /// @dev We supply with a high value lp asset so it's ignored in rp calcs, but allows user to borrow large amounts
    /// @dev We borrow with any asset because only it's value is important, it's lp is ignored
    /// @dev We fix borrow amount, and fuzz the supply amounts, checking rp calc is correct
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    // Dai lp to account for up to 100% of the debt value
    daiSupplyAmount = bound(daiSupplyAmount, 1, totalBorrowAmount);
    uint256 usdxSupplyAmount = totalBorrowAmount - daiSupplyAmount;
    uint256 wethSupplyAmount = MAX_SUPPLY_AMOUNT;

    assertEq(daiSupplyAmount + usdxSupplyAmount, totalBorrowAmount, 'wrong supply amounts');

    uint256 daiReserveId = spokeInfo[spoke3].dai.reserveId;
    uint256 usdxReserveId = spokeInfo[spoke3].usdx.reserveId;
    uint256 wethReserveId = spokeInfo[spoke3].weth.reserveId;

    // Borrow all value in weth. Each weth is 2000 stablecoins
    uint256 wethBorrowAmount = totalBorrowAmount / 2000;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke3
    Utils.spokeSupply(spoke3, daiReserveId, bob, daiSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke3, bob, daiReserveId, usingAsCollateral);

    // Bob supply usdx into spoke3
    if (usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, usdxReserveId, bob, usdxSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke3, bob, usdxReserveId, usingAsCollateral);
    }

    // Bob supply weth into spoke3
    Utils.spokeSupply(spoke3, wethReserveId, bob, wethSupplyAmount, bob);
    Utils.setUsingAsCollateral(spoke3, bob, wethReserveId, usingAsCollateral);

    // Bob draw weth
    Utils.spokeBorrow(spoke3, wethReserveId, bob, wethBorrowAmount, bob);

    Spoke.Reserve memory daiInfo = spoke3.getReserve(daiReserveId);
    Spoke.Reserve memory usdxInfo = spoke3.getReserve(usdxReserveId);
    Spoke.Reserve memory wethInfo = spoke3.getReserve(wethReserveId);

    // Dai and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = (daiInfo.config.liquidityPremium *
      daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId) +
      usdxInfo.config.liquidityPremium *
      usdxSupplyAmount *
      oracle.getAssetPrice(usdxAssetId)) /
      (daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    uint256 userRiskPremium = spoke3.getUserRiskPremium(bob);
    assertEq(userRiskPremium, expectedUserRiskPremium, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_three_assets_supply_and_borrow(
    uint256 daiSupplyAmount,
    uint256 usdxSupplyAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;
    uint256 wbtcSupplyAmount = MAX_SUPPLY_AMOUNT;

    daiSupplyAmount = bound(daiSupplyAmount, 0, totalBorrowAmount);
    usdxSupplyAmount = bound(usdxSupplyAmount, 0, totalBorrowAmount - daiSupplyAmount);
    uint256 wethSupplyAmount = totalBorrowAmount - daiSupplyAmount - usdxSupplyAmount;

    vm.assume(daiSupplyAmount + usdxSupplyAmount + wethSupplyAmount == totalBorrowAmount);
    assertEq(
      daiSupplyAmount + usdxSupplyAmount + wethSupplyAmount,
      totalBorrowAmount,
      'wrong supply amounts'
    );

    // Borrow all value in wbtc. Each wbtc is 50000 stablecoins, weth is 2000
    uint256 wbtcBorrowAmount = (daiSupplyAmount + usdxSupplyAmount + (wethSupplyAmount * 2000)) /
      50000;

    bool usingAsCollateral = true;

    // Bob supply dai into spoke3
    if (daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, spokeInfo[spoke3].dai.reserveId, bob, daiSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke3, bob, spokeInfo[spoke3].dai.reserveId, usingAsCollateral);
    }

    // Bob supply usdx into spoke3
    if (usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, spokeInfo[spoke3].usdx.reserveId, bob, usdxSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke3, bob, spokeInfo[spoke3].usdx.reserveId, usingAsCollateral);
    }

    // Bob supply weth into spoke3
    if (wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke3, spokeInfo[spoke3].weth.reserveId, bob, wethSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke3, bob, spokeInfo[spoke3].weth.reserveId, usingAsCollateral);
    }

    // Bob supply wbtc into spoke3
    Utils.spokeSupply(spoke3, spokeInfo[spoke3].wbtc.reserveId, bob, wbtcSupplyAmount, bob);

    // Bob draw wbtc
    Utils.spokeBorrow(spoke3, spokeInfo[spoke3].wbtc.reserveId, bob, wbtcBorrowAmount, bob);

    Spoke.Reserve memory daiInfo = spoke3.getReserve(spokeInfo[spoke3].dai.reserveId);
    Spoke.Reserve memory usdxInfo = spoke3.getReserve(spokeInfo[spoke3].usdx.reserveId);
    Spoke.Reserve memory wethInfo = spoke3.getReserve(spokeInfo[spoke3].weth.reserveId);

    // Dai, usdx, and weth will each cover part of the debt
    uint256 expectedUserRiskPremium = ((daiInfo.config.liquidityPremium *
      daiSupplyAmount *
      oracle.getAssetPrice(daiAssetId) +
      usdxInfo.config.liquidityPremium *
      usdxSupplyAmount *
      oracle.getAssetPrice(usdxAssetId)) +
      (wethSupplyAmount * oracle.getAssetPrice(wethAssetId) * wethInfo.config.liquidityPremium)) /
      (daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId));

    uint256 userRiskPremium = spoke3.getUserRiskPremium(bob);
    assertApproxEqAbs(userRiskPremium, expectedUserRiskPremium, 1, 'wrong user risk premium');
  }

  function test_getUserRiskPremium_fuzz_four_assets_supply_and_borrow(
    uint256 wbtcSupplyAmount,
    uint256 wethSupplyAmount,
    uint256 daiSupplyAmount
  ) public {
    uint256 totalBorrowAmount = MAX_SUPPLY_AMOUNT / 2;

    /// @dev The multiplications & divisions are to normalize asset values to stablecoin prices to ensure we stay under limits
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000 - wethSupplyAmount * 2000
    );
    uint256 usdxSupplyAmount = totalBorrowAmount -
      wbtcSupplyAmount *
      50000 -
      wethSupplyAmount *
      2000 -
      daiSupplyAmount;

    vm.assume(
      wbtcSupplyAmount * 50000 + wethSupplyAmount * 2000 + daiSupplyAmount + usdxSupplyAmount <=
        totalBorrowAmount
    );
    assertLe(
      wbtcSupplyAmount + wethSupplyAmount + daiSupplyAmount + usdxSupplyAmount,
      totalBorrowAmount,
      'wrong supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    uint256 dai2BorrowAmount = daiSupplyAmount +
      usdxSupplyAmount +
      wethSupplyAmount *
      2000 +
      wbtcSupplyAmount *
      50000;

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].wbtc.reserveId, bob, wbtcSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].wbtc.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].weth.reserveId, bob, wethSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].weth.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai.reserveId, bob, daiSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].usdx.reserveId, bob, usdxSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].usdx.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai2.reserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, dai2BorrowAmount, bob);

    Spoke.Reserve memory wbtcInfo = spoke2.getReserve(spokeInfo[spoke2].wbtc.reserveId);
    Spoke.Reserve memory wethInfo = spoke2.getReserve(spokeInfo[spoke2].weth.reserveId);
    Spoke.Reserve memory daiInfo = spoke2.getReserve(spokeInfo[spoke2].dai.reserveId);
    Spoke.Reserve memory usdxInfo = spoke2.getReserve(spokeInfo[spoke2].usdx.reserveId);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = (
      (wbtcInfo.config.liquidityPremium *
        wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) *
        wethInfo.config.liquidityPremium +
        daiInfo.config.liquidityPremium *
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxInfo.config.liquidityPremium *
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId))
    ) /
      (wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'wrong user risk premium'
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
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000 - wethSupplyAmount * 2000
    );
    uint256 usdxSupplyAmount = totalBorrowAmount -
      wbtcSupplyAmount *
      50000 -
      wethSupplyAmount *
      2000 -
      daiSupplyAmount;

    vm.assume(
      wbtcSupplyAmount * 50000 + wethSupplyAmount * 2000 + daiSupplyAmount + usdxSupplyAmount <=
        totalBorrowAmount
    );
    assertLe(
      wbtcSupplyAmount + wethSupplyAmount + daiSupplyAmount + usdxSupplyAmount,
      totalBorrowAmount,
      'wrong supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    uint256 dai2BorrowAmount = daiSupplyAmount +
      usdxSupplyAmount +
      wethSupplyAmount *
      2000 +
      wbtcSupplyAmount *
      50000;

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].wbtc.reserveId, bob, wbtcSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].wbtc.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].weth.reserveId, bob, wethSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].weth.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai.reserveId, bob, daiSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].usdx.reserveId, bob, usdxSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].usdx.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai2.reserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, dai2BorrowAmount, bob);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = (
      (0 *
        wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) *
        10_00 +
        20_00 *
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        50_00 *
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId))
    ) /
      (wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'wrong user risk premium'
    );

    // Now change the price of usdx
    oracle.setAssetPrice(usdxAssetId, newUsdxPrice);

    if (newUsdxPrice >= 1e8) {
      // If price is greater, calc remains the same
      assertApproxEqAbs(
        spoke2.getUserRiskPremium(bob),
        expectedUserRiskPremium,
        1,
        'wrong user risk premium'
      );
    } else {
      // Otherwise, the difference from old contribution becomes dai2 contribution (100% lp)
      uint256 dai2Contribution = usdxSupplyAmount * 1e8 - usdxSupplyAmount * newUsdxPrice;
      expectedUserRiskPremium =
        (0 *
          wbtcSupplyAmount *
          oracle.getAssetPrice(wbtcAssetId) +
          wethSupplyAmount *
          oracle.getAssetPrice(wethAssetId) *
          10_00 +
          20_00 *
          daiSupplyAmount *
          oracle.getAssetPrice(daiAssetId) +
          50_00 *
          usdxSupplyAmount *
          newUsdxPrice +
          dai2Contribution *
          100_00) /
        (wbtcSupplyAmount *
          oracle.getAssetPrice(wbtcAssetId) +
          wethSupplyAmount *
          oracle.getAssetPrice(wethAssetId) +
          daiSupplyAmount *
          oracle.getAssetPrice(daiAssetId) +
          usdxSupplyAmount *
          newUsdxPrice +
          dai2Contribution);
    }
  }

  // TODO: Test where we change one of the liquidity premiums to make our current data structure out of order to ensure ordering works
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
    wbtcSupplyAmount = bound(wbtcSupplyAmount, 0, totalBorrowAmount / 50000);
    wethSupplyAmount = bound(
      wethSupplyAmount,
      0,
      (totalBorrowAmount - wbtcSupplyAmount * 50000) / 2000
    );
    daiSupplyAmount = bound(
      daiSupplyAmount,
      0,
      totalBorrowAmount - wbtcSupplyAmount * 50000 - wethSupplyAmount * 2000
    );
    uint256 usdxSupplyAmount = totalBorrowAmount -
      wbtcSupplyAmount *
      50000 -
      wethSupplyAmount *
      2000 -
      daiSupplyAmount;

    vm.assume(
      wbtcSupplyAmount * 50000 + wethSupplyAmount * 2000 + daiSupplyAmount + usdxSupplyAmount <=
        totalBorrowAmount
    );
    assertLe(
      wbtcSupplyAmount + wethSupplyAmount + daiSupplyAmount + usdxSupplyAmount,
      totalBorrowAmount,
      'wrong supply amounts'
    );

    // Borrow all value in dai2. Each wbtc is 50000 stablecoins, weth is 2000
    uint256 dai2BorrowAmount = daiSupplyAmount +
      usdxSupplyAmount +
      wethSupplyAmount *
      2000 +
      wbtcSupplyAmount *
      50000;

    // Handle supplying max of both dai and dai2
    deal(address(tokenList.dai), bob, MAX_SUPPLY_AMOUNT * 2);

    // Bob supply wbtc into spoke2
    if (wbtcSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].wbtc.reserveId, bob, wbtcSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].wbtc.reserveId, true);
    }

    // Bob supply weth into spoke2
    if (wethSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].weth.reserveId, bob, wethSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].weth.reserveId, true);
    }

    // Bob supply dai into spoke2
    if (daiSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai.reserveId, bob, daiSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai.reserveId, true);
    }

    // Bob supply usdx into spoke2
    if (usdxSupplyAmount > 0) {
      Utils.spokeSupply(spoke2, spokeInfo[spoke2].usdx.reserveId, bob, usdxSupplyAmount, bob);
      Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].usdx.reserveId, true);
    }

    // Bob supply dai2 into spoke2
    Utils.spokeSupply(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, MAX_SUPPLY_AMOUNT, bob);
    Utils.setUsingAsCollateral(spoke2, bob, spokeInfo[spoke2].dai2.reserveId, true);

    // Bob draw dai2
    Utils.spokeBorrow(spoke2, spokeInfo[spoke2].dai2.reserveId, bob, dai2BorrowAmount, bob);

    // wbtc, weth, dai, and usdx will each cover part of the debt
    uint256 expectedUserRiskPremium = (
      (0 *
        wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) *
        10_00 +
        20_00 *
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        50_00 *
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId))
    ) /
      (wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'wrong user risk premium'
    );

    // Change the liquidity premium of wbtc
    spoke2.updateReserveConfig(
      spokeInfo[spoke2].wbtc.reserveId,
      Spoke.ReserveConfig({
        lt: 0.8e4,
        lb: 0,
        liquidityPremium: newLpValue,
        borrowable: true,
        collateral: true
      })
    );

    expectedUserRiskPremium =
      (
        (newLpValue *
          wbtcSupplyAmount *
          oracle.getAssetPrice(wbtcAssetId) +
          wethSupplyAmount *
          oracle.getAssetPrice(wethAssetId) *
          10_00 +
          20_00 *
          daiSupplyAmount *
          oracle.getAssetPrice(daiAssetId) +
          50_00 *
          usdxSupplyAmount *
          oracle.getAssetPrice(usdxAssetId))
      ) /
      (wbtcSupplyAmount *
        oracle.getAssetPrice(wbtcAssetId) +
        wethSupplyAmount *
        oracle.getAssetPrice(wethAssetId) +
        daiSupplyAmount *
        oracle.getAssetPrice(daiAssetId) +
        usdxSupplyAmount *
        oracle.getAssetPrice(usdxAssetId));

    assertApproxEqAbs(
      spoke2.getUserRiskPremium(bob),
      expectedUserRiskPremium,
      1,
      'wrong user risk premium'
    );
  }
}
