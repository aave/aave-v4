// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 balanceChange;
    uint256 baseChange;
    uint256 balanceSkipTime;
    uint256 balanceChangeSkipTime;
  }

  struct ConvertedValues {
    uint256 base;
    uint256 amount;
  }

  struct SupplyExchangeRate {
    uint256 rateBefore;
    uint256 rateAfter;
  }

  struct LiquidationTestLocalParams {
    IHub collateralHub;
    IHub debtHub;
    ISpoke spoke;
    Balance liquidatorDebt;
    Balance liquidatorCollateral;
    Balance feeReceiverAmount;
    Balance feeReceiverShares;
    Balance userTotalDebt;
    Balance userDrawnDebt;
    Balance userPremiumDebt;
    Balance spokeTotalDebt;
    Balance spokeDrawn;
    Balance spokePremium;
    Balance reserveTotalDebt;
    Balance reserveDrawnDebt;
    Balance reservePremiumDebt;
    Balance userSuppliedAmount;
    Balance userSuppliedShares;
    Balance spokeSuppliedAmount;
    Balance spokeSuppliedShares;
    Balance reserveSuppliedAmount;
    Balance reserveSuppliedShares;
    Balance deficit;
    Balance totalCollateralInBaseCurrency;
    Balance totalDebtInBaseCurrency;
    Balance[] deficits;
    Balance[] userTotalDebts;
    Balance[] spokeTotalDebts;
    DataTypes.DynamicReserveConfig collDynConfig;
    DataTypes.DynamicReserveConfig[] collDynConfigs;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
    DataTypes.Reserve collateralReserve; // collateral reserve being liquidated
    DataTypes.Reserve debtReserve; // debt reserve being liquidated
    address user;
    uint256 liquidationBonus;
    uint256 desiredHf;
    SupplyExchangeRate rate;
    uint256 collToLiq;
    uint256 debtToLiq;
    uint256 liquidationFee;
    uint256 liquidationFeeAmount;
    uint256 liquidationFeeShares;
    bool hasDeficit;
    uint256 outstandingDebt;
    uint256 userRp;
    uint256 finalHf;
    uint256 initialHf;
    bool usingAsCollateral;
    bool isBorrowing;
    uint256 debtReserveIndex;
    uint256 collateralReserveIndex;
    uint256 hfBadDebtThreshold;
    uint256 debtReserveId;
    uint256 collateralReserveId;
    uint256 closeFactor;
    uint256 collateralAssetId;
    uint256 debtAssetId;
    uint256 expectedDeficitAmount;
    uint256 expectedDeficitShares;
    uint256 assetAmountOfOneDrawnShare;
  }

  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26;

  function setUp() public virtual override {
    super.setUp();
    _addBorrowableLiquidities(MAX_SUPPLY_AMOUNT);
  }

  /// @notice Deploys max borrowable liquidity for all reserves in spoke1.
  function _addBorrowableLiquidities(uint256 amount) public {
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), amount);
    _openSupplyPosition(spoke1, _usdyReserveId(spoke1), amount);
  }

  /// @notice Bound liquidation config to full range of possible values
  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );
    liqConfig.healthFactorForMaxBonus = bound(
      liqConfig.healthFactorForMaxBonus,
      0.01e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  /// @notice Bound liqConfig close factor.
  /// Set non-variable liquidation bonus to simplify calcs for desiredHf.
  function _boundCloseFactor(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      MIN_CLOSE_FACTOR,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD * 10
    );
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorForMaxBonus = 0;

    return liqConfig;
  }

  /// @notice Execute generic liquidation call fuzz test with a desired initial user health factor.
  /// @param desiredHf Desired user health factor prior to liquidation.
  function _execLiqCallFuzzTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new DataTypes.Reserve[](1);
    state.debtReserves = new DataTypes.Reserve[](1);
    state.spoke = spoke1;
    state.user = alice;

    state.collateralReserves[state.collateralReserveIndex] = state.spoke.getReserve(
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = state.spoke.getReserve(debtReserveId);
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    state.collDynConfig = _getUserDynConfig(spoke1, state.user, collateralReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    );
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationFee = bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR);
    // bound supply amount to max supply amount
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(
        state.spoke,
        state.collateralReserve.reserveId,
        MIN_AMOUNT_IN_BASE_CURRENCY
      ),
      _min(
        _convertBaseCurrencyToAmount(
          state.spoke,
          state.collateralReserve.reserveId,
          MAX_SUPPLY_IN_BASE_CURRENCY
        ),
        MAX_SUPPLY_AMOUNT / 10 // buffer for growth due to interest accrual
      )
    );
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    state.liquidationFee = liquidationFee;

    updateLiquidationConfig(state.spoke, liqConfig);
    updateLiquidationBonus(state.spoke, collateralReserveId, liqBonus);
    updateLiquidationFee(state.spoke, collateralReserveId, state.liquidationFee);

    Utils.supplyCollateral({
      spoke: state.spoke,
      reserveId: collateralReserveId,
      caller: state.user,
      amount: supplyAmount,
      onBehalfOf: state.user
    });

    _borrowWithoutHfCheck({
      spoke: spoke1,
      user: bob,
      reserveId: collateralReserveId,
      debtAmount: supplyAmount / 2
    });
    skip(skipTime);

    vm.assume(
      _getRequiredDebtAmountForLtHf(spoke1, state.user, debtReserveId, desiredHf) <=
        MAX_SUPPLY_AMOUNT
    );
    // borrow some amount of debt reserve to end up below hf threshold
    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      state.spoke,
      state.user,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = state.spoke.getVariableLiquidationBonus(
      collateralReserveId,
      state.user,
      hfAfterBorrow
    );

    state = _getAccountingInfoBeforeLiquidation(state);

    // Get alice's dynamic config key before liquidation
    DynamicConfig[] memory configKeysBefore = _getUserDynConfigKeys(spoke1, alice);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,

    ) = _calculateAvailableCollateralToLiquidate(state, requiredDebtAmount);

    state.liquidationFeeShares =
      state.collateralHub.previewRemoveByAssets(
        state.collateralReserve.assetId,
        state.collToLiq + state.liquidationFeeAmount
      ) -
      state.collateralHub.previewRemoveByAssets(state.collateralReserve.assetId, state.collToLiq);

    if (collateralReserveId != debtReserveId) {
      vm.expectCall(
        address(state.collateralHub),
        abi.encodeWithSelector(
          state.collateralHub.payFee.selector,
          state.collateralReserve.assetId,
          state.liquidationFeeShares
        ),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    } else {
      // precision loss can occur when coll and debt reserve are the same
      // during a restore action that includes donation
      vm.expectCall(
        address(state.collateralHub),
        abi.encodeWithSelector(IHub.payFee.selector),
        state.liquidationFeeShares > 0 ? 1 : 0
      );
    }

    vm.expectEmit(address(state.spoke));
    emit ISpokeBase.LiquidationCall(
      state.collateralReserve.underlying,
      state.debtReserve.underlying,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state = _getAccountingInfoAfterLiquidation(state);

    // Validate alice's dynamic config key unchanged after liquidation
    assertEq(_getUserDynConfigKeys(spoke1, alice), configKeysBefore);

    return state;
  }

  /// post-liquidation checks
  function _checkLiquidation(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal {
    _assertLiquidationFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertSupplyExchangeRate(state, label);
    _assertSetUsingAsCollateral(state, label);
    if (state.hasDeficit) {
      _assertBadDebt(state, label);
    } else {
      _assertNoBadDebt(state, label);
      _assertUserAccountData(state, label);
    }
    _assertLiquidationAccounting(state, label);
    _assertLiquidationAccountingWithSkipTime(state, label);
  }

  // accounting assertions with skip time after a liquidation
  function _assertLiquidationAccountingWithSkipTime(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal {
    skip(340 days);

    // user debt
    (state.userDrawnDebt.balanceSkipTime, state.userPremiumDebt.balanceSkipTime) = state
      .spoke
      .getUserDebt(state.debtReserve.reserveId, state.user);
    state.userTotalDebt.balanceSkipTime =
      state.userDrawnDebt.balanceSkipTime +
      state.userPremiumDebt.balanceSkipTime;
    // reserve debt
    (state.reserveDrawnDebt.balanceSkipTime, state.reservePremiumDebt.balanceSkipTime) = state
      .spoke
      .getReserveDebt(state.debtReserveId);
    state.reserveTotalDebt.balanceSkipTime =
      state.reserveDrawnDebt.balanceSkipTime +
      state.reservePremiumDebt.balanceSkipTime;
    // spoke debt
    (state.spokeDrawn.balanceSkipTime, state.spokePremium.balanceSkipTime) = state
      .debtHub
      .getSpokeOwed(state.debtReserve.assetId, address(state.spoke));
    state.spokeTotalDebt.balanceSkipTime =
      state.spokeDrawn.balanceSkipTime +
      state.spokePremium.balanceSkipTime;

    // balance changes before/after liquidation
    state.userTotalDebt.balanceChangeSkipTime = stdMath.delta(
      state.userTotalDebt.balanceSkipTime,
      state.userTotalDebt.balanceAfter
    );
    state.spokeTotalDebt.balanceChangeSkipTime = stdMath.delta(
      state.spokeTotalDebt.balanceSkipTime,
      state.spokeTotalDebt.balanceAfter
    );
    state.reserveTotalDebt.balanceChangeSkipTime = stdMath.delta(
      state.reserveTotalDebt.balanceSkipTime,
      state.reserveTotalDebt.balanceAfter
    );

    if (state.userTotalDebt.balanceBefore == state.spokeTotalDebt.balanceBefore) {
      // if user and spoke debts initially match, they should accrue at the same rate
      assertEq(
        state.userTotalDebt.balanceChangeSkipTime,
        state.spokeTotalDebt.balanceChangeSkipTime,
        string.concat('user/spoke total debt accounting after skipTime ', label)
      );
    } else {
      // otherwise debt interest accrual is at min the amount from user position
      assertLe(
        state.userTotalDebt.balanceChangeSkipTime,
        state.spokeTotalDebt.balanceChangeSkipTime,
        string.concat('user/spoke total debt accounting after skipTime ', label)
      );
    }
    // interest accrual should match between spoke/hub
    assertEq(
      state.reserveTotalDebt.balanceChangeSkipTime,
      state.spokeTotalDebt.balanceChangeSkipTime,
      string.concat('reserve/spoke total debt change accounting after skipTime ', label)
    );
    assertEq(
      state.reserveTotalDebt.balanceSkipTime,
      state.spokeTotalDebt.balanceSkipTime,
      string.concat('reserve/spoke total debt accounting after skipTime ', label)
    );
  }

  /// @dev check that spoke accounting from hub matches user accounting from spoke
  function _assertLiquidationAccounting(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // debt asset - user vs spoke accounting
    assertApproxEqAbs(
      state.userTotalDebt.balanceChange,
      state.spokeTotalDebt.balanceChange,
      3,
      string.concat('user/spoke total debt accounting ', label)
    );
    assertApproxEqAbs(
      state.userDrawnDebt.balanceChange,
      state.spokeDrawn.balanceChange,
      1,
      string.concat('user/spoke drawn debt accounting ', label)
    );
    assertApproxEqAbs(
      state.userPremiumDebt.balanceChange,
      state.spokePremium.balanceChange,
      2,
      string.concat('user/spoke premium debt accounting ', label)
    );
    // debt asset - reserve vs spoke accounting
    assertEq(
      state.reserveTotalDebt.balanceChange,
      state.spokeTotalDebt.balanceChange,
      string.concat('reserve/spoke total debt accounting ', label)
    );
    assertEq(
      state.reserveDrawnDebt.balanceChange,
      state.spokeDrawn.balanceChange,
      string.concat('reserve/spoke drawn debt accounting ', label)
    );
    assertEq(
      state.reservePremiumDebt.balanceChange,
      state.spokePremium.balanceChange,
      string.concat('reserve/spoke premium debt accounting ', label)
    );
    // collateral asset - user vs spoke accounting
    assertEq(
      state.userSuppliedShares.balanceChange,
      state.spokeSuppliedShares.balanceChange,
      string.concat('user/spoke supplied shares collateral accounting ', label)
    );
    // collateral asset - reserve vs spoke accounting
    assertEq(
      state.reserveSuppliedShares.balanceChange,
      state.spokeSuppliedShares.balanceChange,
      string.concat('reserve/spoke supplied shares collateral accounting ', label)
    );
    assertEq(
      IERC20(state.collateralReserve.underlying).balanceOf(address(state.spoke)),
      0,
      string.concat('no spoke collateral underlying should remain ', label)
    );
    assertBorrowRateSynced(
      state.collateralHub,
      state.collateralAssetId,
      'liquidationCall collateral'
    );
    assertBorrowRateSynced(state.debtHub, state.debtAssetId, 'liquidationCall debt');
  }

  /// assert that the user account data is correct after liquidation, without deficit
  function _assertUserAccountData(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view virtual {
    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(
        state.spoke,
        state.debtReserve.reserveId,
        state.userTotalDebt.balanceAfter
      ) >
      MIN_AMOUNT_IN_BASE_CURRENCY &&
      _convertAmountToBaseCurrency(
        state.spoke,
        state.collateralReserve.reserveId,
        state.userSuppliedAmount.balanceAfter
      ) >
      MIN_AMOUNT_IN_BASE_CURRENCY
    ) {
      // ensure HF is lte close factor
      assertLe(
        state.finalHf,
        state.closeFactor,
        string.concat('Health factor <= close factor ', label)
      );
      uint256 bpsError = 20;
      // should also be close to the desired CF
      assertApproxEqRel(
        state.finalHf,
        state.closeFactor,
        _approxRelFromBps(bpsError),
        string.concat('HF matches closeFactor within ', vm.toString(bpsError), ' bps')
      );
    } else {
      // HF should always be lte close factor
      assertLe(
        state.finalHf,
        state.closeFactor,
        string.concat('Health factor <= close factor ', label)
      );
    }
    assertEq(
      state.userRp,
      _calculateExpectedUserRP(state.user, state.spoke),
      string.concat('userRp after liq ', label)
    );
  }

  function _assertLiquidationFeeEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.userSuppliedAmount.balanceChange -
      state.userSuppliedAmount.balanceChange.percentDivUp(state.liquidationBonus);
    uint256 expectedLiquidationFeeShares = state
      .collateralHub
      .convertToAddedShares(state.collateralReserve.assetId, totalLiqBonusAmount)
      .percentMulUp(state.liquidationFee);
    uint256 liquidationFeeShares = state.feeReceiverShares.balanceChange;

    // TODO: resolve precision loss difference
    assertApproxEqAbs(
      liquidationFeeShares,
      expectedLiquidationFeeShares,
      2,
      string.concat('liquidationFeeShares ', label)
    );
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 totalLiqBonusAmount = state.userSuppliedAmount.balanceChange -
      state.userSuppliedAmount.balanceChange.percentDivDown(state.liquidationBonus);

    uint256 totalCollateralSeized = (state.collToLiq + state.liquidationFeeAmount);
    // liquidationBonus == PERCENTAGE_FACTOR represents liq bonus being 0
    uint256 expectedLiqBonusAmount = state.liquidationBonus != PercentageMath.PERCENTAGE_FACTOR
      ? totalCollateralSeized - totalCollateralSeized.percentDivDown(state.liquidationBonus)
      : 0;

    if (
      _convertAmountToBaseCurrency(spoke1, state.collateralReserveId, totalLiqBonusAmount) >
      MIN_AMOUNT_IN_BASE_CURRENCY
    ) {
      assertApproxEqRel(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        _approxRelFromBps(1),
        string.concat('liquidationBonus earned in base currency, rel 20 bps ', label)
      );
    } else {
      assertApproxEqAbs(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        1,
        string.concat('liquidationBonus earned in base currency, eq abs 1 ', label)
      );
    }
  }

  function _assertSetUsingAsCollateral(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    // usingAsCollateral should never be disabled during liquidation
    assertTrue(
      state.usingAsCollateral,
      string.concat('isUsingAsCollateral should be true with remaining collateral ', label)
    );
  }

  /// assertions when bad debt remains and is reported as deficit
  function _assertBadDebt(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    // all collateral seized; all debt liquidated and moved to deficit
    assertEq(
      state.userSuppliedShares.balanceAfter,
      0,
      string.concat('supply shares should be 0 ', label)
    );
    assertEq(state.userTotalDebt.balanceAfter, 0, string.concat('debt amount should be 0 ', label));
    assertTrue(state.hasDeficit, string.concat('supply shares & total debt should be 0 ', label));
    // HF should be max value and userRp should be 0 (due to no coll remaining)
    assertEq(state.finalHf, UINT256_MAX, string.concat('HF = 0 if bad debt ', label));
    assertEq(state.userRp, 0, string.concat('userRp = 0 if bad debt ', label));
    assertGe(
      state.deficit.balanceChange,
      state.outstandingDebt,
      string.concat('deficit can only exceed amount restored due to rounding direction ', label)
    );
    // precision error is asset equivalent of 1 share, due to rounding in restore
    // and 1 wei due to rounding of premium debt
    // outstanding debt should be moved to deficit
    assertApproxEqAbs(
      state.deficit.balanceChange,
      state.outstandingDebt,
      state.assetAmountOfOneDrawnShare + 1,
      string.concat('deficit should match restored amount ', label)
    );
    assertEq(state.isBorrowing, false, string.concat('isBorrowing should be false ', label));
  }

  /// generic assertions in non bad debt scenarios
  function _assertNoBadDebt(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    // total debt/collateral in user's position should be > 0
    assertGt(
      state.totalCollateralInBaseCurrency.balanceAfter,
      0,
      string.concat('totalCollateralInBaseCurrency should be > 0 ', label)
    );
    assertGt(
      state.totalDebtInBaseCurrency.balanceAfter,
      0,
      string.concat('totalDebtInBaseCurrency should be > 0 ', label)
    );
    // with collateral/debt remaining, user rp should only be 0 if all coll reserves have liquidity premium == 0
    if (_shouldUserRpBeZero(state.spoke, state.user)) {
      assertEq(state.userRp, 0, string.concat('user rp should be 0 ', label));
    } else {
      assertNotEq(state.userRp, 0, string.concat('user rp should not equal 0 ', label));
    }

    // deficit should remain unchanged
    assertEq(state.deficit.balanceChange, 0, string.concat('deficit should be unchanged ', label));
  }

  /// @dev User's RP should be 0 if all coll reserves have liquidity premium == 0.
  /// @return bool True if user's RP is expected to be 0, False otherwise.
  function _shouldUserRpBeZero(ISpoke spoke, address user) internal view returns (bool) {
    for (uint256 i = 0; i < spoke.getReserveCount(); i++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(i);
      if (
        reserve.config.collateralRisk > 0 &&
        spoke.getUserSuppliedShares(reserve.reserveId, user) > 0 &&
        spoke.isUsingAsCollateral(reserve.reserveId, user)
      ) {
        return false;
      }
    }
    return true;
  }

  /**
   * @dev Calculate output from LiquidationLogic.calculateAvailableCollateralToLiquidate.
   * @param state LiquidationTestLocalParams struct containing local params.
   * @param debtToCover Desired amount of debt to cover.
   * @return actualCollateralToLiquidate Amount of actual collateral to liquidate.
   * @return actualDebtToLiquidate Amount of actual debt to liquidate.
   * @return liquidationFeeAmount Amount of protocol fee (in asset).
   * @return hasDeficit Boolean indicating if there is a deficit in the liquidation.
   */
  function _calculateAvailableCollateralToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  )
    internal
    view
    returns (
      uint256 actualCollateralToLiquidate,
      uint256 actualDebtToLiquidate,
      uint256 liquidationFeeAmount,
      bool hasDeficit
    )
  {
    IPriceOracle oracle = state.spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = state.spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    params.collateralAssetUnit = 10 ** state.collateralReserve.decimals;
    params.collateralReserveId = state.collateralReserve.reserveId;
    params.collateralAssetPrice = oracle.getReservePrice(state.collateralReserve.reserveId);
    params.debtAssetUnit = 10 ** state.debtReserve.decimals;
    params.debtReserveId = state.debtReserve.reserveId;
    params.debtAssetPrice = oracle.getReservePrice(state.debtReserve.reserveId);
    params.liquidationBonus = state.liquidationBonus;
    params.liquidationFee = state.liquidationFee;

    params.actualDebtToLiquidate = _calculateActualDebtToLiquidate(state, debtToCover);
    return LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }

  /// helper to calculate actual collateral to liquidate, replicating LiquidationLogic.calculateActualDebtToLiquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  function _calculateActualDebtToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal view returns (uint256 actualDebtToLiquidate) {
    // find minimum between user's totalDebt of debt asset, debtToCover, and debtToRestoreCloseFactor
    uint256 userTotalDebt = state.userTotalDebt.balanceBefore;
    uint256 debtToRestoreCloseFactor = _calcDebtToRestoreCloseFactor(state.spoke, state);
    return _min(_min(userTotalDebt, debtToCover), debtToRestoreCloseFactor);
  }

  /// @notice Calculate amount of debt to liquidate to restore HF to close factor.
  /// @return debtToRestoreCloseFactor Amount of debt to liquidate to restore HF to close factor.
  function _calcDebtToRestoreCloseFactor(
    ISpoke spoke,
    LiquidationTestLocalParams memory state
  ) internal view returns (uint256 debtToRestoreCloseFactor) {
    IPriceOracle oracle = spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.liquidationBonus = state.liquidationBonus;
    params.collateralFactor = state.collDynConfig.collateralFactor;
    params.closeFactor = _getCloseFactor(spoke);

    params.debtAssetUnit = 10 ** state.debtReserve.decimals;
    params.debtAssetPrice = oracle.getReservePrice(state.debtReserve.reserveId);

    (, , params.healthFactor, , params.totalDebtInBaseCurrency) = spoke.getUserAccountData(alice);
    // duplicated logic from LiquidationLogic.calculateDebtToRestoreCloseFactor
    uint256 effectiveLiquidationPenalty = (params.liquidationBonus.toWad())
      .percentMulDown(params.collateralFactor)
      .fromBpsDown();
    if (params.closeFactor < effectiveLiquidationPenalty) {
      return UINT256_MAX;
    }
    return
      (((params.totalDebtInBaseCurrency * params.debtAssetUnit) *
        (params.closeFactor - params.healthFactor)) /
        ((params.closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice))
        .fromWadDown();
  }

  /// @notice Calc user's lowest possible health factor whereby a liqudation can still restore HF to close factor.
  /// for multiple collateral assets
  /// @return healthFactor in WAD
  function _calcLowestHfForBadDebt(
    ISpoke spoke,
    address user,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    (, uint256 avgCollateralFactor, , , ) = spoke.getUserAccountData(user);
    return _calcLowestHfForBadDebt(avgCollateralFactor.fromWadDown(), liquidationBonus);
  }

  /// given collateral factor and liquidation bonus, calculate the lowest health factor possible
  /// whereby a liquidation can still restore HF to close factor
  function _calcLowestHfForBadDebt(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) internal pure returns (uint256 healthFactor) {
    healthFactor = uint256(HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
      .percentMulUp(collateralFactor)
      .percentMulUp(liquidationBonus);
  }

  /// assert that supply ex rate after liquidation is greater than or equal to before
  /// ex rate can increase due to shares rounding on withdraw
  function _assertSupplyExchangeRate(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    assertGe(
      state.rate.rateAfter,
      state.rate.rateBefore,
      string.concat('Supply exchange rate should be gte before ', label)
    );
  }

  /**
   * @dev Get accounting info before liquidation, in base currency and amount.
   * @return LiquidationTestLocalParams struct with updated balances.
   */
  function _getAccountingInfoBeforeLiquidation(
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.debtReserveId = state.debtReserve.reserveId;
    state.debtAssetId = state.debtReserve.assetId;
    state.collateralReserveId = state.collateralReserve.reserveId;
    state.collateralAssetId = state.collateralReserve.assetId;
    state.closeFactor = _getCloseFactor(state.spoke);

    state.collateralHub = state.collateralReserve.hub;
    state.debtHub = state.debtReserve.hub;

    (state.userDrawnDebt.balanceBefore, state.userPremiumDebt.balanceBefore) = state
      .spoke
      .getUserDebt(state.debtReserve.reserveId, state.user);
    state.userTotalDebt.balanceBefore =
      state.userDrawnDebt.balanceBefore +
      state.userPremiumDebt.balanceBefore;
    state.liquidatorCollateral.balanceBefore = IERC20(state.collateralReserve.underlying).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceBefore = IERC20(state.debtReserve.underlying).balanceOf(LIQUIDATOR);
    state.userSuppliedAmount.balanceBefore = state.spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      state.user
    );
    state.userSuppliedShares.balanceBefore = state.spoke.getUserSuppliedShares(
      state.collateralReserve.reserveId,
      state.user
    );
    state.spokeSuppliedAmount.balanceBefore = state.collateralHub.getSpokeAddedAmount(
      state.collateralReserve.assetId,
      address(state.spoke)
    );
    state.spokeSuppliedShares.balanceBefore = state.collateralHub.getSpokeAddedShares(
      state.collateralReserve.assetId,
      address(state.spoke)
    );
    state.reserveSuppliedAmount.balanceBefore = state.spoke.getReserveSuppliedAmount(
      state.collateralReserveId
    );
    state.reserveSuppliedShares.balanceBefore = state.spoke.getReserveSuppliedShares(
      state.collateralReserveId
    );
    state.rate.rateBefore = state.collateralHub.convertToAddedAssets(
      state.collateralReserve.assetId,
      WadRayMath.RAY
    );
    state.deficit.balanceBefore = getDeficit(state.debtHub, state.debtReserve.assetId);

    (state.spokeDrawn.balanceBefore, state.spokePremium.balanceBefore) = state
      .collateralHub
      .getSpokeOwed(state.debtReserve.assetId, address(state.spoke));
    state.spokeTotalDebt.balanceBefore =
      state.spokeDrawn.balanceBefore +
      state.spokePremium.balanceBefore;

    (state.reserveDrawnDebt.balanceBefore, state.reservePremiumDebt.balanceBefore) = state
      .spoke
      .getReserveDebt(state.debtReserveId);
    state.reserveTotalDebt.balanceBefore =
      state.reserveDrawnDebt.balanceBefore +
      state.reservePremiumDebt.balanceBefore;

    (
      ,
      ,
      state.initialHf,
      state.totalCollateralInBaseCurrency.balanceBefore,
      state.totalDebtInBaseCurrency.balanceBefore
    ) = state.spoke.getUserAccountData(state.user);

    // multi reserve accounting
    state.userTotalDebts = new Balance[](state.debtReserves.length);
    state.deficits = new Balance[](state.debtReserves.length);
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceBefore = getDeficit(
        state.debtReserves[i].hub,
        state.debtReserves[i].assetId
      );
      state.userTotalDebts[i].balanceBefore = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
    }
    state.feeReceiverAmount.balanceBefore = state.collateralHub.getSpokeAddedAmount(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
    );
    state.feeReceiverShares.balanceBefore = state.collateralHub.getSpokeAddedShares(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
    );

    return state;
  }

  /// @notice Get accounting info after liquidation, in base currency and amount.
  /// @return LiquidationTestLocalParams struct with updated balances.
  function _getAccountingInfoAfterLiquidation(
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.feeReceiverAmount.balanceAfter = state.collateralHub.getSpokeAddedAmount(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
    );
    state.feeReceiverShares.balanceAfter = state.collateralHub.getSpokeAddedShares(
      state.collateralReserve.assetId,
      _getFeeReceiver(state.collateralReserve.assetId)
    );
    state.liquidatorCollateral.balanceAfter = IERC20(state.collateralReserve.underlying).balanceOf(
      LIQUIDATOR
    );
    state.liquidatorDebt.balanceAfter = IERC20(state.debtReserve.underlying).balanceOf(LIQUIDATOR);
    (state.userDrawnDebt.balanceAfter, state.userPremiumDebt.balanceAfter) = state
      .spoke
      .getUserDebt(state.debtReserve.reserveId, state.user);
    state.userTotalDebt.balanceAfter =
      state.userDrawnDebt.balanceAfter +
      state.userPremiumDebt.balanceAfter;
    state.userSuppliedAmount.balanceAfter = state.spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      state.user
    );
    state.userSuppliedShares.balanceAfter = state.spoke.getUserSuppliedShares(
      state.collateralReserve.reserveId,
      state.user
    );
    state.spokeSuppliedAmount.balanceAfter = state.collateralHub.getSpokeAddedAmount(
      state.collateralReserve.assetId,
      address(state.spoke)
    );
    state.spokeSuppliedShares.balanceAfter = state.collateralHub.getSpokeAddedShares(
      state.collateralReserve.assetId,
      address(state.spoke)
    );
    state.reserveSuppliedAmount.balanceAfter = state.spoke.getReserveSuppliedAmount(
      state.collateralReserveId
    );
    state.reserveSuppliedShares.balanceAfter = state.spoke.getReserveSuppliedShares(
      state.collateralReserveId
    );
    state.rate.rateAfter = state.collateralHub.convertToAddedAssets(
      state.collateralReserve.assetId,
      WadRayMath.RAY
    );
    state.deficit.balanceAfter = getDeficit(state.debtReserve.hub, state.debtReserve.assetId);
    (state.spokeDrawn.balanceAfter, state.spokePremium.balanceAfter) = state.debtHub.getSpokeOwed(
      state.debtReserve.assetId,
      address(state.spoke)
    );
    state.spokeTotalDebt.balanceAfter =
      state.spokeDrawn.balanceAfter +
      state.spokePremium.balanceAfter;
    (state.reserveDrawnDebt.balanceAfter, state.reservePremiumDebt.balanceAfter) = state
      .spoke
      .getReserveDebt(state.debtReserveId);
    state.reserveTotalDebt.balanceAfter =
      state.reserveDrawnDebt.balanceAfter +
      state.reservePremiumDebt.balanceAfter;

    // balance changes before/after liquidation
    state.liquidatorCollateral.balanceChange = stdMath.delta(
      state.liquidatorCollateral.balanceAfter,
      state.liquidatorCollateral.balanceBefore
    );
    state.liquidatorDebt.balanceChange = stdMath.delta(
      state.liquidatorDebt.balanceAfter,
      state.liquidatorDebt.balanceBefore
    );
    state.userTotalDebt.balanceChange = stdMath.delta(
      state.userTotalDebt.balanceAfter,
      state.userTotalDebt.balanceBefore
    );
    state.userDrawnDebt.balanceChange = stdMath.delta(
      state.userDrawnDebt.balanceAfter,
      state.userDrawnDebt.balanceBefore
    );
    state.userPremiumDebt.balanceChange = stdMath.delta(
      state.userPremiumDebt.balanceAfter,
      state.userPremiumDebt.balanceBefore
    );
    state.spokeTotalDebt.balanceChange = stdMath.delta(
      state.spokeTotalDebt.balanceAfter,
      state.spokeTotalDebt.balanceBefore
    );
    state.spokeDrawn.balanceChange = stdMath.delta(
      state.spokeDrawn.balanceAfter,
      state.spokeDrawn.balanceBefore
    );
    state.spokePremium.balanceChange = stdMath.delta(
      state.spokePremium.balanceAfter,
      state.spokePremium.balanceBefore
    );
    state.reserveTotalDebt.balanceChange = stdMath.delta(
      state.reserveTotalDebt.balanceAfter,
      state.reserveTotalDebt.balanceBefore
    );
    state.reserveDrawnDebt.balanceChange = stdMath.delta(
      state.reserveDrawnDebt.balanceAfter,
      state.reserveDrawnDebt.balanceBefore
    );
    state.reservePremiumDebt.balanceChange = stdMath.delta(
      state.reservePremiumDebt.balanceAfter,
      state.reservePremiumDebt.balanceBefore
    );
    state.userSuppliedAmount.balanceChange = stdMath.delta(
      state.userSuppliedAmount.balanceAfter,
      state.userSuppliedAmount.balanceBefore
    );
    state.userSuppliedShares.balanceChange = stdMath.delta(
      state.userSuppliedShares.balanceAfter,
      state.userSuppliedShares.balanceBefore
    );
    state.spokeSuppliedAmount.balanceChange = stdMath.delta(
      state.spokeSuppliedAmount.balanceAfter,
      state.spokeSuppliedAmount.balanceBefore
    );
    state.spokeSuppliedShares.balanceChange = stdMath.delta(
      state.spokeSuppliedShares.balanceAfter,
      state.spokeSuppliedShares.balanceBefore
    );
    state.reserveSuppliedAmount.balanceChange = stdMath.delta(
      state.reserveSuppliedAmount.balanceAfter,
      state.reserveSuppliedAmount.balanceBefore
    );
    state.reserveSuppliedShares.balanceChange = stdMath.delta(
      state.reserveSuppliedShares.balanceAfter,
      state.reserveSuppliedShares.balanceBefore
    );
    state.deficit.balanceChange = stdMath.delta(
      state.deficit.balanceAfter,
      state.deficit.balanceBefore
    );
    state.feeReceiverAmount.balanceChange = stdMath.delta(
      state.feeReceiverAmount.balanceAfter,
      state.feeReceiverAmount.balanceBefore
    );
    state.feeReceiverShares.balanceChange = stdMath.delta(
      state.feeReceiverShares.balanceAfter,
      state.feeReceiverShares.balanceBefore
    );

    // convert amount to base currency
    state.liquidatorCollateral.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserve.reserveId,
      state.liquidatorCollateral.balanceChange
    );
    state.liquidatorDebt.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserve.reserveId,
      state.liquidatorDebt.balanceChange
    );
    state.userTotalDebt.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.debtReserve.reserveId,
      state.userTotalDebt.balanceChange
    );
    state.userSuppliedAmount.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserve.reserveId,
      state.userSuppliedAmount.balanceChange
    );

    state.outstandingDebt = state.userTotalDebt.balanceBefore - state.debtToLiq;
    (
      state.userRp,
      ,
      state.finalHf,
      state.totalCollateralInBaseCurrency.balanceAfter,
      state.totalDebtInBaseCurrency.balanceAfter
    ) = state.spoke.getUserAccountData(state.user);

    state.hasDeficit =
      state.userSuppliedAmount.balanceAfter == 0 &&
      state.userTotalDebt.balanceAfter == 0;
    state.usingAsCollateral = state.spoke.isUsingAsCollateral(
      state.collateralReserve.reserveId,
      state.user
    );
    state.isBorrowing = state.spoke.isBorrowing(state.debtReserve.reserveId, state.user);

    // multi reserve accounting
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceAfter = getDeficit(
        state.debtReserves[i].hub,
        state.debtReserves[i].assetId
      );
      state.deficits[i].balanceChange = stdMath.delta(
        state.deficits[i].balanceAfter,
        state.deficits[i].balanceBefore
      );
      state.userTotalDebts[i].balanceAfter = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
      state.userTotalDebts[i].balanceChange = stdMath.delta(
        state.userTotalDebts[i].balanceAfter,
        state.userTotalDebts[i].balanceBefore
      );
    }

    state.assetAmountOfOneDrawnShare = minimumAssetsPerDrawnShare(
      state.debtHub,
      state.debtReserve.assetId
    );

    return state;
  }
}
