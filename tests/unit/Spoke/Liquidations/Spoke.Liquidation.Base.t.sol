// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  uint256 minSupplyInBaseCurrency = 10e26; // $10 in base currency
  uint256 remainingBaseCurrencyBound = 1e26; // $1 in base currency units

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 balanceChange;
    uint256 baseChange;
  }

  struct ConvertedValues {
    uint256 base;
    uint256 amount;
  }

  struct LiquidationTestLocalParams {
    Balance liquidator;
    Balance liquidatorCollateral;
    Balance user;
    Balance treasury;
    Balance collateral;
    Balance debt;
    Balance supply;
    uint256 liquidationBonus;
    uint256 collateralAssetId;
    uint256 debtAssetId;
    uint256 liquidationProtocolFeePercentage;
    DataTypes.Reserve collateralReserve;
    DataTypes.Reserve debtReserve;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 desiredHf;
  }

  DataTypes.LiquidationConfig internal _config;

  function setUp() public virtual override {
    super.setUp();
    _addBorrowableLiquidity();
  }

  /// @notice Deploys borrowable liquidity for all reserves in spoke1
  function _addBorrowableLiquidity() public {
    _deployLiquidity(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _usdyReserveId(spoke1), MAX_SUPPLY_AMOUNT);
  }

  function _getVariableLiquidationBonus(
    ISpoke spoke,
    uint256 reserveId,
    uint256 healthFactor
  ) internal view returns (uint256) {
    return
      LiquidationLogic.calculateVariableLiquidationBonus(
        _config,
        healthFactor,
        spoke.getReserve(reserveId).config.liquidationBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD
      );
  }

  function _borrowToBeBelowHf(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 desiredHf
  ) internal returns (uint256, uint256) {
    uint256 requiredDebtInBase = _getRequiredDebtForLtHf(spoke, user, desiredHf);
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    uint256 requiredDebtAmount = _convertBaseCurrencyToAmount(assetId, requiredDebtInBase) + 1;

    vm.assume(requiredDebtAmount < MAX_SUPPLY_AMOUNT);

    // mock price to 0 to circumvent borrow validation
    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, requiredDebtAmount, user);
    vm.clearMockedCalls();

    uint256 finalHf = spoke.getHealthFactor(user);
    console.log('final hf %e | desired hf %e', finalHf, desiredHf);
    assertLt(finalHf, desiredHf);
    return (finalHf, requiredDebtAmount);
  }

  function _borrowWithoutHfCheck(
    ISpoke spoke,
    address user,
    uint256 reserveId,
    uint256 debtAmount
  ) internal returns (uint256, uint256) {
    uint256 assetId = spoke.getReserve(reserveId).assetId;
    // mock price to 0 to circumvent borrow validation
    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, debtAmount, user);
    vm.clearMockedCalls();
  }

  /**
   * @notice Returns the required debt amount in base currency to ensure user position is below a certain health factor.
   */
  function _getRequiredDebtForLtHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal view returns (uint256 requiredDebt) {
    (
      ,
      uint256 currentAvgCollateralFactor,
      ,
      uint256 totalCollateralBase,
      uint256 totalDebtBase
    ) = spoke.getUserAccountData(user);

    requiredDebt =
      (
        (totalCollateralBase.percentMul(currentAvgCollateralFactor.dewadify() + 1))
          .wadMul(HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
          .wadDiv(desiredHf)
      ) -
      totalDebtBase;
    // add rounding to num/denom to round debt up (ie making sure resultant HF is less than desired)
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );
    liqConfig.healthFactorBonusThreshold = bound(
      liqConfig.healthFactorBonusThreshold,
      0.5e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  function _execLiqCallFuzzTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.1e18); // enough buffer so that collateral to be liquidated is not dust
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e26),
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e9 * 1e26)
    );

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    console.log('   fuzz inputs');
    console.log('   collateralReserveId %e', collateralReserveId);
    console.log('   debtReserveId %e', debtReserveId);
    console.log('   supplyAmount %e', supplyAmount);
    console.log('   closeFactor %e', liqConfig.closeFactor);
    console.log('   healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('   liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('   liqBonus %e', liqBonus);
    console.log('   liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);
    console.log('   desiredHf %e', desiredHf);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    console.log('   state.liquidationBonus %e', state.liquidationBonus);

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    console.log(
      'before liq: debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.debtReserve.assetId,
        spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice)
      )
    );
    console.log(
      'before liq: collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.collateralReserve.assetId,
        spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice)
      )
    );

    (uint256 collToLiq, uint256 debtToLiq) = _calcDebtAndCollateralToLiquidate(
      spoke1,
      state,
      requiredDebtAmount
    );

    vm.expectEmit(address(spoke1));
    emit ISpoke.LiquidationCall(
      state.collateralReserve.asset,
      state.debtReserve.asset,
      alice,
      debtToLiq,
      collToLiq,
      LIQUIDATOR
    );
    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    console.log(
      'after liq: debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.debtReserve.assetId,
        spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice)
      )
    );
    console.log(
      'after liq: collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.collateralReserve.assetId,
        spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice)
      )
    );

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    state.liquidator.balanceChange = _absDiff(
      state.liquidator.balanceAfter,
      state.liquidator.balanceBefore
    );
    state.supply.balanceChange = _absDiff(state.supply.balanceAfter, state.supply.balanceBefore);
    state.debt.balanceChange = _absDiff(state.debt.balanceAfter, state.debt.balanceBefore);

    // convert
    state.liquidator.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidator.balanceChange
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.supply.balanceChange
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      state.debt.balanceChange
    );

    return state;
  }

  // function _assertAccounting(
  //   LiquidationTestLocalParams memory state,
  //   ISpoke spoke,
  //   uint256 remainingBaseCurrencyBound
  // ) internal view {
  //   // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
  //   if (
  //     _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
  //     remainingBaseCurrencyBound &&
  //     _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
  //     remainingBaseCurrencyBound
  //   ) {
  //     assertEq(
  //       state.supply.baseChange.percentDiv(state.debt.baseChange),
  //       state.liquidationBonus,
  //       'liquidationBonus'
  //     );
  //   }
  // }

  function _assertUserAccountData(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    string memory label
  ) internal view virtual {
    (uint256 userRp, , uint256 finalHf, , ) = spoke1.getUserAccountData(alice);

    console.log('hf %e cf %e', finalHf, _getCloseFactor(spoke));

    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      remainingBaseCurrencyBound &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      remainingBaseCurrencyBound
    ) {
      // ensure HF is lte close factor
      assertLe(
        finalHf,
        _getCloseFactor(spoke),
        string.concat('Health factor <= close factor ', label)
      );
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(10),
        'HF matches closeFactor within 0.1%'
      );
    } else if (state.supply.balanceAfter == 0 && state.debt.balanceAfter > 0) {
      // bad debt
      assertEq(finalHf, 0, string.concat('HF = 0 if bad debt ', label));
      assertEq(userRp, 0, string.concat('userRp = 0 if bad debt ', label));
    } else if (state.debt.balanceAfter == 0) {
      assertEq(
        finalHf,
        type(uint256).max,
        string.concat('HF = max uint if all debt liquidated ', label)
      );
      if (state.supply.balanceAfter > 0) {
        assertEq(
          userRp,
          state.collateralReserve.config.collateralFactor,
          string.concat('userRp = coll factor of remaining coll ', label)
        );
      } else {
        // debt == 0, coll == 0
        assertEq(userRp, 0, string.concat('userRp = 0 if user debt and coll are 0 ', label));
      }
    } else {
      assertLe(
        finalHf,
        _getCloseFactor(spoke),
        string.concat('Health factor <= close factor ', label)
      );
    }
  }

  function _assertProtocolFeeEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    ConvertedValues memory liqBonusEarned;
    ConvertedValues memory liqProtocolFee;

    liqBonusEarned.base = state.debt.baseChange.percentMul(
      state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR
    );
    liqBonusEarned.amount = _convertBaseCurrencyToAmount(
      state.collateralReserve.assetId,
      liqBonusEarned.base
    );

    console.log('lb % %e', state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR);

    if (state.collateralReserve.assetId == state.debtReserve.assetId) {
      // when collateral and debt are the same asset, protocol fee is calculated as
      liqProtocolFee.base = _absDiff(
        _absDiff(state.supply.baseChange, state.debt.baseChange),
        state.liquidator.baseChange
      );
    } else {
      liqProtocolFee.base = _absDiff(state.supply.baseChange, state.liquidator.baseChange);
    }
    liqProtocolFee.amount = _convertBaseCurrencyToAmount(
      state.collateralReserve.assetId,
      liqProtocolFee.base
    );

    console.log(
      'amount diff liquidator: %e | supplyvsDebt %e',
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, state.liquidator.baseChange),
      _convertBaseCurrencyToAmount(
        state.collateralReserve.assetId,
        _absDiff(state.supply.baseChange, state.debt.baseChange)
      )
    );

    console.log('liqBonusEarned amt: %e base: %e', liqBonusEarned.amount, liqBonusEarned.base);
    console.log('liqProtocolFee amt: %e base: %e', liqProtocolFee.amount, liqProtocolFee.base);
    // console.log(
    //   'liqProtocolFee %e',
    //   _convertBaseCurrencyToAmount(
    //     state.collateralReserve.assetId,
    //     _absDiff(state.supply.baseChange, state.liquidator.baseChange)
    //   )
    // );

    console.log('final hf %e', spoke1.getHealthFactor(alice));

    // constrain due to rounding/precisio
    if (liqProtocolFee.amount < 1e3) {
      // at low amounts, abs diff is greater than rel
      assertApproxEqAbs(
        liqBonusEarned.amount.percentMul(state.liquidationProtocolFeePercentage),
        liqProtocolFee.amount,
        3,
        string.concat('protocol fee amount abs ', label)
      );
      assertApproxEqRel(
        _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
        _convertBaseCurrencyToAmount(
          state.collateralAssetId,
          state.debt.baseChange.percentMul(state.liquidationBonus)
        ),
        _approxRelFromBps(1_00),
        string.concat('total collateral seized should match debt rel ', label)
      );
    } else {
      assertApproxEqRel(
        liqBonusEarned.amount.percentMul(state.liquidationProtocolFeePercentage),
        liqProtocolFee.amount,
        _approxRelFromBps(1_00),
        string.concat('protocol fee amount rel ', label)
      );
      assertApproxEqRel(
        _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
        _convertBaseCurrencyToAmount(
          state.collateralAssetId,
          state.debt.baseChange.percentMul(state.liquidationBonus)
        ),
        _approxRelFromBps(1_00),
        string.concat('total collateral seized should match debt rel ', label)
      );
    }

    // if (state.supply.balanceChange > 1e4) {
    //   assertApproxEqRel(
    //     _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
    //     _convertBaseCurrencyToAmount(
    //       state.collateralAssetId,
    //       state.debt.baseChange.percentMul(state.liquidationBonus)
    //     ),
    //     _approxRelFromBps(10),
    //     string.concat('total collateral seized should match debt rel ', label)
    //   );
    // } else {
    //   assertApproxEqRel(
    //     _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
    //     _convertBaseCurrencyToAmount(
    //       state.collateralAssetId,
    //       state.debt.baseChange.percentMul(state.liquidationBonus)
    //     ),
    //     _approxRelFromBps(1_00),
    //     string.concat('total collateral seized should match debt rel ', label)
    //   );
    // }

    // console.log('coll change %e', state.collateral.baseChange);
    // console.log('debt change %e', state.debt.baseChange);

    // console.log('coll bal change %e', state.supply.balanceChange);
    // console.log('debt bal change %e', state.debt.balanceChange);

    // console.log(
    //   'expected coll/debt %e %e',
    //   state.debt.baseChange.percentMul(state.liquidationBonus),
    //   state.supply.balanceChange
    // );

    // console.log(
    //   'bonus %e %e',
    //   _absDiff(
    //     state.liquidator.baseChange,
    //     state.debt.baseChange.percentMul(state.liquidationBonus - 100_00)
    //   ),
    //   _convertBaseCurrencyToAmount(
    //     state.collateralReserve.assetId,
    //     _absDiff(state.liquidator.baseChange, state.supply.baseChange - state.debt.baseChange)
    //   )
    // );

    // if (
    //   _convertBaseCurrencyToAmount(state.collateralReserve.reserveId, state.collateral.baseChange) <
    //   1e4
    // ) {
    //   assertApproxEqAbs(
    //     _convertBaseCurrencyToAmount(
    //       state.collateralReserve.reserveId,
    //       state.collateral.baseChange
    //     ),
    //     _convertBaseCurrencyToAmount(
    //       state.collateralReserve.reserveId,
    //       state.debt.baseChange.percentMul(state.liquidationBonus)
    //     ),
    //     1,
    //     string.concat('total collateral seized should match debt abs ', label)
    //   );
    // } else {
    //   assertApproxEqRel(
    //     _convertBaseCurrencyToAmount(
    //       state.collateralReserve.reserveId,
    //       state.collateral.baseChange
    //     ),
    //     _convertBaseCurrencyToAmount(
    //       state.debtReserve.reserveId,
    //       state.debt.baseChange.percentMul(state.liquidationBonus)
    //     ),
    //     _approxRelFromBps(10),
    //     string.concat('total collateral seized should match debt rel ', label)
    //   );
    // }
  }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    if (
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, state.supply.balanceAfter) >
      1e26
    ) {
      assertApproxEqRel(
        state.supply.baseChange,
        state.debt.baseChange.percentMul(state.liquidationBonus),
        _approxRelFromBps(10),
        string.concat('liquidationBonus earned in base currency ', label)
      );
    } else {
      console.log('state.liquidationBonus %e', state.liquidationBonus);
      assertApproxEqRel(
        state.supply.baseChange,
        state.debt.baseChange.percentMul(state.liquidationBonus),
        _approxRelFromBps(1_00),
        string.concat('liquidationBonus earned in base currency ', label)
      );
    }
  }

  function _assertSetUsingAsCollateral(
    ISpoke spoke,
    address user,
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    if (state.supply.balanceAfter == 0) {
      assertFalse(
        spoke.getUsingAsCollateral(state.collateralReserve.reserveId, user),
        string.concat('isUsingAsCollateral should be false with no collateral ', label)
      );
    } else {
      assertTrue(
        spoke.getUsingAsCollateral(state.collateralReserve.reserveId, user),
        string.concat('isUsingAsCollateral should be false with no collateral ', label)
      );
    }
  }

  function _calcDebtAndCollateralToLiquidate(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal returns (uint256 actualDebtToLiquidate, uint256 collateralToLiquidate) {
    (actualDebtToLiquidate, collateralToLiquidate, ) = _calculateAvailableCollateralToLiquidate(
      spoke,
      state,
      debtToCover
    );
    console.log(
      '_calcDebtAndCollateralToLiquidate: coll %e debt %e',
      actualDebtToLiquidate,
      collateralToLiquidate
    );
  }

  function _calculateAvailableCollateralToLiquidate(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  )
    internal
    returns (
      uint256 actualCollateralToLiquidate,
      uint256 actualDebtToLiquidate,
      uint256 liquidationProtocolFeeAmount
    )
  {
    DataTypes.LiquidationCallLocalVars memory params;

    params.userCollateralBalance = spoke.getUserSuppliedAmount(
      state.collateralReserve.reserveId,
      alice
    );
    params.collateralAssetUnit = 10 ** state.collateralReserve.config.decimals;
    params.collateralReserveId = state.collateralReserve.reserveId;
    params.collateralAssetPrice = oracle.getAssetPrice(state.collateralReserve.assetId);

    params.debtAssetUnit = 10 ** state.debtReserve.config.decimals;
    params.debtReserveId = state.debtReserve.reserveId;
    params.debtAssetPrice = oracle.getAssetPrice(state.debtReserve.assetId);

    params.liquidationBonus = state.liquidationBonus;
    params.liquidationProtocolFeePercentage = state.liquidationProtocolFeePercentage;

    params.actualDebtToLiquidate = _calculateActualDebtToLiquidate(spoke, state, debtToCover);

    return LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }

  function _calculateActualDebtToLiquidate(
    ISpoke spoke,
    LiquidationTestLocalParams memory state,
    uint256 debtToCover
  ) internal returns (uint256 actualDebtToLiquidate) {
    // find minimum between user's totalDebt of debt asset, debtToCover, and debtToRestoreCloseFactor
    uint256 userTotalDebt = state.debt.balanceBefore;
    uint256 debtToRestoreCloseFactor = _calcDebtToRestoreCloseFactor(spoke, state);

    return _min(_min(userTotalDebt, debtToCover), debtToRestoreCloseFactor);
  }

  function _calcDebtToRestoreCloseFactor(
    ISpoke spoke,
    LiquidationTestLocalParams memory state
  ) internal returns (uint256 debtToRestoreCloseFactor) {
    DataTypes.LiquidationCallLocalVars memory params;

    params.liquidationBonus = state.liquidationBonus;
    params.collateralFactor = state.collateralReserve.config.collateralFactor;
    params.closeFactor = _getCloseFactor(spoke);

    params.debtAssetUnit = 10 ** state.debtReserve.config.decimals;
    params.debtAssetPrice = oracle.getAssetPrice(state.debtReserve.assetId);

    (, , params.healthFactor, , params.totalDebtInBaseCurrency) = spoke.getUserAccountData(alice);

    return LiquidationLogic.calculateDebtToRestoreCloseFactor(params);
  }

  /// @notice Calc max achievable hf to be able to repay all debt and have remaining collateral
  /// allows close factor to be up to max uint
  /// @return healthFactor in WAD
  function _calcMaxAchievableHfWithinColl(
    uint256 collateralReserveId,
    uint256 liquidationBonus
  ) internal view returns (uint256) {
    return
      _calcMaxAchievableHfFromCollateralFactor(
        spoke1.getCollateralFactor(collateralReserveId),
        liquidationBonus
      );
  }

  function _calcMaxAchievableHfFromCollateralFactor(
    uint256 collateralFactor,
    uint256 liquidationBonus
  ) internal view returns (uint256 healthFactor) {
    healthFactor = uint256(1e18).percentMul(collateralFactor).percentMul(liquidationBonus + 1);
  }

  function _convertAssetAmount(
    uint256 assetId,
    uint256 amount,
    uint256 toAssetId
  ) internal returns (uint256) {
    return _convertBaseCurrencyToAmount(toAssetId, _convertAmountToBaseCurrency(assetId, amount));
  }
}
