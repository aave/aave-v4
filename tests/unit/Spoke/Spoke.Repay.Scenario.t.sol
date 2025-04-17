// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRepayScenarioTest is SpokeBase {
  function test_repay_fuzz_multiple_users_multiple_assets(
    UserAssetInfo memory bobInfo,
    UserAssetInfo memory aliceInfo,
    UserAssetInfo memory carolInfo,
    uint40 skipTime
  ) public {
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    carolInfo = _bound(carolInfo);
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    UserAssetInfo[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

    // Calculate needed supply for each asset
    uint256 totalDaiNeeded = 0;
    uint256 totalWethNeeded = 0;
    uint256 totalUsdxNeeded = 0;
    uint256 totalWbtcNeeded = 0;

    for (uint256 i = 0; i < usersInfo.length; i++) {
      totalDaiNeeded += usersInfo[i].daiInfo.borrowAmount;
      totalWethNeeded += usersInfo[i].wethInfo.borrowAmount;
      totalUsdxNeeded += usersInfo[i].usdxInfo.borrowAmount;
      totalWbtcNeeded += usersInfo[i].wbtcInfo.borrowAmount;
    }

    // Derl supplies needed assets
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);
    Utils.supply(spoke1, _wethReserveId(spoke1), derl, totalWethNeeded, derl);
    Utils.supply(spoke1, _usdxReserveId(spoke1), derl, totalUsdxNeeded, derl);
    Utils.supply(spoke1, _wbtcReserveId(spoke1), derl, totalWbtcNeeded, derl);

    // Each user supplies collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = 0;
      uint256 wbtcCollateralNeeded = 0;

      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _daiReserveId(spoke1),
          usersInfo[i].daiInfo.borrowAmount
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _usdxReserveId(spoke1),
          usersInfo[i].usdxInfo.borrowAmount
        );
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wethReserveId(spoke1),
          usersInfo[i].wethInfo.borrowAmount
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wbtcReserveId(spoke1),
          usersInfo[i].wbtcInfo.borrowAmount
        );
      }

      // Supply weth and wbtc as collateral
      if (wethCollateralNeeded > 0) {
        deal(address(tokenList.weth), user, wethCollateralNeeded);
        Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        Utils.supply(spoke1, _wbtcReserveId(spoke1), user, wbtcCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wbtcReserveId(spoke1), true);
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].daiInfo.borrowAmount, user);
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.borrowAmount,
          user
        );
      }

      // Store supply positions before time skipping
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].daiInfo.borrowAmount, 'Initial DAI debt incorrect');

      uint256 totalWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      assertEq(totalWethDebt, usersInfo[i].wethInfo.borrowAmount, 'Initial WETH debt incorrect');

      uint256 totalUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      assertEq(totalUsdxDebt, usersInfo[i].usdxInfo.borrowAmount, 'Initial USDX debt incorrect');

      uint256 totalWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      assertEq(totalWbtcDebt, usersInfo[i].wbtcInfo.borrowAmount, 'Initial WBTC debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[4][3] memory debtsBefore; // 4 assets, 3 users
    // [dai, weth, usdx, wbtc] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Get updated supply positions after interest accrual
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Store debts before repayment
      debtsBefore[i][0] = getUserDebt(spoke1, user, _daiReserveId(spoke1));
      debtsBefore[i][1] = getUserDebt(spoke1, user, _wethReserveId(spoke1));
      debtsBefore[i][2] = getUserDebt(spoke1, user, _usdxReserveId(spoke1));
      debtsBefore[i][3] = getUserDebt(spoke1, user, _wbtcReserveId(spoke1));

      // Verify interest accrual
      assertGe(
        debtsBefore[i][0].totalDebt,
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][1].totalDebt,
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][2].totalDebt,
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][3].totalDebt,
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][0].baseDebt,
        debtsBefore[i][0].premiumDebt,
        usersInfo[i].daiInfo.repayAmount,
        daiAssetId
      );

      usersInfo[i].daiInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].daiInfo.repayAmount);
      }
      usersInfo[i].daiInfo.repayAmount = baseRestored + premiumRestored;

      // WETH repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][1].baseDebt,
        debtsBefore[i][1].premiumDebt,
        usersInfo[i].wethInfo.repayAmount,
        wethAssetId
      );
      usersInfo[i].wethInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wethAssetId) || premiumRestored > 0) {
        deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_wethReserveId(spoke1), usersInfo[i].wethInfo.repayAmount);
      }
      usersInfo[i].wethInfo.repayAmount = baseRestored + premiumRestored;

      // USDX repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][2].baseDebt,
        debtsBefore[i][2].premiumDebt,
        usersInfo[i].usdxInfo.repayAmount,
        usdxAssetId
      );

      usersInfo[i].usdxInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(usdxAssetId) || premiumRestored > 0) {
        deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_usdxReserveId(spoke1), usersInfo[i].usdxInfo.repayAmount);
      }
      usersInfo[i].usdxInfo.repayAmount = baseRestored + premiumRestored;

      // WBTC repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][3].baseDebt,
        debtsBefore[i][3].premiumDebt,
        usersInfo[i].wbtcInfo.repayAmount,
        wbtcAssetId
      );

      usersInfo[i].wbtcInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wbtcAssetId) || premiumRestored > 0) {
        deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_wbtcReserveId(spoke1), usersInfo[i].wbtcInfo.repayAmount);
      }
      usersInfo[i].wbtcInfo.repayAmount = baseRestored + premiumRestored;
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].daiInfo.repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].daiInfo.premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].daiInfo.repayAmount >= debtsBefore[i][0].totalDebt
          ? 0
          : debtsBefore[i][0].totalDebt - usersInfo[i].daiInfo.repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertApproxEqAbs(actualDaiDebt, expectedDaiDebt, 3, 'DAI debt not reduced correctly');
      }

      if (
        usersInfo[i].wethInfo.repayAmount >= minimumAssetsPerDrawnShare(wethAssetId) ||
        usersInfo[i].wethInfo.premiumRestored > 0
      ) {
        uint256 expectedWethDebt = usersInfo[i].wethInfo.repayAmount >= debtsBefore[i][1].totalDebt
          ? 0
          : debtsBefore[i][1].totalDebt - usersInfo[i].wethInfo.repayAmount;
        uint256 actualWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
        assertApproxEqAbs(actualWethDebt, expectedWethDebt, 3, 'WETH debt not reduced correctly');
      }

      if (
        usersInfo[i].usdxInfo.repayAmount >= minimumAssetsPerDrawnShare(usdxAssetId) ||
        usersInfo[i].usdxInfo.premiumRestored > 0
      ) {
        uint256 expectedUsdxDebt = usersInfo[i].usdxInfo.repayAmount >= debtsBefore[i][2].totalDebt
          ? 0
          : debtsBefore[i][2].totalDebt - usersInfo[i].usdxInfo.repayAmount;
        uint256 actualUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
        assertApproxEqAbs(actualUsdxDebt, expectedUsdxDebt, 3, 'USDX debt not reduced correctly');
      }

      if (
        usersInfo[i].wbtcInfo.repayAmount >= minimumAssetsPerDrawnShare(wbtcAssetId) ||
        usersInfo[i].wbtcInfo.premiumRestored > 0
      ) {
        uint256 expectedWbtcDebt = usersInfo[i].wbtcInfo.repayAmount >= debtsBefore[i][3].totalDebt
          ? 0
          : debtsBefore[i][3].totalDebt - usersInfo[i].wbtcInfo.repayAmount;
        uint256 actualWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
        assertApproxEqAbs(actualWbtcDebt, expectedWbtcDebt, 3, 'WBTC debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.suppliedShares,
        'DAI supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.suppliedShares,
        'USDX supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.suppliedShares,
        'WBTC supplied shares should remain unchanged'
      );
    }
  }

  function test_repay_fuzz_two_users_multiple_assets(
    UserAssetInfo memory bobInfo,
    UserAssetInfo memory aliceInfo,
    uint40 skipTime
  ) public {
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    UserAssetInfo[2] memory usersInfo = [bobInfo, aliceInfo];

    // Calculate needed supply for each asset
    uint256 totalDaiNeeded = 0;
    uint256 totalWethNeeded = 0;
    uint256 totalUsdxNeeded = 0;
    uint256 totalWbtcNeeded = 0;

    for (uint256 i = 0; i < usersInfo.length; i++) {
      totalDaiNeeded += usersInfo[i].daiInfo.borrowAmount;
      totalWethNeeded += usersInfo[i].wethInfo.borrowAmount;
      totalUsdxNeeded += usersInfo[i].usdxInfo.borrowAmount;
      totalWbtcNeeded += usersInfo[i].wbtcInfo.borrowAmount;
    }

    // Derl supplies needed assets
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);
    Utils.supply(spoke1, _wethReserveId(spoke1), derl, totalWethNeeded, derl);
    Utils.supply(spoke1, _usdxReserveId(spoke1), derl, totalUsdxNeeded, derl);
    Utils.supply(spoke1, _wbtcReserveId(spoke1), derl, totalWbtcNeeded, derl);

    // Each user supplies collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = 0;
      uint256 wbtcCollateralNeeded = 0;

      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _daiReserveId(spoke1),
          usersInfo[i].daiInfo.borrowAmount
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        wethCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wethReserveId(spoke1),
          _usdxReserveId(spoke1),
          usersInfo[i].usdxInfo.borrowAmount
        );
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wethReserveId(spoke1),
          usersInfo[i].wethInfo.borrowAmount
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          _wbtcReserveId(spoke1),
          usersInfo[i].wbtcInfo.borrowAmount
        );
      }

      // Supply weth and wbtc as collateral
      if (wethCollateralNeeded > 0) {
        deal(address(tokenList.weth), user, wethCollateralNeeded);
        Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        Utils.supply(spoke1, _wbtcReserveId(spoke1), user, wbtcCollateralNeeded, user);
        setUsingAsCollateral(spoke1, user, _wbtcReserveId(spoke1), true);
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].daiInfo.borrowAmount, user);
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.borrowAmount,
          user
        );
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        Utils.borrow(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.borrowAmount,
          user
        );
      }

      // Store supply positions before time skipping
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].daiInfo.borrowAmount, 'Initial DAI debt incorrect');

      uint256 totalWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      assertEq(totalWethDebt, usersInfo[i].wethInfo.borrowAmount, 'Initial WETH debt incorrect');

      uint256 totalUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      assertEq(totalUsdxDebt, usersInfo[i].usdxInfo.borrowAmount, 'Initial USDX debt incorrect');

      uint256 totalWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      assertEq(totalWbtcDebt, usersInfo[i].wbtcInfo.borrowAmount, 'Initial WBTC debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[4][2] memory debtsBefore; // 4 assets, 2 users
    // [dai, weth, usdx, wbtc] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Get updated supply positions after interest accrual
      usersInfo[i].daiInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _daiReserveId(spoke1),
        user
      );
      usersInfo[i].wethInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wethReserveId(spoke1),
        user
      );
      usersInfo[i].usdxInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _usdxReserveId(spoke1),
        user
      );
      usersInfo[i].wbtcInfo.suppliedShares = spoke1.getUserSuppliedShares(
        _wbtcReserveId(spoke1),
        user
      );

      // Store debts before repayment
      debtsBefore[i][0].totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      (debtsBefore[i][0].baseDebt, debtsBefore[i][0].premiumDebt) = spoke1.getUserDebt(
        _daiReserveId(spoke1),
        user
      );
      debtsBefore[i][1].totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
      (debtsBefore[i][1].baseDebt, debtsBefore[i][1].premiumDebt) = spoke1.getUserDebt(
        _wethReserveId(spoke1),
        user
      );
      debtsBefore[i][2].totalDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
      (debtsBefore[i][2].baseDebt, debtsBefore[i][2].premiumDebt) = spoke1.getUserDebt(
        _usdxReserveId(spoke1),
        user
      );
      debtsBefore[i][3].totalDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
      (debtsBefore[i][3].baseDebt, debtsBefore[i][3].premiumDebt) = spoke1.getUserDebt(
        _wbtcReserveId(spoke1),
        user
      );

      // Verify interest accrual
      assertGe(
        debtsBefore[i][0].totalDebt,
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][1].totalDebt,
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][2].totalDebt,
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );

      assertGe(
        debtsBefore[i][3].totalDebt,
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][0].baseDebt,
        debtsBefore[i][0].premiumDebt,
        usersInfo[i].daiInfo.repayAmount,
        daiAssetId
      );

      usersInfo[i].daiInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].daiInfo.repayAmount);
      }
      usersInfo[i].daiInfo.repayAmount = baseRestored + premiumRestored;

      // WETH repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][1].baseDebt,
        debtsBefore[i][1].premiumDebt,
        usersInfo[i].wethInfo.repayAmount,
        wethAssetId
      );

      usersInfo[i].wethInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wethAssetId) || premiumRestored > 0) {
        deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_wethReserveId(spoke1), usersInfo[i].wethInfo.repayAmount);
      }
      usersInfo[i].wethInfo.repayAmount = baseRestored + premiumRestored;

      // USDX repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][2].baseDebt,
        debtsBefore[i][2].premiumDebt,
        usersInfo[i].usdxInfo.repayAmount,
        usdxAssetId
      );

      usersInfo[i].usdxInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(usdxAssetId) || premiumRestored > 0) {
        deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_usdxReserveId(spoke1), usersInfo[i].usdxInfo.repayAmount);
      }
      usersInfo[i].usdxInfo.repayAmount = baseRestored + premiumRestored;

      // WBTC repayment
      (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i][3].baseDebt,
        debtsBefore[i][3].premiumDebt,
        usersInfo[i].wbtcInfo.repayAmount,
        wbtcAssetId
      );

      usersInfo[i].wbtcInfo.premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(wbtcAssetId) || premiumRestored > 0) {
        deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
        vm.prank(user);
        spoke1.repay(_wbtcReserveId(spoke1), usersInfo[i].wbtcInfo.repayAmount);
      }
      usersInfo[i].wbtcInfo.repayAmount = baseRestored + premiumRestored;
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].daiInfo.repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].daiInfo.premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].daiInfo.repayAmount >= debtsBefore[i][0].totalDebt
          ? 0
          : debtsBefore[i][0].totalDebt - usersInfo[i].daiInfo.repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertApproxEqAbs(actualDaiDebt, expectedDaiDebt, 3, 'DAI debt not reduced correctly');
      }

      if (
        usersInfo[i].wethInfo.repayAmount >= minimumAssetsPerDrawnShare(wethAssetId) ||
        usersInfo[i].wethInfo.premiumRestored > 0
      ) {
        uint256 expectedWethDebt = usersInfo[i].wethInfo.repayAmount >= debtsBefore[i][1].totalDebt
          ? 0
          : debtsBefore[i][1].totalDebt - usersInfo[i].wethInfo.repayAmount;
        uint256 actualWethDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), user);
        assertApproxEqAbs(actualWethDebt, expectedWethDebt, 3, 'WETH debt not reduced correctly');
      }

      if (
        usersInfo[i].usdxInfo.repayAmount >= minimumAssetsPerDrawnShare(usdxAssetId) ||
        usersInfo[i].usdxInfo.premiumRestored > 0
      ) {
        uint256 expectedUsdxDebt = usersInfo[i].usdxInfo.repayAmount >= debtsBefore[i][2].totalDebt
          ? 0
          : debtsBefore[i][2].totalDebt - usersInfo[i].usdxInfo.repayAmount;
        uint256 actualUsdxDebt = spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user);
        assertApproxEqAbs(actualUsdxDebt, expectedUsdxDebt, 3, 'USDX debt not reduced correctly');
      }

      if (
        usersInfo[i].wbtcInfo.repayAmount >= minimumAssetsPerDrawnShare(wbtcAssetId) ||
        usersInfo[i].wbtcInfo.premiumRestored > 0
      ) {
        uint256 expectedWbtcDebt = usersInfo[i].wbtcInfo.repayAmount >= debtsBefore[i][3].totalDebt
          ? 0
          : debtsBefore[i][3].totalDebt - usersInfo[i].wbtcInfo.repayAmount;
        uint256 actualWbtcDebt = spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user);
        assertApproxEqAbs(actualWbtcDebt, expectedWbtcDebt, 3, 'WBTC debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.suppliedShares,
        'DAI supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.suppliedShares,
        'USDX supplied shares should remain unchanged'
      );
      assertEq(
        spoke1.getUserSuppliedShares(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.suppliedShares,
        'WBTC supplied shares should remain unchanged'
      );
    }
  }

  function test_fuzz_repay_multiple_users_repay_same_reserve(
    UserAction memory bobInfo,
    UserAction memory aliceInfo,
    UserAction memory carolInfo,
    uint256 skipTime
  ) public {
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);
    carolInfo = _boundUserAction(carolInfo);

    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    UserAction[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount + carolInfo.borrowAmount;

    // Derl supplies needed DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);

    // Each user supplies needed collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        usersInfo[i].borrowAmount
      );

      // Supply WETH as collateral
      deal(address(tokenList.weth), user, wethCollateralNeeded);
      Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
      setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].borrowAmount, user);

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[3] memory debtsBefore; // 3 users
    // [bob, alice, carol] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Store debts before repayment
      debtsBefore[i] = getUserDebt(spoke1, user, _daiReserveId(spoke1));

      // Verify interest accrual
      assertGe(
        debtsBefore[i].totalDebt,
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i].baseDebt,
        debtsBefore[i].premiumDebt,
        usersInfo[i].repayAmount,
        daiAssetId
      );

      usersInfo[i].premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        vm.prank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].repayAmount);
      }
      usersInfo[i].repayAmount = baseRestored + premiumRestored;
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].repayAmount >= debtsBefore[i].totalDebt
          ? 0
          : debtsBefore[i].totalDebt - usersInfo[i].repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertApproxEqAbs(actualDaiDebt, expectedDaiDebt, 3, 'DAI debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }
  }

  function test_repay_two_users_repay_same_reserve(
    UserAction memory bobInfo,
    UserAction memory aliceInfo,
    uint256 skipTime
  ) public {
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);

    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    UserAction[2] memory usersInfo = [bobInfo, aliceInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount;

    // Derl supplies needed DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), derl, totalDaiNeeded, derl);

    // Each user supplies needed collateral and borrows
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Calculate needed collateral for this user
      uint256 wethCollateralNeeded = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        usersInfo[i].borrowAmount
      );

      // Supply WETH as collateral
      deal(address(tokenList.weth), user, wethCollateralNeeded);
      Utils.supply(spoke1, _wethReserveId(spoke1), user, wethCollateralNeeded, user);
      setUsingAsCollateral(spoke1, user, _wethReserveId(spoke1), true);

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      Utils.borrow(spoke1, _daiReserveId(spoke1), user, usersInfo[i].borrowAmount, user);

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Fetch current debts before repayment
    Debts[2] memory debtsBefore; // 2 users
    // [bob, alice] order
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Store debts before repayment
      debtsBefore[i] = getUserDebt(spoke1, user, _daiReserveId(spoke1));

      // Verify interest accrual
      assertGe(
        debtsBefore[i].totalDebt,
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        debtsBefore[i].baseDebt,
        debtsBefore[i].premiumDebt,
        usersInfo[i].repayAmount,
        daiAssetId
      );

      usersInfo[i].premiumRestored = premiumRestored;
      if (baseRestored >= minimumAssetsPerDrawnShare(daiAssetId) || premiumRestored > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        vm.prank(user);
        spoke1.repay(_daiReserveId(spoke1), usersInfo[i].repayAmount);
      }
      usersInfo[i].repayAmount = baseRestored + premiumRestored;
    }

    // Verify final state for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // Verify repayments have been applied correctly
      if (
        usersInfo[i].repayAmount >= minimumAssetsPerDrawnShare(daiAssetId) ||
        usersInfo[i].premiumRestored > 0
      ) {
        uint256 expectedDaiDebt = usersInfo[i].repayAmount >= debtsBefore[i].totalDebt
          ? 0
          : debtsBefore[i].totalDebt - usersInfo[i].repayAmount;
        uint256 actualDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
        assertApproxEqAbs(actualDaiDebt, expectedDaiDebt, 3, 'DAI debt not reduced correctly');
      }

      // Verify supply positions remain unchanged
      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }
  }

  /// Borrow, repay, borrow more, repay
  function test_fuzz_repay_borrow_twice_repay_twice(
    Action memory action1,
    Action memory action2
  ) public {
    action1.skipTime = uint40(bound(action1.skipTime, 1, MAX_SKIP_TIME / 2));
    action2.skipTime = uint40(bound(action2.skipTime, 1, MAX_SKIP_TIME / 2));
    action1.borrowAmount = bound(action1.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action2.borrowAmount = bound(action2.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action1.repayAmount = bound(action1.repayAmount, 1, action1.borrowAmount);
    action2.repayAmount = bound(action2.repayAmount, 1, action2.borrowAmount);

    // Enough funds to cover 2 repayments
    deal(address(tokenList.dai), bob, action1.repayAmount + action2.repayAmount);

    // Bob supply weth as collateral
    action1.supplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      action1.borrowAmount
    );
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, action1.supplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supply dai
    Utils.supply(
      spoke1,
      _daiReserveId(spoke1),
      alice,
      action1.borrowAmount + action2.borrowAmount,
      alice
    );

    // Bob borrow dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, action1.borrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, action1.borrowAmount, 'bob dai debt before');
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Time passes
    skip(action1.skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    assertGe(bobDaiBefore.totalDebt, action1.borrowAmount, 'bob dai debt before');
    assertGe(bobDaiBefore.premiumDebt, 0, 'bob dai premium debt before');

    // Bob repays the first repay amount
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      action1.repayAmount,
      daiAssetId
    );

    if (action1.repayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), action1.repayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    action1.repayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - action1.repayAmount,
      3,
      'bob dai debt final balance'
    );
    assertApproxEqAbs(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - action1.repayAmount,
      3,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);
    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    // Supply more collateral if not enough
    {
      uint256 totalCollateral = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob) + action2.borrowAmount
      );
      action2.supplyAmount = action1.supplyAmount > totalCollateral
        ? 0
        : totalCollateral - action1.supplyAmount;
      if (action2.supplyAmount > 0) {
        Utils.supply(spoke1, _wethReserveId(spoke1), bob, action2.supplyAmount, bob);
      }
    }

    // Reuse variables for second borrow and repay round
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);

    // Bob borrows more dai
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, action2.borrowAmount, bob);

    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt + action2.borrowAmount,
      2,
      'bob dai debt after second borrow'
    );

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);
    bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount + action2.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(action2.skipTime);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      bobDaiBefore.totalDebt,
      'bob dai debt before second repay'
    );
    bobDaiBefore = getUserDebt(spoke1, bob, _daiReserveId(spoke1));

    // Bob repays the second repay amount
    (baseRestored, premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      action2.repayAmount,
      daiAssetId
    );

    if (action2.repayAmount == 0) {
      vm.expectRevert(ILiquidityHub.InvalidRestoreAmount.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        hub.convertToDrawnShares(daiAssetId, baseRestored)
      );
    }

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), action2.repayAmount);

    bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiAfter = getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    action2.repayAmount = baseRestored + premiumRestored;

    assertEq(bobDaiDataAfter.suppliedShares, bobDaiDataBefore.suppliedShares);
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      bobDaiBefore.totalDebt - action2.repayAmount,
      3,
      'bob dai debt final balance'
    );
    assertApproxEqAbs(
      tokenList.dai.balanceOf(bob),
      bobDaiBalanceBefore - action2.repayAmount,
      3,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub.convertToSuppliedShares(wethAssetId, action1.supplyAmount + action2.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);
  }

  function test_repay_partial_then_max() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supplies WETH as collateral
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, wethSupplyAmount, bob);
    setUsingAsCollateral(spoke1, bob, _wethReserveId(spoke1), true);

    // Alice supplies DAI
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, daiSupplyAmount, alice);

    // Bob borrows DAI
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiBorrowAmount, bob);

    DataTypes.UserPosition memory bobDaiDataBefore = getUserInfo(
      spoke1,
      bob,
      _daiReserveId(spoke1)
    );
    Debts memory bobDaiBefore;
    Debts memory bobWethBefore;
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobWethBefore.totalDebt = spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob);

    uint256 bobDaiBalanceBefore = tokenList.dai.balanceOf(bob);

    assertEq(bobDaiDataBefore.suppliedShares, 0);
    assertEq(bobDaiBefore.totalDebt, daiBorrowAmount, 'Initial bob dai debt');

    // Time passes so that interest accrues
    skip(10 days);

    bobDaiDataBefore = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiBefore.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiBefore.baseDebt, bobDaiBefore.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    // Bob's debt (base debt + premium) is greater than the original borrow amount
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    // Calculate full debt before repayment
    uint256 fullDebt = bobDaiBefore.baseDebt + bobDaiBefore.premiumDebt;
    uint256 partialRepayAmount = fullDebt / 2;

    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      bobDaiBefore.baseDebt,
      bobDaiBefore.premiumDebt,
      partialRepayAmount,
      daiAssetId
    );

    // Partial repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );

    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), partialRepayAmount);

    DataTypes.UserPosition memory bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    Debts memory bobDaiAfter;
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    uint256 bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);
    partialRepayAmount = baseRestored + premiumRestored;

    // Verify that Bob's debt is reduced after partial repayment
    assertApproxEqAbs(
      bobDaiAfter.totalDebt,
      fullDebt - partialRepayAmount,
      1,
      'Bob dai debt should be reduced'
    );
    // Verify that his DAI balance was reduced by the partial debt amount
    assertApproxEqAbs(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - partialRepayAmount,
      1,
      'Bob dai balance decreased by partial debt repaid'
    );
    // Verify reserve debt was decreased by partial repayment
    assertApproxEqAbs(
      spoke1.getReserveTotalDebt(_daiReserveId(spoke1)),
      fullDebt - partialRepayAmount,
      1
    );

    // verify LH asset debt is decreased by partial repayment
    assertApproxEqAbs(
      hub.getAssetTotalDebt(_daiReserveId(spoke1)),
      fullDebt - partialRepayAmount,
      1
    );

    (baseRestored, ) = _calculateExactRestoreAmount(
      bobDaiAfter.baseDebt,
      bobDaiAfter.premiumDebt,
      bobDaiAfter.totalDebt,
      daiAssetId
    );

    // Full repay
    vm.expectEmit(address(spoke1));
    emit ISpoke.Repay(
      _daiReserveId(spoke1),
      bob,
      hub.convertToDrawnShares(daiAssetId, baseRestored)
    );

    // Bob repays using the max value to signal full repayment
    vm.prank(bob);
    spoke1.repay(_daiReserveId(spoke1), type(uint256).max);

    bobDaiDataAfter = getUserInfo(spoke1, bob, _daiReserveId(spoke1));
    bobDaiAfter.totalDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    (bobDaiAfter.baseDebt, bobDaiAfter.premiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );
    bobDaiBalanceAfter = tokenList.dai.balanceOf(bob);

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(bobDaiAfter.totalDebt, 0, 'Bob dai debt should be cleared');

    // Verify that his DAI balance was reduced by the full debt amount
    assertApproxEqAbs(
      bobDaiBalanceAfter,
      bobDaiBalanceBefore - fullDebt,
      1,
      'Bob dai balance decreased by full debt repaid'
    );

    // Verify reserve debt is 0
    (uint256 baseDaiDebt, uint256 premiumDaiDebt) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(premiumDaiDebt, 0);

    // verify LH asset debt is 0
    assertEq(hub.getAssetTotalDebt(_daiReserveId(spoke1)), 0);
  }
}
