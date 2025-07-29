// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeRiskPremiumScenarioTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct GeneralLocalVars {
    uint256 usdxSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 daiBorrowAmount;
    uint40 lastUpdateTimestamp;
    uint256 delay;
    uint256 expectedPremiumDebt;
    uint256 expectedPremiumDrawnShares;
    uint256 expectedUserRiskPremium;
  }

  struct ReserveInfoLocal {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 price;
    uint256 collateralRisk;
    uint256 riskPremium;
  }

  struct UserInfoLocal {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 premiumDrawnShares;
    uint256 totalDebt;
    uint256 riskPremium;
  }

  struct DebtChecks {
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 actualBaseDebt;
    uint256 actualPremium;
    uint256 reserveDebt;
    uint256 reservePremium;
    uint256 spokeDebt;
    uint256 spokePremium;
    uint256 assetDebt;
    uint256 assetPremium;
  }

  struct RestoredAmounts {
    uint256 baseRestored;
    uint256 premiumRestored;
  }

  struct ExpectedUserRp {
    uint256 bobRiskPremium;
    uint256 aliceRiskPremium;
  }

  struct Rates {
    uint256 baseRateDai;
    uint256 baseRateUsdx;
  }

  /** Spoke1 Init Config
   * +-----------+------------+------------------+--------+----------+
   * | reserveId | collateral | collateralRisk | price  | decimals |
   * +-----------+------------+------------------+--------+----------+
   * |         0 | weth       | 15%              | 2_000  |       18 |
   * |         1 | wbtc       | 50%              | 50_000 |        8 |
   * |         2 | dai        | 20%              | 1      |       18 |
   * |         3 | usdx       | 50%              | 1      |        6 |
   * +-----------+------------+------------------+--------+----------+
   */
  /// Borrow, skip, supply, skip, supply, ensure risk premium is correct and accounting updates accordingly throughout protocol
  function test_riskPremiumPropagatesCorrectly_singleBorrow() public {
    GeneralLocalVars memory vars;
    vars.usdxSupplyAmount = 1500e6; // 1500 usd, 50 collateralRisk
    vars.wethSupplyAmount = 5e18; // 10_000 usd, 15 collateralRisk
    vars.daiBorrowAmount = 10_000e18; // 10_000 usd, 20 collateralRisk
    vars.delay = 365 days;

    ReserveIds memory reservesIds;
    reservesIds.usdx = _usdxReserveId(spoke1);
    reservesIds.weth = _wethReserveId(spoke1);
    reservesIds.dai = _daiReserveId(spoke1);

    // Validate collateral risks
    assertEq(_getCollateralRisk(spoke1, reservesIds.usdx), 50_00, 'usdx collateral risk');
    assertEq(_getCollateralRisk(spoke1, reservesIds.weth), 15_00, 'weth collateral risk');
    assertEq(_getCollateralRisk(spoke1, reservesIds.dai), 20_00, 'dai collateral risk');

    // Set collateral factor to 100% for Alice collateral
    updateCollateralFactor(spoke1, reservesIds.weth, 100_00);
    updateCollateralFactor(spoke1, reservesIds.usdx, 100_00);

    // supply twice the amount that alice borrows, usage ratio ~45%, borrow rate ~7.5%
    Utils.supply(spoke1, reservesIds.dai, bob, vars.daiBorrowAmount.percentDivDown(45_00), bob);

    Utils.supplyCollateral(spoke1, reservesIds.usdx, alice, vars.usdxSupplyAmount, alice);

    Utils.supplyCollateral(spoke1, reservesIds.weth, alice, vars.wethSupplyAmount, alice);

    Utils.borrow(spoke1, reservesIds.dai, alice, vars.daiBorrowAmount, alice);

    uint256 usdxCollateralRisk = _getCollateralRisk(spoke1, reservesIds.usdx);
    uint256 wethCollateralRisk = _getCollateralRisk(spoke1, reservesIds.weth);
    assertLt(
      wethCollateralRisk,
      usdxCollateralRisk,
      'weth collateral risk should be less than usdx collateral risk'
    );

    // Weth is enough to cover debt, both stored & calculated risk premiums match
    assertEq(spoke1.getUserRiskPremium(alice), wethCollateralRisk, 'user rp: weth covers debt');
    // Check stored risk premium via back-calculating premium drawn shares
    DataTypes.UserPosition memory alicePosition = spoke1.getUserPosition(
      _daiReserveId(spoke1),
      alice
    );
    vars.expectedPremiumDrawnShares = alicePosition.baseDrawnShares.percentMulUp(
      wethCollateralRisk
    );
    assertEq(
      alicePosition.premiumDrawnShares,
      vars.expectedPremiumDrawnShares,
      'premium drawn shares match expected'
    );

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    uint40 startTime = vars.lastUpdateTimestamp;
    skip(vars.delay);

    // Since only DAI is borrowed in the system, supply interest is accrued only on it
    assertEq(
      spoke1.getUserSuppliedAmount(reservesIds.usdx, alice),
      vars.usdxSupplyAmount,
      'supplied usdx'
    );
    assertEq(
      spoke1.getUserSuppliedAmount(reservesIds.weth, alice),
      vars.wethSupplyAmount,
      'supplied weth'
    );

    uint256 accruedDaiDebt = vars.daiBorrowAmount.rayMulUp(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // todo: IR strategy has a pending fix
        vars.lastUpdateTimestamp
      ) - WadRayMath.RAY
    );
    vars.expectedPremiumDebt = accruedDaiDebt.percentMulUp(wethCollateralRisk);

    (uint256 baseDaiDebt, uint256 daiPremiumDebt) = spoke1.getUserDebt(reservesIds.dai, alice);
    assertEq(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt, 'dai base debt');
    assertEq(daiPremiumDebt, vars.expectedPremiumDebt, 'dai premium debt');

    // Now since debt has grown, weth supply is not enough to cover debt, hence rp changes
    // usdx is enough to cover remaining debt
    uint256 daiDebtValue = _getValueInBaseCurrency(
      spoke1,
      reservesIds.dai,
      accruedDaiDebt + daiPremiumDebt
    );
    uint256 usdxSupplyValue = _getValueInBaseCurrency(
      spoke1,
      reservesIds.usdx,
      vars.usdxSupplyAmount
    );
    assertLt(daiDebtValue, usdxSupplyValue);

    vars.expectedUserRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    assertEq(
      spoke1.getUserRiskPremium(alice),
      vars.expectedUserRiskPremium,
      'user risk premium after accrual'
    );

    // Alice supplies more usdx
    Utils.supply(spoke1, reservesIds.usdx, alice, 500e6, alice);

    assertEq(
      spoke1.getUserRiskPremium(alice),
      vars.expectedUserRiskPremium,
      'user risk premium after supply'
    );

    // Store alice's position before timeskip to calc expected premium debt
    alicePosition = spoke1.getUserPosition(reservesIds.dai, alice);

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(vars.delay);

    // Now we supply more weth such that new total debt from now on is covered by weth
    Utils.supply(spoke1, reservesIds.weth, alice, vars.wethSupplyAmount, alice);

    accruedDaiDebt = vars.daiBorrowAmount.rayMulUp(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // todo: IR strategy has a pending fix
        startTime
      ) - WadRayMath.RAY
    );

    vars.expectedPremiumDebt =
      hub.convertToDrawnAssets(daiAssetId, alicePosition.premiumDrawnShares) -
      alicePosition.premiumOffset;

    (baseDaiDebt, daiPremiumDebt) = spoke1.getUserDebt(reservesIds.dai, alice);

    assertEq(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt, 'dai base debt after weth supply');
    assertEq(daiPremiumDebt, vars.expectedPremiumDebt, 'dai premium debt after weth supply');

    // Alice repays everything
    _repayAll(spoke1, _daiReserveId);
  }

  /// Bob and Alice each supply and borrow varying amounts of usdx and dai, we check interest accrues and values percolate to hub.
  /// After 1 year, Alice does a repay, and we ensure the same values are updated accordingly.
  function test_getUserRiskPremium_applyInterest_two_users_two_reserves_borrowed() public {
    // Set dai collateral risk to 10% and usdx to 20%
    updateCollateralRisk(spoke1, _daiReserveId(spoke1), 10_00);
    updateCollateralRisk(spoke1, _usdxReserveId(spoke1), 20_00);

    UserInfoLocal memory bobDaiInfo;
    UserInfoLocal memory aliceDaiInfo;
    UserInfoLocal memory bobUsdxInfo;
    UserInfoLocal memory aliceUsdxInfo;

    bobDaiInfo.supplyAmount = 1000e18;
    aliceDaiInfo.supplyAmount = 2000e18;
    bobUsdxInfo.supplyAmount = 5000e6;
    aliceUsdxInfo.supplyAmount = 10000e6;

    bobDaiInfo.borrowAmount = bobDaiInfo.supplyAmount / 2;
    aliceDaiInfo.borrowAmount = aliceDaiInfo.supplyAmount / 2;
    bobUsdxInfo.borrowAmount = bobUsdxInfo.supplyAmount / 2;
    aliceUsdxInfo.borrowAmount = aliceUsdxInfo.supplyAmount / 2;

    ReserveInfoLocal memory daiInfo;
    ReserveInfoLocal memory usdxInfo;

    daiInfo.reserveId = _daiReserveId(spoke1);
    usdxInfo.reserveId = _usdxReserveId(spoke1);

    daiInfo.collateralRisk = _getCollateralRisk(spoke1, daiInfo.reserveId);
    usdxInfo.collateralRisk = _getCollateralRisk(spoke1, usdxInfo.reserveId);

    // Bob supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, bob, bobDaiInfo.supplyAmount, bob);

    // Bob supply usdx into spoke1
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.supplyAmount, bob);

    // Alice supply dai into spoke1
    Utils.supplyCollateral(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.supplyAmount, alice);

    // Alice supply usdx into spoke1
    Utils.supplyCollateral(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.supplyAmount, alice);

    // Bob draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, bob, bobDaiInfo.borrowAmount, bob);

    // Bob draw usdx
    Utils.borrow(spoke1, usdxInfo.reserveId, bob, bobUsdxInfo.borrowAmount, bob);

    // Alice draw dai
    Utils.borrow(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.borrowAmount, alice);

    // Alice draw usdx
    Utils.borrow(spoke1, usdxInfo.reserveId, alice, aliceUsdxInfo.borrowAmount, alice);

    ExpectedUserRp memory expectedUserRp;
    expectedUserRp.bobRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    expectedUserRp.aliceRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    assertEq(spoke1.getUserRiskPremium(bob), expectedUserRp.bobRiskPremium, 'bob risk premium');
    assertEq(
      spoke1.getUserRiskPremium(alice),
      expectedUserRp.aliceRiskPremium,
      'alice risk premium'
    );

    DebtChecks memory debtChecks;
    Rates memory rates;

    // Get the base rate of dai
    rates.baseRateDai = hub.getBaseInterestRate(daiAssetId);

    // Check Bob's starting dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    uint256 startTime = vm.getBlockTimestamp();

    assertEq(bobDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob dai premium before');

    // Get the base rate of usdx
    rates.baseRateUsdx = hub.getBaseInterestRate(usdxAssetId);

    // Check Bob's starting usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );

    assertEq(bobUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob usdx premium before');

    // Check Alice's starting dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    assertEq(aliceDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice dai premium before');

    // Check Alice's starting usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );

    assertEq(aliceUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice usdx premium before');

    // Store premium drawn shares for both users to check as proxy for risk premium
    bobDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(daiInfo.reserveId, bob)
      .premiumDrawnShares;
    aliceDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(daiInfo.reserveId, alice)
      .premiumDrawnShares;
    bobUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(usdxInfo.reserveId, bob)
      .premiumDrawnShares;
    aliceUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(usdxInfo.reserveId, alice)
      .premiumDrawnShares;

    // Wait a year
    skip(365 days);

    // User risk premium should remain the same when there is no action, use premium drawn shares as proxy for this check
    assertEq(
      spoke1.getUserPosition(daiInfo.reserveId, bob).premiumDrawnShares,
      bobDaiInfo.premiumDrawnShares,
      'bob dai premium drawn shares after interest accrual'
    );
    assertEq(
      spoke1.getUserPosition(usdxInfo.reserveId, bob).premiumDrawnShares,
      bobUsdxInfo.premiumDrawnShares,
      'bob usdx premium drawn shares after interest accrual'
    );
    assertEq(
      spoke1.getUserPosition(daiInfo.reserveId, alice).premiumDrawnShares,
      aliceDaiInfo.premiumDrawnShares,
      'alice dai premium drawn shares after interest accrual'
    );
    assertEq(
      spoke1.getUserPosition(usdxInfo.reserveId, alice).premiumDrawnShares,
      aliceUsdxInfo.premiumDrawnShares,
      'alice usdx premium drawn shares after interest accrual'
    );

    // Ensure the calculated risk premium would match
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'bob risk premium after time skip'
    );
    assertEq(
      spoke1.getUserRiskPremium(alice),
      _calculateExpectedUserRP(alice, spoke1),
      'alice risk premium after time skip'
    );

    // See if Bob's base debt of dai changes appropriately
    bobDaiInfo.baseDebt = MathUtils
      .calculateLinearInterest(rates.baseRateDai, uint40(startTime))
      .rayMulUp(bobDaiInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertEq(bobDaiInfo.baseDebt, debtChecks.actualBaseDebt, 'bob dai base debt after');

    // See if Bob's dai premium debt changes proportionally to bob's risk premium
    bobDaiInfo.premiumDebt = (bobDaiInfo.baseDebt - bobDaiInfo.borrowAmount).percentMulUp(
      expectedUserRp.bobRiskPremium
    );
    assertEq(bobDaiInfo.premiumDebt, debtChecks.actualPremium, 'bob premium debt after accrual');

    // See if Bob's base debt of usdx changes appropriately
    bobUsdxInfo.baseDebt = MathUtils
      .calculateLinearInterest(rates.baseRateUsdx, uint40(startTime))
      .rayMulUp(bobUsdxInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(bobUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'bob usdx base debt after');

    // See if Bob's usdx premium debt changes proportionally to bob's risk premium
    bobUsdxInfo.premiumDebt = (bobUsdxInfo.baseDebt - bobUsdxInfo.borrowAmount).percentMulUp(
      expectedUserRp.bobRiskPremium
    );
    assertEq(bobUsdxInfo.premiumDebt, debtChecks.actualPremium, 'bob premium debt after accrual');

    // See if Alice's base debt of dai changes appropriately
    aliceDaiInfo.baseDebt = MathUtils
      .calculateLinearInterest(rates.baseRateDai, uint40(startTime))
      .rayMulUp(aliceDaiInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );
    assertEq(aliceDaiInfo.baseDebt, debtChecks.actualBaseDebt, 'alice dai base debt after');

    // See if Alice's dai premium debt changes proportionally to alice's risk premium
    aliceDaiInfo.premiumDebt = (aliceDaiInfo.baseDebt - aliceDaiInfo.borrowAmount).percentMulUp(
      expectedUserRp.aliceRiskPremium
    );
    assertEq(
      aliceDaiInfo.premiumDebt,
      debtChecks.actualPremium,
      'alice premium debt after accrual'
    );

    // See if Alice's base debt of usdx changes appropriately
    aliceUsdxInfo.baseDebt = MathUtils
      .calculateLinearInterest(rates.baseRateUsdx, uint40(startTime))
      .rayMulUp(aliceUsdxInfo.borrowAmount);
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(aliceUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'alice usdx base debt after');

    // See if Alice's usdx premium debt changes proportionally to alice's risk premium
    aliceUsdxInfo.premiumDebt = (aliceUsdxInfo.baseDebt - aliceUsdxInfo.borrowAmount).percentMulUp(
      expectedUserRp.aliceRiskPremium
    );
    assertEq(
      aliceUsdxInfo.premiumDebt,
      debtChecks.actualPremium,
      'alice premium debt after accrual'
    );

    _verifyProtocolDebtAmounts(
      bobDaiInfo,
      aliceDaiInfo,
      bobUsdxInfo,
      aliceUsdxInfo,
      'after accrual'
    );

    RestoredAmounts memory restored;
    (restored.baseRestored, restored.premiumRestored) = _calculateExactRestoreAmount(
      aliceDaiInfo.baseDebt,
      aliceDaiInfo.premiumDebt,
      aliceDaiInfo.borrowAmount / 2,
      daiAssetId
    );

    // Store premium drawn shares for both users to check as proxy for risk premium
    bobDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(daiInfo.reserveId, bob)
      .premiumDrawnShares;
    aliceDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(daiInfo.reserveId, alice)
      .premiumDrawnShares;
    bobUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(usdxInfo.reserveId, bob)
      .premiumDrawnShares;
    aliceUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(usdxInfo.reserveId, alice)
      .premiumDrawnShares;

    // Now, if Alice repays some debt, her user risk premium should change and percolate through protocol
    Utils.repay(spoke1, daiInfo.reserveId, alice, aliceDaiInfo.borrowAmount / 2, alice);

    // Bob's user risk premium remains unchanged
    assertEq(
      spoke1.getUserPosition(daiInfo.reserveId, bob).premiumDrawnShares,
      bobDaiInfo.premiumDrawnShares,
      'bob dai premium drawn shares after repay'
    );
    assertEq(
      spoke1.getUserPosition(usdxInfo.reserveId, bob).premiumDrawnShares,
      bobUsdxInfo.premiumDrawnShares,
      'bob usdx premium drawn shares after repay'
    );

    // Alice's user risk premium does change
    assertNotEq(
      spoke1.getUserPosition(daiInfo.reserveId, alice).premiumDrawnShares,
      aliceDaiInfo.premiumDrawnShares,
      'alice dai premium drawn shares after repay should not match'
    );
    assertNotEq(
      spoke1.getUserPosition(usdxInfo.reserveId, alice).premiumDrawnShares,
      aliceUsdxInfo.premiumDrawnShares,
      'alice usdx premium drawn shares after repay should not match'
    );

    expectedUserRp.aliceRiskPremium = _calculateExpectedUserRP(alice, spoke1);
    assertEq(
      spoke1.getUserRiskPremium(alice),
      expectedUserRp.aliceRiskPremium,
      'alice risk premium after repay'
    );

    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      alice
    );

    // Only Alice's premium debt and base debt on dai should change due to repay
    aliceDaiInfo.baseDebt -= restored.baseRestored;
    aliceDaiInfo.premiumDebt -= restored.premiumRestored;
    assertApproxEqAbs(
      debtChecks.actualBaseDebt,
      aliceDaiInfo.baseDebt,
      1,
      'alice base debt after repay'
    );
    assertApproxEqAbs(
      debtChecks.actualPremium,
      aliceDaiInfo.premiumDebt,
      1,
      'alice premium debt after repay'
    );
    aliceDaiInfo.totalDebt = aliceDaiInfo.baseDebt + aliceDaiInfo.premiumDebt;

    // Alice's debts on usdx should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      alice
    );
    assertEq(debtChecks.actualBaseDebt, aliceUsdxInfo.baseDebt, 'alice usdx base debt after');
    assertApproxEqAbs(
      debtChecks.actualPremium,
      aliceUsdxInfo.premiumDebt,
      1,
      'alice usdx premium debt after'
    );
    aliceUsdxInfo.totalDebt = aliceUsdxInfo.baseDebt + aliceUsdxInfo.premiumDebt;

    // Bob's debts on dai should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      daiInfo.reserveId,
      bob
    );
    assertEq(debtChecks.actualBaseDebt, bobDaiInfo.baseDebt, 'bob dai base debt after');
    assertEq(debtChecks.actualPremium, bobDaiInfo.premiumDebt, 'bob dai premium debt after');
    bobDaiInfo.totalDebt = bobDaiInfo.baseDebt + bobDaiInfo.premiumDebt;

    // Bob's debts on usdx should remain unchanged
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      usdxInfo.reserveId,
      bob
    );
    assertEq(debtChecks.actualBaseDebt, bobUsdxInfo.baseDebt, 'bob usdx base debt after');
    assertEq(debtChecks.actualPremium, bobUsdxInfo.premiumDebt, 'bob usdx premium debt after');

    _verifyProtocolDebtAmounts(
      bobDaiInfo,
      aliceDaiInfo,
      bobUsdxInfo,
      aliceUsdxInfo,
      'after alice repay'
    );
  }

  /// Bob and Alice each supply and borrow varying fuzzed amounts of usdx and dai,
  /// with different risk premiums. We check interest accrues correctly and values percolate to hub.
  /// @dev We don't store user risk premium directly, so compare calculated premiumDrawnShares as proxy for expected previous risk premium
  function test_getUserRiskPremium_fuzz_two_users_two_reserves_borrowed(
    UserBorrowAction memory bobDaiAction,
    UserBorrowAction memory bobUsdxAction,
    UserBorrowAction memory aliceDaiAction,
    UserBorrowAction memory aliceUsdxAction,
    uint256 daiCollateralRisk,
    uint256 usdxCollateralRisk,
    uint40[3] memory timeSkip
  ) public {
    bobDaiAction = _boundUserBorrowAction(bobDaiAction);
    bobUsdxAction = _boundUserBorrowAction(bobUsdxAction);
    aliceDaiAction = _boundUserBorrowAction(aliceDaiAction);
    aliceUsdxAction = _boundUserBorrowAction(aliceUsdxAction);

    daiCollateralRisk = bound(daiCollateralRisk, 0, MAX_RISK_PREMIUM_BPS);
    usdxCollateralRisk = bound(usdxCollateralRisk, 0, MAX_RISK_PREMIUM_BPS);

    timeSkip[0] = uint40(bound(timeSkip[0], 0, MAX_SKIP_TIME));
    timeSkip[1] = uint40(bound(timeSkip[1], 0, MAX_SKIP_TIME));
    timeSkip[2] = uint40(bound(timeSkip[2], 0, MAX_SKIP_TIME));

    // Set collateral risks
    updateCollateralRisk(spoke1, _daiReserveId(spoke1), daiCollateralRisk);
    updateCollateralRisk(spoke1, _usdxReserveId(spoke1), usdxCollateralRisk);
    assertEq(
      _getCollateralRisk(spoke1, _daiReserveId(spoke1)),
      daiCollateralRisk,
      'dai collateral risk'
    );
    assertEq(
      _getCollateralRisk(spoke1, _usdxReserveId(spoke1)),
      usdxCollateralRisk,
      'usdx collateral risk'
    );

    UserInfoLocal memory bobDaiInfo;
    UserInfoLocal memory aliceDaiInfo;
    UserInfoLocal memory bobUsdxInfo;
    UserInfoLocal memory aliceUsdxInfo;

    // Set up user info structs
    bobDaiInfo.supplyAmount = bobDaiAction.supplyAmount;
    aliceDaiInfo.supplyAmount = aliceDaiAction.supplyAmount;
    bobUsdxInfo.supplyAmount = bobUsdxAction.supplyAmount;
    aliceUsdxInfo.supplyAmount = aliceUsdxAction.supplyAmount;

    bobDaiInfo.borrowAmount = bobDaiAction.borrowAmount;
    aliceDaiInfo.borrowAmount = aliceDaiAction.borrowAmount;
    bobUsdxInfo.borrowAmount = bobUsdxAction.borrowAmount;
    aliceUsdxInfo.borrowAmount = aliceUsdxAction.borrowAmount;

    // Users supply

    // Bob supply dai
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobDaiInfo.supplyAmount, bob);

    // Bob supply usdx
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, bobUsdxInfo.supplyAmount, bob);

    // Alice supply dai
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceDaiInfo.supplyAmount, alice);

    // Alice supply usdx
    Utils.supplyCollateral(
      spoke1,
      _usdxReserveId(spoke1),
      alice,
      aliceUsdxInfo.supplyAmount,
      alice
    );

    // Users borrow

    // Bob draw dai (if any)
    if (bobDaiInfo.borrowAmount > 0) {
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, bobDaiInfo.borrowAmount, bob);
    }

    // Bob draw usdx (if any)
    if (bobUsdxInfo.borrowAmount > 0) {
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, bobUsdxInfo.borrowAmount, bob);
    }

    // Alice draw dai (if any)
    if (aliceDaiInfo.borrowAmount > 0) {
      Utils.borrow(spoke1, _daiReserveId(spoke1), alice, aliceDaiInfo.borrowAmount, alice);
    }

    // Alice draw usdx (if any)
    if (aliceUsdxInfo.borrowAmount > 0) {
      Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, aliceUsdxInfo.borrowAmount, alice);
    }

    // Calculate expected risk premiums
    uint256 bobExpectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);
    uint256 aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);

    // Verify initial risk premiums
    assertEq(spoke1.getUserRiskPremium(bob), bobExpectedRiskPremium, 'bob initial risk premium');
    assertEq(
      spoke1.getUserRiskPremium(alice),
      aliceExpectedRiskPremium,
      'alice initial risk premium'
    );

    DebtChecks memory debtChecks;

    // Check initial debts

    // Bob's initial dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      bob
    );

    uint256 startTime = vm.getBlockTimestamp();

    assertEq(bobDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob dai premium before');

    // Bob's initial usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      _usdxReserveId(spoke1),
      bob
    );
    assertEq(bobUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Bob usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Bob usdx premium before');

    // Alice's initial dai debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );
    assertEq(aliceDaiInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice dai debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice dai premium before');

    // Alice's initial usdx debt
    (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
      _usdxReserveId(spoke1),
      alice
    );
    assertEq(aliceUsdxInfo.borrowAmount, debtChecks.actualBaseDebt, 'Alice usdx debt before');
    assertEq(debtChecks.actualPremium, 0, 'Alice usdx premium before');

    // Skip time
    skip(timeSkip[0]);

    // Check that risk premiums remain consistent after time skip by checking premium drawn shares
    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
    uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(
      bobExpectedRiskPremium
    );
    assertEq(
      expectedPremiumDrawnShares,
      bobPosition.premiumDrawnShares,
      'bob dai premium drawn shares after time skip'
    );
    bobDaiInfo.premiumDrawnShares = expectedPremiumDrawnShares;

    bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
    expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMulUp(bobExpectedRiskPremium);
    assertEq(
      expectedPremiumDrawnShares,
      bobPosition.premiumDrawnShares,
      'bob usdx premium drawn shares after time skip'
    );
    bobUsdxInfo.premiumDrawnShares = expectedPremiumDrawnShares;

    DataTypes.UserPosition memory alicePosition = spoke1.getUserPosition(
      _daiReserveId(spoke1),
      alice
    );
    expectedPremiumDrawnShares = alicePosition.baseDrawnShares.percentMulUp(
      aliceExpectedRiskPremium
    );
    assertEq(
      expectedPremiumDrawnShares,
      alicePosition.premiumDrawnShares,
      'alice dai premium drawn shares after time skip'
    );
    aliceDaiInfo.premiumDrawnShares = expectedPremiumDrawnShares;

    alicePosition = spoke1.getUserPosition(_usdxReserveId(spoke1), alice);
    expectedPremiumDrawnShares = alicePosition.baseDrawnShares.percentMulUp(
      aliceExpectedRiskPremium
    );
    assertEq(
      expectedPremiumDrawnShares,
      alicePosition.premiumDrawnShares,
      'alice usdx premium drawn shares after time skip'
    );
    aliceUsdxInfo.premiumDrawnShares = expectedPremiumDrawnShares;

    // Check base debt values

    // Bob's dai debt after 1 year
    if (bobDaiInfo.borrowAmount > 0) {
      bobDaiInfo.baseDebt = MathUtils
        .calculateLinearInterest(hub.getBaseInterestRate(daiAssetId), uint40(startTime))
        .rayMulUp(bobDaiInfo.borrowAmount);

      (debtChecks.actualBaseDebt, ) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
      assertEq(bobDaiInfo.baseDebt, debtChecks.actualBaseDebt, 'bob dai base debt after');
    }

    // Bob's usdx debt after 1 year
    if (bobUsdxInfo.borrowAmount > 0) {
      bobUsdxInfo.baseDebt = MathUtils
        .calculateLinearInterest(hub.getBaseInterestRate(usdxAssetId), uint40(startTime))
        .rayMulUp(bobUsdxInfo.borrowAmount);

      (debtChecks.actualBaseDebt, ) = spoke1.getUserDebt(_usdxReserveId(spoke1), bob);
      assertEq(bobUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'bob usdx base debt after');
    }

    // Alice's dai debt after 1 year
    if (aliceDaiInfo.borrowAmount > 0) {
      aliceDaiInfo.baseDebt = MathUtils
        .calculateLinearInterest(hub.getBaseInterestRate(daiAssetId), uint40(startTime))
        .rayMulUp(aliceDaiInfo.borrowAmount);

      (debtChecks.actualBaseDebt, ) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);
      assertEq(aliceDaiInfo.baseDebt, debtChecks.actualBaseDebt, 'alice dai base debt after');
    }

    // Alice's usdx debt after 1 year
    if (aliceUsdxInfo.borrowAmount > 0) {
      aliceUsdxInfo.baseDebt = MathUtils
        .calculateLinearInterest(hub.getBaseInterestRate(usdxAssetId), uint40(startTime))
        .rayMulUp(aliceUsdxInfo.borrowAmount);

      (debtChecks.actualBaseDebt, debtChecks.actualPremium) = spoke1.getUserDebt(
        _usdxReserveId(spoke1),
        alice
      );
      assertEq(aliceUsdxInfo.baseDebt, debtChecks.actualBaseDebt, 'alice usdx base debt after');
    }

    _verifyProtocolDebtShares(
      bobDaiInfo,
      aliceDaiInfo,
      bobUsdxInfo,
      aliceUsdxInfo,
      'after accrual'
    );

    // Skip time before Bob repay
    skip(timeSkip[1]);

    // Bob repay half dai debt
    if (bobDaiInfo.borrowAmount > 2) {
      uint256 repayAmount = (bobDaiInfo.baseDebt + bobDaiInfo.premiumDebt) / 2;
      Utils.repay(spoke1, _daiReserveId(spoke1), bob, repayAmount, bob);

      // Bob's risk premium should change
      bobExpectedRiskPremium = _calculateExpectedUserRP(bob, spoke1);

      // Verify his new risk premium
      assertEq(
        spoke1.getUserRiskPremium(bob),
        bobExpectedRiskPremium,
        'bob risk premium after repay'
      );

      // Alice risk premium unchanged, check via premium drawn shares
      assertEq(
        aliceDaiInfo.premiumDrawnShares,
        spoke1.getUserPosition(_daiReserveId(spoke1), alice).premiumDrawnShares,
        'alice premium drawn shares after bob repay'
      );
      assertEq(
        aliceUsdxInfo.premiumDrawnShares,
        spoke1.getUserPosition(_usdxReserveId(spoke1), alice).premiumDrawnShares,
        'alice usdx premium drawn shares after bob repay'
      );
    }

    // Alice borrows more usdx and we check risk premiums
    if (
      aliceUsdxInfo.borrowAmount > 2 &&
      spoke1.getUserSuppliedAmount(_usdxReserveId(spoke1), alice) >
      spoke1.getUserTotalDebt(_usdxReserveId(spoke1), alice) * 3 &&
      spoke1.getHealthFactor(alice) > WadRayMath.WAD
    ) {
      // Store Bob old premium drawn shares before Alice borrow
      bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
      bobUsdxInfo.premiumDrawnShares = bobPosition.premiumDrawnShares;
      bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
      bobDaiInfo.premiumDrawnShares = bobPosition.premiumDrawnShares;

      // Alice increases her USDX borrow by 50%
      uint256 additionalBorrow = aliceUsdxInfo.borrowAmount / 2;
      Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, additionalBorrow, alice);

      // Alice's risk premium should change
      aliceExpectedRiskPremium = _calculateExpectedUserRP(alice, spoke1);

      // Verify her new risk premium
      assertEq(
        spoke1.getUserRiskPremium(alice),
        aliceExpectedRiskPremium,
        'alice risk premium after borrow'
      );

      // Verify Bob's risk premium remains the same by checking premium drawn shares
      bobPosition = spoke1.getUserPosition(_usdxReserveId(spoke1), bob);
      assertEq(
        bobUsdxInfo.premiumDrawnShares,
        bobPosition.premiumDrawnShares,
        'bob dai premium drawn shares after alice borrow'
      );
      bobPosition = spoke1.getUserPosition(_daiReserveId(spoke1), bob);
      assertEq(
        bobDaiInfo.premiumDrawnShares,
        bobPosition.premiumDrawnShares,
        'bob usdx premium drawn shares after alice borrow'
      );
    }

    // Store user premiumDrawnShares before time skip (unchanged)
    bobDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(_daiReserveId(spoke1), bob)
      .premiumDrawnShares;
    bobUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(_usdxReserveId(spoke1), bob)
      .premiumDrawnShares;
    aliceDaiInfo.premiumDrawnShares = spoke1
      .getUserPosition(_daiReserveId(spoke1), alice)
      .premiumDrawnShares;
    aliceUsdxInfo.premiumDrawnShares = spoke1
      .getUserPosition(_usdxReserveId(spoke1), alice)
      .premiumDrawnShares;

    // Skip time to accrue interest
    skip(timeSkip[2]);

    // Get base debts after time skip (changed)
    (bobDaiInfo.baseDebt, ) = spoke1.getUserDebt(_daiReserveId(spoke1), bob);
    (bobUsdxInfo.baseDebt, ) = spoke1.getUserDebt(_usdxReserveId(spoke1), bob);
    (aliceDaiInfo.baseDebt, ) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);
    (aliceUsdxInfo.baseDebt, ) = spoke1.getUserDebt(_usdxReserveId(spoke1), alice);

    // Verify final reserve states and hub propagation for both assets
    _verifyProtocolDebtShares(bobDaiInfo, aliceDaiInfo, bobUsdxInfo, aliceUsdxInfo, 'final');
  }

  /// Bob supplies and borrows varying amounts of 4 reserves. We fuzz prices and collateral risks, and wait arbitrary time.
  /// We ensure risk premium is calculated correctly before and after the time passing
  function test_getUserRiskPremium_fuzz_inflight_calcs(
    UserBorrowAction memory daiAmounts,
    UserBorrowAction memory wethAmounts,
    UserBorrowAction memory usdxAmounts,
    UserBorrowAction memory wbtcAmounts,
    uint40 skipTime
  ) public {
    skipTime = uint40(bound(skipTime, 1, MAX_SKIP_TIME));

    daiAmounts.supplyAmount = bound(daiAmounts.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wethAmounts.supplyAmount = bound(wethAmounts.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    usdxAmounts.supplyAmount = bound(usdxAmounts.supplyAmount, 0, MAX_SUPPLY_AMOUNT);
    wbtcAmounts.supplyAmount = bound(wbtcAmounts.supplyAmount, 0, MAX_SUPPLY_AMOUNT);

    daiAmounts.borrowAmount = bound(daiAmounts.borrowAmount, 0, daiAmounts.supplyAmount / 2);
    wethAmounts.borrowAmount = bound(wethAmounts.borrowAmount, 0, wethAmounts.supplyAmount / 2);
    usdxAmounts.borrowAmount = bound(usdxAmounts.borrowAmount, 0, usdxAmounts.supplyAmount / 2);
    wbtcAmounts.borrowAmount = bound(wbtcAmounts.borrowAmount, 0, wbtcAmounts.supplyAmount / 2);

    // Ensure supplied value is at least double borrowed value to pass hf checks
    vm.assume(
      _getValueInBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmounts.supplyAmount) +
        _getValueInBaseCurrency(spoke1, _wethReserveId(spoke1), wethAmounts.supplyAmount) +
        _getValueInBaseCurrency(spoke1, _usdxReserveId(spoke1), usdxAmounts.supplyAmount) +
        _getValueInBaseCurrency(spoke1, _wbtcReserveId(spoke1), wbtcAmounts.supplyAmount) >=
        2 *
          (_getValueInBaseCurrency(spoke1, _daiReserveId(spoke1), daiAmounts.borrowAmount) +
            _getValueInBaseCurrency(spoke1, _wethReserveId(spoke1), wethAmounts.borrowAmount) +
            _getValueInBaseCurrency(spoke1, _usdxReserveId(spoke1), usdxAmounts.borrowAmount) +
            _getValueInBaseCurrency(spoke1, _wbtcReserveId(spoke1), wbtcAmounts.borrowAmount))
    );

    // Bob supplies and draws all assets on spoke1
    if (daiAmounts.supplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, daiAmounts.supplyAmount, bob);
    }
    if (wethAmounts.supplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, wethAmounts.supplyAmount, bob);
    }
    if (usdxAmounts.supplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), bob, usdxAmounts.supplyAmount, bob);
    }
    if (wbtcAmounts.supplyAmount > 0) {
      Utils.supplyCollateral(spoke1, _wbtcReserveId(spoke1), bob, wbtcAmounts.supplyAmount, bob);
    }

    if (daiAmounts.borrowAmount > 0) {
      Utils.borrow(spoke1, _daiReserveId(spoke1), bob, daiAmounts.borrowAmount, bob);
    }
    if (wethAmounts.borrowAmount > 0) {
      Utils.borrow(spoke1, _wethReserveId(spoke1), bob, wethAmounts.borrowAmount, bob);
    }
    if (usdxAmounts.borrowAmount > 0) {
      Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, usdxAmounts.borrowAmount, bob);
    }
    if (wbtcAmounts.borrowAmount > 0) {
      Utils.borrow(spoke1, _wbtcReserveId(spoke1), bob, wbtcAmounts.borrowAmount, bob);
    }

    // Check bob's user risk premium
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium'
    );

    // Now skip some time
    skip(skipTime);

    // Recheck bob's user risk premium
    assertEq(
      spoke1.getUserRiskPremium(bob),
      _calculateExpectedUserRP(bob, spoke1),
      'user risk premium after time skip'
    );
  }

  function _boundUserBorrowAction(
    UserBorrowAction memory action
  ) internal pure returns (UserBorrowAction memory) {
    action.supplyAmount = bound(action.supplyAmount, 2, MAX_SUPPLY_AMOUNT / 2);
    action.borrowAmount = bound(action.borrowAmount, 1, action.supplyAmount / 2);
    return action;
  }

  function _verifyProtocolDebtAmounts(
    UserInfoLocal memory bobDaiInfo,
    UserInfoLocal memory aliceDaiInfo,
    UserInfoLocal memory bobUsdxInfo,
    UserInfoLocal memory aliceUsdxInfo,
    string memory label
  ) internal view {
    DebtChecks memory debtChecks;
    // Check reserve debt for dai
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(
      _daiReserveId(spoke1)
    );

    // Reserve debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.reserveDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      1,
      string.concat('reserve base debt ', label)
    );

    // Reserve premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.reservePremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      1,
      string.concat('reserve premium debt ', label)
    );

    // Check reserve debt for usdx
    (debtChecks.reserveDebt, debtChecks.reservePremium) = spoke1.getReserveDebt(
      _usdxReserveId(spoke1)
    );

    // Reserve debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.reserveDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      1,
      string.concat('reserve base debt ', label)
    );

    // Reserve premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.reservePremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      1,
      string.concat('reserve premium debt ', label)
    );

    // Check spoke debt on hub for dai
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));

    // Spoke debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.spokeDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      1,
      string.concat('hub spoke base debt ', label)
    );

    // Spoke premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.spokePremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      1,
      string.concat('hub spoke premium debt ', label)
    );

    // Check spoke debt on hub for usdx
    (debtChecks.spokeDebt, debtChecks.spokePremium) = hub.getSpokeDebt(
      usdxAssetId,
      address(spoke1)
    );

    // Spoke debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.spokeDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      1,
      string.concat('hub spoke base debt ', label)
    );

    // Spoke premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.spokePremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      1,
      string.concat('hub spoke premium debt ', label)
    );

    // Check asset debt on hub for dai
    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(daiAssetId);

    // Asset debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.assetDebt,
      bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt,
      1,
      string.concat('hub asset base debt ', label)
    );

    // Asset premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.assetPremium,
      bobDaiInfo.premiumDebt + aliceDaiInfo.premiumDebt,
      1,
      string.concat('hub asset premium debt ', label)
    );

    // Check asset debt on hub for usdx
    (debtChecks.assetDebt, debtChecks.assetPremium) = hub.getAssetDebt(usdxAssetId);

    // Asset debt should be the sum of both user debts
    assertApproxEqAbs(
      debtChecks.assetDebt,
      bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt,
      1,
      string.concat('hub asset base debt ', label)
    );

    // Asset premium debt should be the sum of both users' premium debt
    assertApproxEqAbs(
      debtChecks.assetPremium,
      bobUsdxInfo.premiumDebt + aliceUsdxInfo.premiumDebt,
      1,
      string.concat('hub asset premium debt ', label)
    );
  }

  function _verifyProtocolDebtShares(
    UserInfoLocal memory bobDaiInfo,
    UserInfoLocal memory aliceDaiInfo,
    UserInfoLocal memory bobUsdxInfo,
    UserInfoLocal memory aliceUsdxInfo,
    string memory label
  ) internal view {
    // Check base drawn shares and premium drawn shares for dai
    DataTypes.Reserve memory reserve = spoke1.getReserve(_daiReserveId(spoke1));

    // Reserve base drawn shares should be the sum of both users' base drawn shares
    assertApproxEqAbs(
      reserve.baseDrawnShares,
      hub.convertToDrawnShares(daiAssetId, bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt),
      1,
      string.concat('reserve dai base drawn shares ', label)
    );

    // Reserve premium drawn shares should be the sum of both users' premium drawn shares
    assertEq(
      reserve.premiumDrawnShares,
      bobDaiInfo.premiumDrawnShares + aliceDaiInfo.premiumDrawnShares,
      string.concat('reserve dai premium drawn shares ', label)
    );

    // Check base drawn shares and premium drawn shares for usdx
    reserve = spoke1.getReserve(_usdxReserveId(spoke1));

    // Reserve base drawn shares should be the sum of both users' base drawn shares
    assertApproxEqAbs(
      reserve.baseDrawnShares,
      hub.convertToDrawnShares(usdxAssetId, bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt),
      1,
      string.concat('reserve usdx base drawn shares ', label)
    );

    // Reserve premium drawn shares should be the sum of both users' premium drawn shares
    assertEq(
      reserve.premiumDrawnShares,
      bobUsdxInfo.premiumDrawnShares + aliceUsdxInfo.premiumDrawnShares,
      string.concat('reserve usdx premium drawn shares ', label)
    );

    // Verify spoke debts on hub for dai
    DataTypes.SpokeData memory spoke = hub.getSpoke(daiAssetId, address(spoke1));
    assertApproxEqAbs(
      spoke.baseDrawnShares,
      hub.convertToDrawnShares(daiAssetId, bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt),
      1,
      string.concat('hub spoke dai base debt ', label)
    );
    assertEq(
      spoke.premiumDrawnShares,
      bobDaiInfo.premiumDrawnShares + aliceDaiInfo.premiumDrawnShares,
      string.concat('hub spoke dai premium debt ', label)
    );

    // Verify spoke debts on hub for usdx
    spoke = hub.getSpoke(usdxAssetId, address(spoke1));
    assertApproxEqAbs(
      spoke.baseDrawnShares,
      hub.convertToDrawnShares(usdxAssetId, bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt),
      1,
      string.concat('hub spoke usdx base debt ', label)
    );
    assertEq(
      spoke.premiumDrawnShares,
      bobUsdxInfo.premiumDrawnShares + aliceUsdxInfo.premiumDrawnShares,
      string.concat('hub spoke usdx premium debt ', label)
    );

    // Verify asset debts on hub
    DataTypes.Asset memory asset = hub.getAsset(daiAssetId);
    assertApproxEqAbs(
      asset.baseDrawnShares,
      hub.convertToDrawnShares(daiAssetId, bobDaiInfo.baseDebt + aliceDaiInfo.baseDebt),
      1,
      string.concat('hub asset dai base debt ', label)
    );
    assertEq(
      asset.premiumDrawnShares,
      bobDaiInfo.premiumDrawnShares + aliceDaiInfo.premiumDrawnShares,
      string.concat('hub asset dai premium debt ', label)
    );

    asset = hub.getAsset(usdxAssetId);
    assertApproxEqAbs(
      asset.baseDrawnShares,
      hub.convertToDrawnShares(usdxAssetId, bobUsdxInfo.baseDebt + aliceUsdxInfo.baseDebt),
      1,
      string.concat('hub asset usdx base debt ', label)
    );
    assertEq(
      asset.premiumDrawnShares,
      bobUsdxInfo.premiumDrawnShares + aliceUsdxInfo.premiumDrawnShares,
      string.concat('hub asset usdx premium debt ', label)
    );
  }
}
