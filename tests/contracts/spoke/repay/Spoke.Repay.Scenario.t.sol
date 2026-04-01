// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeRepayScenarioTest is Base {
  using SafeCast for uint256;

  struct RepayAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint40 skipTime;
  }

  struct RepayAssetInfo {
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    uint256 suppliedShares;
  }

  struct RepayUserAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 suppliedShares;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    address user;
  }

  struct RepayUserAssetInfo {
    RepayAssetInfo daiInfo;
    RepayAssetInfo wethInfo;
    RepayAssetInfo usdxInfo;
    RepayAssetInfo wbtcInfo;
    address user;
  }

  function test_repay_fuzz_multiple_users_multiple_assets(
    RepayUserAssetInfo memory bobInfo,
    RepayUserAssetInfo memory aliceInfo,
    RepayUserAssetInfo memory carolInfo,
    uint40 skipTime
  ) public {
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    carolInfo = _bound(carolInfo);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    RepayUserAssetInfo[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

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
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: derl,
      amount: totalDaiNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: derl,
      amount: totalWethNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: derl,
      amount: totalUsdxNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      caller: derl,
      amount: totalWbtcNeeded,
      onBehalfOf: derl
    });

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
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
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
        SpokeActions.supplyCollateral({
          spoke: spoke1,
          reserveId: _wethReserveId(spoke1),
          caller: user,
          amount: wethCollateralNeeded,
          onBehalfOf: user
        });
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        SpokeActions.supplyCollateral({
          spoke: spoke1,
          reserveId: _wbtcReserveId(spoke1),
          caller: user,
          amount: wbtcCollateralNeeded,
          onBehalfOf: user
        });
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _daiReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].daiInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _wethReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].wethInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _usdxReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].usdxInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _wbtcReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].wbtcInfo.borrowAmount,
          onBehalfOf: user
        });
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

    // Update supply positions and verify interest accrual
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

      // Verify interest accrual
      assertGe(
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _daiReserveId(spoke1),
          user,
          usersInfo[i].daiInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _daiReserveId(spoke1),
              user: user,
              amount: usersInfo[i].daiInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].daiInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'DAI debt not reduced correctly'
          );
        }
      }

      // WETH repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _wethReserveId(spoke1),
              user: user,
              amount: usersInfo[i].wethInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].wethInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'WETH debt not reduced correctly'
          );
        }
      }

      // USDX repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _usdxReserveId(spoke1),
              user: user,
              amount: usersInfo[i].usdxInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].usdxInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'USDX debt not reduced correctly'
          );
        }
      }

      // WBTC repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _wbtcReserveId(spoke1),
              user: user,
              amount: usersInfo[i].wbtcInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].wbtcInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'WBTC debt not reduced correctly'
          );
        }
      }
    }

    // Verify Supply positions remain unchanged for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

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
    RepayUserAssetInfo memory bobInfo,
    RepayUserAssetInfo memory aliceInfo,
    uint40 skipTime
  ) public {
    bobInfo = _bound(bobInfo);
    aliceInfo = _bound(aliceInfo);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    RepayUserAssetInfo[2] memory usersInfo = [bobInfo, aliceInfo];

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
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: derl,
      amount: totalDaiNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: derl,
      amount: totalWethNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: derl,
      amount: totalUsdxNeeded,
      onBehalfOf: derl
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wbtcReserveId(spoke1),
      caller: derl,
      amount: totalWbtcNeeded,
      onBehalfOf: derl
    });

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
        wbtcCollateralNeeded += _calcMinimumCollAmount(
          spoke1,
          _wbtcReserveId(spoke1),
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
        SpokeActions.supplyCollateral({
          spoke: spoke1,
          reserveId: _wethReserveId(spoke1),
          caller: user,
          amount: wethCollateralNeeded,
          onBehalfOf: user
        });
      }

      if (wbtcCollateralNeeded > 0) {
        deal(address(tokenList.wbtc), user, wbtcCollateralNeeded);
        SpokeActions.supplyCollateral({
          spoke: spoke1,
          reserveId: _wbtcReserveId(spoke1),
          caller: user,
          amount: wbtcCollateralNeeded,
          onBehalfOf: user
        });
      }

      // Borrow assets based on fuzzed amounts
      if (usersInfo[i].daiInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _daiReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].daiInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].wethInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _wethReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].wethInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].usdxInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _usdxReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].usdxInfo.borrowAmount,
          onBehalfOf: user
        });
      }

      if (usersInfo[i].wbtcInfo.borrowAmount > 0) {
        SpokeActions.borrow({
          spoke: spoke1,
          reserveId: _wbtcReserveId(spoke1),
          caller: user,
          amount: usersInfo[i].wbtcInfo.borrowAmount,
          onBehalfOf: user
        });
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

    // Update supply positions and verify interest accrual
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

      // Verify interest accrual
      assertGe(
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), user),
        usersInfo[i].daiInfo.borrowAmount,
        'DAI debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_wethReserveId(spoke1), user),
        usersInfo[i].wethInfo.borrowAmount,
        'WETH debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_usdxReserveId(spoke1), user),
        usersInfo[i].usdxInfo.borrowAmount,
        'USDX debt should accrue interest'
      );
      assertGe(
        spoke1.getUserTotalDebt(_wbtcReserveId(spoke1), user),
        usersInfo[i].wbtcInfo.borrowAmount,
        'WBTC debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      // DAI repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _daiReserveId(spoke1),
          user,
          usersInfo[i].daiInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.dai), user, usersInfo[i].daiInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _daiReserveId(spoke1),
              user: user,
              amount: usersInfo[i].daiInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].daiInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'DAI debt not reduced correctly'
          );
        }
      }

      // WETH repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _wethReserveId(spoke1),
          user,
          usersInfo[i].wethInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.weth), user, usersInfo[i].wethInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _wethReserveId(spoke1),
              user: user,
              amount: usersInfo[i].wethInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].wethInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'WETH debt not reduced correctly'
          );
        }
      }

      // USDX repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _usdxReserveId(spoke1),
          user,
          usersInfo[i].usdxInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.usdx), user, usersInfo[i].usdxInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _usdxReserveId(spoke1),
              user: user,
              amount: usersInfo[i].usdxInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].usdxInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'USDX debt not reduced correctly'
          );
        }
      }

      // WBTC repayment
      {
        (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
          spoke1,
          _wbtcReserveId(spoke1),
          user,
          usersInfo[i].wbtcInfo.repayAmount
        );
        if (calcBase + calcPrem > 0) {
          deal(address(tokenList.wbtc), user, usersInfo[i].wbtcInfo.repayAmount);
          CheckedRepayResult memory r = _checkedRepay(
            CheckedRepayParams({
              spoke: spoke1,
              reserveId: _wbtcReserveId(spoke1),
              user: user,
              amount: usersInfo[i].wbtcInfo.repayAmount,
              onBehalfOf: user
            })
          );
          uint256 expectedDebt = usersInfo[i].wbtcInfo.repayAmount >= r.ownerBefore.totalDebt
            ? 0
            : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
          assertApproxEqAbs(
            r.ownerAfter.totalDebt,
            expectedDebt,
            2,
            'WBTC debt not reduced correctly'
          );
        }
      }
    }

    // Verify supply positions remain unchanged for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

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
    RepayUserAction memory bobInfo,
    RepayUserAction memory aliceInfo,
    RepayUserAction memory carolInfo,
    uint256 skipTime
  ) public {
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);
    carolInfo = _boundUserAction(carolInfo);

    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;
    carolInfo.user = carol;

    // Put structs into array
    RepayUserAction[3] memory usersInfo = [bobInfo, aliceInfo, carolInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount + carolInfo.borrowAmount;

    // Derl supplies needed DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: derl,
      amount: totalDaiNeeded,
      onBehalfOf: derl
    });

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
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: _wethReserveId(spoke1),
        caller: user,
        amount: wethCollateralNeeded,
        onBehalfOf: user
      });

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: user,
        amount: usersInfo[i].borrowAmount,
        onBehalfOf: user
      });

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Verify interest accrual
    for (uint256 i = 0; i < usersInfo.length; i++) {
      assertGe(
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), usersInfo[i].user),
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
        spoke1,
        _daiReserveId(spoke1),
        user,
        usersInfo[i].repayAmount
      );
      if (calcBase + calcPrem > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        CheckedRepayResult memory r = _checkedRepay(
          CheckedRepayParams({
            spoke: spoke1,
            reserveId: _daiReserveId(spoke1),
            user: user,
            amount: usersInfo[i].repayAmount,
            onBehalfOf: user
          })
        );
        uint256 expectedDebt = usersInfo[i].repayAmount >= r.ownerBefore.totalDebt
          ? 0
          : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
        assertApproxEqAbs(
          r.ownerAfter.totalDebt,
          expectedDebt,
          2,
          'DAI debt not reduced correctly'
        );
      }
    }

    // Verify supply positions remain unchanged for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
  }

  function test_repay_two_users_repay_same_reserve(
    RepayUserAction memory bobInfo,
    RepayUserAction memory aliceInfo,
    uint256 skipTime
  ) public {
    // Bound borrow and repay amounts
    bobInfo = _boundUserAction(bobInfo);
    aliceInfo = _boundUserAction(aliceInfo);

    skipTime = bound(skipTime, 1, MAX_SKIP_TIME).toUint40();

    // Assign user addresses to the structs
    bobInfo.user = bob;
    aliceInfo.user = alice;

    // Put structs into array
    RepayUserAction[2] memory usersInfo = [bobInfo, aliceInfo];

    // Calculate needed supply for DAI
    uint256 totalDaiNeeded = bobInfo.borrowAmount + aliceInfo.borrowAmount;

    // Derl supplies needed DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: derl,
      amount: totalDaiNeeded,
      onBehalfOf: derl
    });

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
      SpokeActions.supplyCollateral({
        spoke: spoke1,
        reserveId: _wethReserveId(spoke1),
        caller: user,
        amount: wethCollateralNeeded,
        onBehalfOf: user
      });

      usersInfo[i].suppliedShares = spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user);

      // Borrow DAI based on fuzzed amounts
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: user,
        amount: usersInfo[i].borrowAmount,
        onBehalfOf: user
      });

      // Verify initial borrowing state
      uint256 totalDaiDebt = spoke1.getUserTotalDebt(_daiReserveId(spoke1), user);
      assertEq(totalDaiDebt, usersInfo[i].borrowAmount, 'Initial DAI debt incorrect');
    }

    // Time passes, interest accrues
    skip(skipTime);

    // Verify interest accrual
    for (uint256 i = 0; i < usersInfo.length; i++) {
      assertGe(
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), usersInfo[i].user),
        usersInfo[i].borrowAmount,
        'DAI debt should accrue interest'
      );
    }

    // Repayments
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      (uint256 calcBase, uint256 calcPrem) = _calculateExactRestoreAmount(
        spoke1,
        _daiReserveId(spoke1),
        user,
        usersInfo[i].repayAmount
      );
      if (calcBase + calcPrem > 0) {
        deal(address(tokenList.dai), user, usersInfo[i].repayAmount);
        CheckedRepayResult memory r = _checkedRepay(
          CheckedRepayParams({
            spoke: spoke1,
            reserveId: _daiReserveId(spoke1),
            user: user,
            amount: usersInfo[i].repayAmount,
            onBehalfOf: user
          })
        );
        uint256 expectedDebt = usersInfo[i].repayAmount >= r.ownerBefore.totalDebt
          ? 0
          : r.ownerBefore.totalDebt - r.baseRestored - r.premiumRestored;
        assertApproxEqAbs(
          r.ownerAfter.totalDebt,
          expectedDebt,
          2,
          'DAI debt not reduced correctly'
        );
      }
    }

    // Verify supply positions remain unchanged for each user
    for (uint256 i = 0; i < usersInfo.length; i++) {
      address user = usersInfo[i].user;

      assertEq(
        spoke1.getUserSuppliedShares(_wethReserveId(spoke1), user),
        usersInfo[i].suppliedShares,
        'WETH supplied shares should remain unchanged'
      );
    }

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
  }

  /// Borrow, repay, borrow more, repay
  function test_fuzz_repay_borrow_twice_repay_twice(
    RepayAction memory action1,
    RepayAction memory action2
  ) public {
    action1.skipTime = bound(action1.skipTime, 1, MAX_SKIP_TIME / 2).toUint40();
    action2.skipTime = bound(action2.skipTime, 1, MAX_SKIP_TIME / 2).toUint40();
    action1.borrowAmount = bound(action1.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action2.borrowAmount = bound(action2.borrowAmount, 1, MAX_SUPPLY_AMOUNT / 4);
    action1.repayAmount = bound(action1.repayAmount, 1, action1.borrowAmount);
    action2.repayAmount = bound(action2.repayAmount, 1, action2.borrowAmount);

    // Enough funds to cover 2 repayments
    deal(address(tokenList.dai), bob, action1.repayAmount + action2.repayAmount);

    // Bob supply weth as collateral
    action1.supplyAmount =
      _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        action1.borrowAmount
      ) + 1;
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: action1.supplyAmount,
      onBehalfOf: bob
    });

    // Alice supply dai
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: action1.borrowAmount + action2.borrowAmount,
      onBehalfOf: alice
    });

    // Bob borrow dai
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: action1.borrowAmount,
      onBehalfOf: bob
    });

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      action1.borrowAmount,
      'bob dai debt before'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub1.previewAddByAssets(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(action1.skipTime);

    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      action1.borrowAmount,
      'bob dai debt before'
    );

    // Bob repays the first repay amount
    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        spoke1,
        _daiReserveId(spoke1),
        bob,
        action1.repayAmount
      );
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        action1.repayAmount
      );
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        action1.repayAmount,
        expectedPremiumDelta
      );
    }

    CheckedRepayResult memory r1 = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: action1.repayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r1.ownerAfter.suppliedShares, r1.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r1.ownerAfter.totalDebt,
      r1.ownerBefore.totalDebt - r1.baseRestored - r1.premiumRestored,
      2,
      'bob dai debt final balance'
    );
    assertEq(
      r1.callerAfter.tokenBalance,
      r1.callerBefore.tokenBalance - action1.repayAmount,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub1.previewAddByAssets(wethAssetId, action1.supplyAmount)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Supply more collateral if not enough
    {
      uint256 totalCollateral = _calcMinimumCollAmount(
        spoke1,
        _wethReserveId(spoke1),
        _daiReserveId(spoke1),
        spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob) + action2.borrowAmount
      ) + 1;
      action2.supplyAmount = action1.supplyAmount > totalCollateral
        ? 0
        : totalCollateral - action1.supplyAmount;
      if (action2.supplyAmount > 0) {
        SpokeActions.supply({
          spoke: spoke1,
          reserveId: _wethReserveId(spoke1),
          caller: bob,
          amount: action2.supplyAmount,
          onBehalfOf: bob
        });
      }
    }

    uint256 bobWethBalanceBefore = tokenList.weth.balanceOf(bob);

    // Bob borrows more dai
    uint256 debtBeforeSecondBorrow = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: action2.borrowAmount,
      onBehalfOf: bob
    });

    assertApproxEqAbs(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      debtBeforeSecondBorrow + action2.borrowAmount,
      4,
      'bob dai debt after second borrow'
    );

    uint256 totalSuppliedFromActions = action1.supplyAmount + action2.supplyAmount;

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub1.previewAddByAssets(wethAssetId, totalSuppliedFromActions)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    // Time passes
    skip(action2.skipTime);

    assertGe(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      debtBeforeSecondBorrow + action2.borrowAmount,
      'bob dai debt before second repay'
    );

    // Bob repays the second repay amount
    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        spoke1,
        _daiReserveId(spoke1),
        bob,
        action2.repayAmount
      );
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        action2.repayAmount
      );
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        action2.repayAmount,
        expectedPremiumDelta
      );
    }

    CheckedRepayResult memory r2 = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: action2.repayAmount,
        onBehalfOf: bob
      })
    );

    assertEq(r2.ownerAfter.suppliedShares, r2.ownerBefore.suppliedShares);
    assertApproxEqAbs(
      r2.ownerAfter.totalDebt,
      r2.ownerBefore.totalDebt - r2.baseRestored - r2.premiumRestored,
      2,
      'bob dai debt final balance'
    );
    assertEq(
      r2.callerAfter.tokenBalance,
      r2.callerBefore.tokenBalance - action2.repayAmount,
      'bob dai final balance'
    );
    assertEq(
      spoke1.getUserSuppliedShares(_wethReserveId(spoke1), bob),
      hub1.previewAddByAssets(wethAssetId, totalSuppliedFromActions)
    );
    assertEq(spoke1.getUserTotalDebt(_wethReserveId(spoke1), bob), 0);

    assertEq(tokenList.weth.balanceOf(bob), bobWethBalanceBefore);

    _repayAll(spoke1, _daiReserveId(spoke1), _defaultUsers());
  }

  function test_repay_partial_then_max() public {
    uint256 daiSupplyAmount = 100e18;
    uint256 wethSupplyAmount = 10e18;
    uint256 daiBorrowAmount = daiSupplyAmount / 2;

    // Bob supplies WETH as collateral
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    });

    // Alice supplies DAI
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: daiSupplyAmount,
      onBehalfOf: alice
    });

    // Bob borrows DAI
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: daiBorrowAmount,
      onBehalfOf: bob
    });

    assertEq(_getUserInfo(spoke1, bob, _daiReserveId(spoke1)).suppliedShares, 0);
    assertEq(
      spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob),
      daiBorrowAmount,
      'Initial bob dai debt'
    );

    // Time passes so that interest accrues
    skip(10 days);

    DebtData memory bobDaiBefore = _getUserDebt(spoke1, bob, _daiReserveId(spoke1));
    // Bob's debt (drawn debt + premium) is greater than the original borrow amount
    assertGt(bobDaiBefore.totalDebt, daiBorrowAmount, 'Accrued interest increased bob dai debt');

    // Calculate full debt before repayment
    uint256 fullDebt = bobDaiBefore.drawnDebt + bobDaiBefore.premiumDebt;
    uint256 partialRepayAmount = fullDebt / 2;

    {
      (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
        hub1,
        daiAssetId,
        bobDaiBefore.drawnDebt,
        bobDaiBefore.premiumDebt,
        partialRepayAmount
      );

      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        partialRepayAmount
      );

      // Partial repay
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        baseRestored + premiumRestored,
        expectedPremiumDelta
      );
    }

    CheckedRepayResult memory r1 = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: partialRepayAmount,
        onBehalfOf: bob
      })
    );

    // Verify that Bob's debt is reduced after partial repayment
    assertApproxEqAbs(
      r1.ownerAfter.totalDebt,
      fullDebt - r1.baseRestored - r1.premiumRestored,
      2,
      'Bob dai debt should be reduced'
    );
    // Verify that his DAI balance was reduced by the partial repay amount
    assertEq(
      r1.callerAfter.tokenBalance,
      r1.callerBefore.tokenBalance - partialRepayAmount,
      'Bob dai balance decreased by partial repay amount'
    );
    // Verify reserve debt was decreased by partial repayment
    assertApproxEqAbs(
      r1.reserveAfter.totalDebt,
      fullDebt - r1.baseRestored - r1.premiumRestored,
      2
    );

    // verify LH asset debt is decreased by partial repayment
    assertApproxEqAbs(
      hub1.getAssetTotalOwed(_daiReserveId(spoke1)),
      fullDebt - r1.baseRestored - r1.premiumRestored,
      2
    );

    {
      (uint256 baseRestored, ) = _calculateExactRestoreAmount(
        spoke1,
        _daiReserveId(spoke1),
        bob,
        UINT256_MAX
      );

      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke1,
        bob,
        _daiReserveId(spoke1),
        UINT256_MAX
      );

      (uint256 drawnDebt, uint256 premiumDebt) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);

      // Full repay
      vm.expectEmit(address(spoke1));
      emit ISpoke.Repay(
        _daiReserveId(spoke1),
        bob,
        bob,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        drawnDebt + premiumDebt,
        expectedPremiumDelta
      );
    }

    CheckedRepayResult memory r2 = _checkedRepay(
      CheckedRepayParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: UINT256_MAX,
        onBehalfOf: bob
      })
    );

    // Verify that Bob's debt is fully cleared after repayment
    assertEq(r2.ownerAfter.totalDebt, 0, 'Bob dai debt should be cleared');

    // Verify that his DAI balance was reduced by the full debt amount
    assertApproxEqAbs(
      r2.callerAfter.tokenBalance,
      r1.callerBefore.tokenBalance - fullDebt,
      2,
      'Bob dai balance decreased by full debt repaid'
    );

    // Verify reserve debt is 0
    assertEq(r2.reserveAfter.totalDrawnDebt, 0);
    assertEq(r2.reserveAfter.totalPremiumDebt, 0);

    // verify LH asset debt is 0
    assertEq(hub1.getAssetTotalOwed(_daiReserveId(spoke1)), 0);
  }

  /// User supplies appropriate collateral, then borrows, immediately repays, check delta on share amounts
  /// @dev Assume another user borrowing, and skip time so debt ex ratio potentially nonzero
  function test_repay_round_trip_borrow_repay(
    uint256 reserveId,
    uint256 userBorrowing,
    uint40 skipTime,
    address caller,
    uint256 assets
  ) public {
    _assumeValidSupplier(caller);
    vm.assume(caller != derl);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    userBorrowing = bound(userBorrowing, 0, _calculateMaxSupplyAmount(spoke1, reserveId) / 2 - 1); // Allow some buffer from borrow cap
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    assets = bound(assets, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 2 - userBorrowing);

    // Set up initial state of the vault by having derl borrow
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, userBorrowing);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: derl,
      amount: supplyAmount,
      onBehalfOf: derl
    });
    if (userBorrowing > 0) {
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: reserveId,
        caller: derl,
        amount: userBorrowing,
        onBehalfOf: derl
      });
    }

    skip(skipTime);

    ISpoke.Reserve memory reserve = spoke1.getReserve(reserveId);

    IERC20 underlying = _getAssetUnderlyingByReserveId(spoke1, reserveId);

    // Deal caller max collateral amount, approve spoke, supply
    supplyAmount = _calculateMaxSupplyAmount(spoke1, reserveId) - supplyAmount;
    deal(address(underlying), caller, supplyAmount);
    vm.prank(caller);
    underlying.approve(address(spoke1), supplyAmount);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: caller,
      amount: supplyAmount,
      onBehalfOf: caller
    });

    // Borrow
    uint256 shares1 = hub1.previewRestoreByAssets(reserve.assetId, assets);
    vm.startPrank(caller);
    spoke1.borrow(reserveId, assets, caller);

    // Repay
    uint256 shares2 = hub1.previewRestoreByAssets(reserve.assetId, assets);
    deal(address(underlying), caller, assets);
    underlying.approve(address(spoke1), assets);
    spoke1.repay(reserveId, assets, caller);
    vm.stopPrank();

    assertEq(shares2, shares1, 'borrowed and repaid shares');
  }

  /// User repays, then immediately borrows, check delta on share amounts
  /// @dev Assume another user borrowing, and skip time so debt ex ratio potentially nonzero
  /// @dev Assume user already has a nonzero borrow position to repay
  function test_repay_round_trip_repay_borrow(
    uint256 reserveId,
    uint256 userBorrowing,
    uint256 callerStartingDebt,
    uint40 skipTime,
    address caller,
    uint256 assets
  ) public {
    _assumeValidSupplier(caller);
    vm.assume(caller != derl);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 MAX_BORROW_AMOUNT = _calculateMaxSupplyAmount(spoke1, reserveId) / 2;
    userBorrowing = bound(userBorrowing, 0, MAX_BORROW_AMOUNT - 2); // Allow some buffer from borrow cap
    skipTime = bound(skipTime, 0, MAX_SKIP_TIME).toUint40();
    assets = bound(assets, 1, MAX_BORROW_AMOUNT - userBorrowing - 1); // Allow some buffer from borrow cap
    callerStartingDebt = bound(callerStartingDebt, 1, MAX_BORROW_AMOUNT - userBorrowing - assets);

    // Set up initial state of the vault by having derl borrow
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, userBorrowing);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: derl,
      amount: supplyAmount,
      onBehalfOf: derl
    });
    if (userBorrowing > 0) {
      SpokeActions.borrow({
        spoke: spoke1,
        reserveId: reserveId,
        caller: derl,
        amount: userBorrowing,
        onBehalfOf: derl
      });
    }

    skip(skipTime);

    ISpoke.Reserve memory reserve = spoke1.getReserve(reserveId);

    IERC20 underlying = _getAssetUnderlyingByReserveId(spoke1, reserveId);

    // Set up caller initial debt position
    supplyAmount = _calculateMaxSupplyAmount(spoke1, reserveId) - supplyAmount;
    deal(address(underlying), caller, supplyAmount);
    vm.prank(caller);
    underlying.approve(address(spoke1), supplyAmount);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: caller,
      amount: supplyAmount,
      onBehalfOf: caller
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      caller: caller,
      amount: callerStartingDebt,
      onBehalfOf: caller
    });

    // Repay
    uint256 shares1 = hub1.previewRestoreByAssets(reserve.assetId, assets);
    deal(address(underlying), caller, assets);
    vm.startPrank(caller);
    underlying.approve(address(spoke1), assets);
    spoke1.repay(reserveId, assets, caller);

    // Borrow
    uint256 shares2 = hub1.previewRestoreByAssets(reserve.assetId, assets);
    spoke1.borrow(reserveId, assets, caller);
    vm.stopPrank();

    assertEq(shares2, shares1, 'borrowed and repaid shares');
  }

  function _boundUserAction(
    RepayUserAction memory action
  ) internal view returns (RepayUserAction memory) {
    action.borrowAmount = bound(action.borrowAmount, 1, MAX_SUPPLY_AMOUNT_DAI / 8);
    action.repayAmount = bound(action.repayAmount, 1, UINT256_MAX);

    return action;
  }

  function _bound(
    RepayUserAssetInfo memory info
  ) internal view returns (RepayUserAssetInfo memory) {
    // Bound borrow amounts
    info.daiInfo.borrowAmount = bound(info.daiInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT_DAI / 8);
    info.wethInfo.borrowAmount = bound(info.wethInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT_WETH / 8);
    info.usdxInfo.borrowAmount = bound(info.usdxInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT_USDX / 8);
    info.wbtcInfo.borrowAmount = bound(info.wbtcInfo.borrowAmount, 1, MAX_SUPPLY_AMOUNT_WBTC / 8);

    // Bound repay amounts
    info.daiInfo.repayAmount = bound(info.daiInfo.repayAmount, 1, UINT256_MAX);
    info.wethInfo.repayAmount = bound(info.wethInfo.repayAmount, 1, UINT256_MAX);
    info.usdxInfo.repayAmount = bound(info.usdxInfo.repayAmount, 1, UINT256_MAX);
    info.wbtcInfo.repayAmount = bound(info.wbtcInfo.repayAmount, 1, UINT256_MAX);

    return info;
  }
}
