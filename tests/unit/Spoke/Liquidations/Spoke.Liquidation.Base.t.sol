// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for *;
  using SafeCast for uint256;

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
    Balance userTotalReserveDebt;
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
    Balance[] userTotalReserveDebts;
    Balance[] spokeTotalDebts;
    DataTypes.DynamicReserveConfig collDynConfig;
    DataTypes.DynamicReserveConfig[] collDynConfigs;
    Reserve[] collateralReserves;
    Reserve[] debtReserves;
    Reserve collateralReserve; // collateral reserve being liquidated
    Reserve debtReserve; // debt reserve being liquidated
    address user;
    uint256 liquidationBonus;
    uint256 desiredHf;
    SupplyExchangeRate rate;
    uint256 collToLiq;
    uint256 debtToLiq;
    uint16 liquidationFee;
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
    bool hasDustFromDebt; // if dust remains from calculateActualDebtToLiquidate; debtToLiquidate amount will be adjusted
    bool hasDustFromAvailableCollateral; // if dust remains from naive calculateAvailableCollateralToLiquidate; will revert
    bool isMultiDebtReserve;
    uint256 minLeftoverAmount;
    uint256 naiveLeftoverDebtAmount;
  }

  struct Amount {
    uint256 wbtc;
    uint256 weth;
    uint256 dai;
    uint256 usdx;
  }

  struct LiqScenarioTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    Amount collAmount;
    Amount debtAmount;
    Balance userTotalReserveDebt;
    Balance userSuppliedAmount;
    Balance liquidatorDebt;
    Balance liquidatorCollateral;
    Balance user;
    uint256 closeFactor;
    uint256 liqBonus;
    uint256 initialDebt;
    uint256 finalDebt;
    uint256 liquidatedDebt;
    uint256 healthFactor;
    uint256 userRp;
    DataTypes.UserPosition wbtcPosition;
    DataTypes.UserPosition wethPosition;
  }

  uint256 internal constant MIN_AMOUNT_IN_BASE_CURRENCY = 1e26;
  uint256 internal constant MIN_LEFTOVER_BASE = LiquidationLogic.MIN_LEFTOVER_BASE;

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
    ).toUint128();
    liqConfig.healthFactorForMaxBonus = bound(
      liqConfig.healthFactorForMaxBonus,
      0.01e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    ).toUint64();
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00)
      .toUint16();

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
    ).toUint128();
    liqConfig.liquidationBonusFactor = 0;
    liqConfig.healthFactorForMaxBonus = 0;

    return liqConfig;
  }

  /// @notice Execute generic liquidation call fuzz test with a desired initial user health factor.
  /// @param desiredHf Desired user health factor prior to liquidation.
  function _execLiqCallFuzzTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint32 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint16 liquidationFee,
    uint256 skipTime
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserves = new Reserve[](1);
    state.debtReserves = new Reserve[](1);
    state.spoke = spoke1;
    state.user = alice;

    state.collateralReserves[state.collateralReserveIndex] = _getReserve(
      state.spoke,
      collateralReserveId
    );
    state.debtReserves[state.debtReserveIndex] = _getReserve(state.spoke, debtReserveId);
    state.collateralReserve = state.collateralReserves[state.collateralReserveIndex];
    state.debtReserve = state.debtReserves[state.debtReserveIndex];

    state.collDynConfig = _getUserDynConfig(spoke1, state.user, collateralReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(
      liqBonus,
      MIN_LIQUIDATION_BONUS,
      PercentageMath.PERCENTAGE_FACTOR.percentDivDown(state.collDynConfig.collateralFactor)
    ).toUint32();
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.01e18);
    liquidationFee = bound(liquidationFee, 0, PercentageMath.PERCENTAGE_FACTOR).toUint16();
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

    state = _getAccountingInfoBeforeLiquidation(collateralReserveId, debtReserveId, state);

    // Get alice's dynamic config key before liquidation
    DynamicConfig[] memory configKeysBefore = _getUserDynConfigKeys(spoke1, alice);

    (
      state.collToLiq,
      state.debtToLiq,
      state.liquidationFeeAmount,
      ,
      state.hasDustFromDebt
    ) = _calculateCollateralAndDebtToLiquidate(state, UINT256_MAX);

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
      collateralReserveId,
      debtReserveId,
      alice,
      state.debtToLiq,
      state.collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    state.spoke.liquidationCall(collateralReserveId, debtReserveId, alice, UINT256_MAX);

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
    _assertNoDustRemains(state, label);
    _assertLiquidationAccountingWithSkipTime(state, label);
  }

  function _assertNoDustRemains(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    // either position is fully liquidated, or no dust remains
    // however, dust can remain if collateral reserve is fully liquidated
    assertTrue(
      state.userTotalReserveDebt.balanceAfter == 0 ||
        state.userTotalReserveDebt.balanceAfter >= state.minLeftoverAmount ||
        state.userSuppliedShares.balanceAfter == 0,
      string.concat('no remaining dust ', label)
    );
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
    state.userTotalReserveDebt.balanceSkipTime =
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
    state.userTotalReserveDebt.balanceChangeSkipTime = stdMath.delta(
      state.userTotalReserveDebt.balanceSkipTime,
      state.userTotalReserveDebt.balanceAfter
    );
    state.spokeTotalDebt.balanceChangeSkipTime = stdMath.delta(
      state.spokeTotalDebt.balanceSkipTime,
      state.spokeTotalDebt.balanceAfter
    );
    state.reserveTotalDebt.balanceChangeSkipTime = stdMath.delta(
      state.reserveTotalDebt.balanceSkipTime,
      state.reserveTotalDebt.balanceAfter
    );

    if (state.userTotalReserveDebt.balanceBefore == state.spokeTotalDebt.balanceBefore) {
      // if user and spoke debts initially match, they should accrue at the same rate
      assertEq(
        state.userTotalReserveDebt.balanceChangeSkipTime,
        state.spokeTotalDebt.balanceChangeSkipTime,
        string.concat('user/spoke total debt accounting after skipTime ', label)
      );
    } else {
      // otherwise debt interest accrual is at min the amount from user position
      assertLe(
        state.userTotalReserveDebt.balanceChangeSkipTime,
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
      state.userTotalReserveDebt.balanceChange,
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
      getAssetUnderlyingByReserveId(state.spoke, state.collateralReserveId).balanceOf(
        address(state.spoke)
      ),
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
    if (state.hasDustFromDebt) {
      if (!state.isMultiDebtReserve) {
        /// HF > CloseFactor holds for single debt reserve, bc more debt was liquidated than expected
        /// for multi reserve, liquidating the whole debt may or may not bring HF below CF
        assertGt(state.finalHf, state.closeFactor, string.concat('HF should exceed closeFactor'));
      }
    } else {
      // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
      if (
        _convertAmountToBaseCurrency(
          state.spoke,
          state.debtReserve.reserveId,
          state.userTotalReserveDebt.balanceAfter
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
      uint256 bpsError = 1;
      assertApproxEqRel(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        _approxRelFromBps(bpsError),
        string.concat('liquidationBonus earned amount, rel bps ', vm.toString(bpsError), ' ', label)
      );
    } else {
      uint256 approxError = 1;
      assertApproxEqAbs(
        totalLiqBonusAmount,
        expectedLiqBonusAmount,
        approxError,
        string.concat(
          'liquidationBonus earned amount, eq abs ',
          vm.toString(approxError),
          ' ',
          label
        )
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
    assertEq(
      state.userTotalReserveDebt.balanceAfter,
      0,
      string.concat('debt amount should be 0 ', label)
    );
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
    // total collateral in user's position should be > 0
    assertGt(
      state.totalCollateralInBaseCurrency.balanceAfter,
      0,
      string.concat('totalCollateralInBaseCurrency should be > 0 ', label)
    );
    if (!state.hasDustFromDebt) {
      // if no dust to re-adjust liquidated debt, remaining debt should be > 0
      assertGt(
        state.totalDebtInBaseCurrency.balanceAfter,
        0,
        string.concat('totalDebtInBaseCurrency should be > 0 ', label)
      );
    }
    assertApproxEqAbs(
      state.userTotalReserveDebt.balanceAfter,
      state.userTotalReserveDebt.balanceBefore - state.debtToLiq,
      state.assetAmountOfOneDrawnShare + 1,
      string.concat('expected userTotalReserveDebt ', label)
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
  /// @return isZero True if user's RP is expected to be 0, False otherwise.
  function _shouldUserRpBeZero(ISpoke spoke, address user) internal view returns (bool isZero) {
    bool hasCollateralWithRisk = false;
    uint256 totalDebtInBaseCurrency;
    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
      totalDebtInBaseCurrency += _convertAmountToBaseCurrency(
        spoke,
        reserveId,
        spoke.getUserTotalDebt(reserveId, user)
      );
      if (
        reserve.collateralRisk > 0 &&
        spoke.getUserSuppliedShares(reserveId, user) > 0 &&
        spoke.isUsingAsCollateral(reserveId, user)
      ) {
        hasCollateralWithRisk = true;
      }
    }

    isZero = !(hasCollateralWithRisk && totalDebtInBaseCurrency > 0);
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
  function _calculateCollateralAndDebtToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  )
    internal
    view
    returns (
      uint256 actualCollateralToLiquidate,
      uint256 actualDebtToLiquidate,
      uint256 liquidationFeeAmount,
      bool hasDeficit,
      bool hasDustFromDebt
    )
  {
    IPriceOracle oracle = state.spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.borrowerCollateralBalance = state.spoke.getUserSuppliedAmount(
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
    (
      ,
      ,
      params.healthFactor,
      params.totalCollateralInBaseCurrency,
      params.totalDebtInBaseCurrency
    ) = state.spoke.getUserAccountData(state.user);

    (params.actualDebtToLiquidate, hasDustFromDebt) = calculateActualDebtToLiquidate(
      state,
      debtToCover
    );

    // if actualDebtToLiquidate is 0, it should revert in practice
    if (params.actualDebtToLiquidate != 0) {
      (
        actualCollateralToLiquidate,
        actualDebtToLiquidate,
        liquidationFeeAmount,
        hasDeficit
      ) = calculateAvailableCollateralToLiquidate(state, params, debtToCover);
    } else {
      actualCollateralToLiquidate = 0;
      actualDebtToLiquidate = 0;
      liquidationFeeAmount = 0;
      hasDeficit = false;
    }
  }

  function calculateAvailableCollateralToLiquidate(
    LiquidationTestLocalParams memory state,
    DataTypes.LiquidationCallLocalVars memory params,
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
    DataTypes.CalculateAvailableCollateralToLiquidate memory vars;

    // convert existing collateral to base currency
    vars.borrowerCollateralBalanceInBaseCurrency =
      (params.borrowerCollateralBalance * params.collateralAssetPrice).toWad() /
      params.collateralAssetUnit;

    // find collateral in base currency that corresponds to the debt to cover
    vars.baseCollateral =
      (params.actualDebtToLiquidate * params.debtAssetPrice).toWad() /
      params.debtAssetUnit;

    // account for additional collateral required due to liquidation bonus
    vars.maxCollateralToLiquidate = vars.baseCollateral.percentMulDown(params.liquidationBonus);

    if (vars.maxCollateralToLiquidate >= vars.borrowerCollateralBalanceInBaseCurrency) {
      vars.collateralAmount = params.borrowerCollateralBalance;
      vars.debtAmountNeeded = ((params.debtAssetUnit * vars.borrowerCollateralBalanceInBaseCurrency)
        .percentDivDown(params.liquidationBonus) / params.debtAssetPrice).fromWadDown();
      vars.collateralToLiquidateInBaseCurrency = vars.borrowerCollateralBalanceInBaseCurrency;
      vars.debtToLiquidateInBaseCurrency =
        (vars.debtAmountNeeded * params.debtAssetPrice).toWad() /
        params.debtAssetUnit;
    } else {
      // add 1 to round collateral amount up, ensuring HF is always <= close factor
      vars.collateralAmount =
        ((vars.maxCollateralToLiquidate * params.collateralAssetUnit) / params.collateralAssetPrice)
          .fromWadDown() +
        1;
      vars.debtAmountNeeded = params.actualDebtToLiquidate;
      vars.collateralToLiquidateInBaseCurrency =
        (vars.collateralAmount * params.collateralAssetPrice).toWad() /
        params.collateralAssetUnit;
      vars.debtToLiquidateInBaseCurrency = vars.baseCollateral;
    }

    vars.hasDeficit =
      vars.debtToLiquidateInBaseCurrency < params.totalDebtInBaseCurrency &&
      vars.collateralToLiquidateInBaseCurrency == params.totalCollateralInBaseCurrency;

    if (params.liquidationFee != 0) {
      uint256 bonusCollateral = vars.collateralAmount -
        vars.collateralAmount.percentDivUp(params.liquidationBonus);
      uint256 liquidationFeeAmount = bonusCollateral.percentMulUp(params.liquidationFee);
      return (
        vars.collateralAmount - liquidationFeeAmount,
        vars.debtAmountNeeded,
        liquidationFeeAmount,
        vars.hasDeficit
      );
    } else {
      return (vars.collateralAmount, vars.debtAmountNeeded, 0, vars.hasDeficit);
    }
  }

  /// helper to calculate actual collateral to liquidate, replicating LiquidationLogic.calculateActualDebtToLiquidate.
  /// @return actualDebtToLiquidate Amount of actual debt to liquidate.
  function calculateActualDebtToLiquidate(
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal view returns (uint256 actualDebtToLiquidate, bool hasDustFromDebt) {
    uint256 totalBorrowerReserveDebt = state.userTotalReserveDebt.balanceBefore;
    uint256 debtToRestoreCloseFactor = _calcDebtToRestoreCloseFactor(state.spoke, state);

    uint256 maxLiquidatableDebt = _min(debtToCover, totalBorrowerReserveDebt);
    actualDebtToLiquidate = _min(maxLiquidatableDebt, debtToRestoreCloseFactor);
    uint256 remainingDebtInBaseCurrency = _convertAmountToBaseCurrency(
      state.spoke,
      state.debtReserveId,
      totalBorrowerReserveDebt - actualDebtToLiquidate
    );

    // only adjust actualDebtToLiquidate if there is non zero dust remaining
    if (
      remainingDebtInBaseCurrency < LiquidationLogic.MIN_LEFTOVER_BASE &&
      remainingDebtInBaseCurrency != 0
    ) {
      if (debtToCover == actualDebtToLiquidate) {
        actualDebtToLiquidate = 0;
      }
      if (
        debtToCover < totalBorrowerReserveDebt &&
        _convertAmountToBaseCurrency(
          state.spoke,
          state.debtReserveId,
          totalBorrowerReserveDebt - debtToCover
        ) <
        LiquidationLogic.MIN_LEFTOVER_BASE
      ) {
        actualDebtToLiquidate = 0;
      } else {
        actualDebtToLiquidate = maxLiquidatableDebt;
        hasDustFromDebt = true;
      }
    }

    return (actualDebtToLiquidate, hasDustFromDebt);
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

  function calcDebtToRestoreCloseFactor(
    ISpoke spoke,
    uint256 reserveId,
    address user,
    uint256 liquidationBonus,
    uint256 closeFactor
  ) internal view returns (uint256) {
    IPriceOracle oracle = spoke.oracle();
    DataTypes.LiquidationCallLocalVars memory params;

    params.debtAssetUnit = 10 ** spoke.getReserve(reserveId).decimals;
    params.debtAssetPrice = oracle.getReservePrice(reserveId);

    (, , params.healthFactor, , params.totalDebtInBaseCurrency) = spoke.getUserAccountData(user);

    // duplicated logic from LiquidationLogic.calculateDebtToRestoreCloseFactor
    uint256 effectiveLiquidationPenalty = (liquidationBonus.toWad())
      .percentMulDown(_getCollateralFactor(spoke, reserveId))
      .fromBpsDown();
    if (closeFactor < effectiveLiquidationPenalty) {
      return UINT256_MAX;
    }
    return
      (((params.totalDebtInBaseCurrency * params.debtAssetUnit) *
        (closeFactor - params.healthFactor)) /
        ((closeFactor - effectiveLiquidationPenalty + 1) * params.debtAssetPrice)).fromWadDown();
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
    healthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD.percentMulUp(collateralFactor).percentMulUp(
      liquidationBonus
    );
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
    uint256 collateralReserveId,
    uint256 debtReserveId,
    LiquidationTestLocalParams memory state
  ) internal view returns (LiquidationTestLocalParams memory) {
    state.debtReserveId = debtReserveId;
    state.collateralReserveId = collateralReserveId;
    state.collateralAssetId = state.collateralReserve.assetId;
    state.debtAssetId = state.debtReserve.assetId;
    state.closeFactor = _getCloseFactor(state.spoke);
    state.collateralHub = state.collateralReserve.hub;
    state.debtHub = state.debtReserve.hub;

    state.minLeftoverAmount = _convertBaseCurrencyToAmount(
      state.spoke,
      state.debtReserveId,
      LiquidationLogic.MIN_LEFTOVER_BASE
    );

    (state.userDrawnDebt.balanceBefore, state.userPremiumDebt.balanceBefore) = state
      .spoke
      .getUserDebt(state.debtReserve.reserveId, state.user);
    state.userTotalReserveDebt.balanceBefore =
      state.userDrawnDebt.balanceBefore +
      state.userPremiumDebt.balanceBefore;
    state.liquidatorCollateral.balanceBefore = getAssetUnderlyingByReserveId(
      state.spoke,
      state.collateralReserveId
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceBefore = getAssetUnderlyingByReserveId(
      state.spoke,
      state.debtReserveId
    ).balanceOf(LIQUIDATOR);
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
    state.userTotalReserveDebts = new Balance[](state.debtReserves.length);
    state.deficits = new Balance[](state.debtReserves.length);
    for (uint256 i = 0; i < state.debtReserves.length; i++) {
      state.deficits[i].balanceBefore = getDeficit(
        state.debtReserves[i].hub,
        state.debtReserves[i].assetId
      );
      state.userTotalReserveDebts[i].balanceBefore = state.spoke.getUserTotalDebt(
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
    state.liquidatorCollateral.balanceAfter = getAssetUnderlyingByReserveId(
      state.spoke,
      state.collateralReserveId
    ).balanceOf(LIQUIDATOR);
    state.liquidatorDebt.balanceAfter = getAssetUnderlyingByReserveId(
      state.spoke,
      state.debtReserveId
    ).balanceOf(LIQUIDATOR);
    (state.userDrawnDebt.balanceAfter, state.userPremiumDebt.balanceAfter) = state
      .spoke
      .getUserDebt(state.debtReserve.reserveId, state.user);
    state.userTotalReserveDebt.balanceAfter =
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
    state.userTotalReserveDebt.balanceChange = stdMath.delta(
      state.userTotalReserveDebt.balanceAfter,
      state.userTotalReserveDebt.balanceBefore
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
    state.userTotalReserveDebt.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.debtReserve.reserveId,
      state.userTotalReserveDebt.balanceChange
    );
    state.userSuppliedAmount.baseChange = _convertAmountToBaseCurrency(
      state.spoke,
      state.collateralReserve.reserveId,
      state.userSuppliedAmount.balanceChange
    );

    state.outstandingDebt = state.userTotalReserveDebt.balanceBefore - state.debtToLiq;
    (
      state.userRp,
      ,
      state.finalHf,
      state.totalCollateralInBaseCurrency.balanceAfter,
      state.totalDebtInBaseCurrency.balanceAfter
    ) = state.spoke.getUserAccountData(state.user);

    state.hasDeficit =
      state.userSuppliedAmount.balanceAfter == 0 &&
      state.userTotalReserveDebt.balanceAfter == 0;
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
      state.userTotalReserveDebts[i].balanceAfter = state.spoke.getUserTotalDebt(
        state.debtReserves[i].reserveId,
        state.user
      );
      state.userTotalReserveDebts[i].balanceChange = stdMath.delta(
        state.userTotalReserveDebts[i].balanceAfter,
        state.userTotalReserveDebts[i].balanceBefore
      );
    }

    state.assetAmountOfOneDrawnShare = minimumAssetsPerDrawnShare(
      state.debtHub,
      state.debtReserve.assetId
    );

    return state;
  }
}
