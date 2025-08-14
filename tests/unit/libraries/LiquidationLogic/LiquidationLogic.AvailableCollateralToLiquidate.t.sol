// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationAvailableCollateralToLiquidateTest is LiquidationLogicBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  struct TestAvailableCollateralParams {
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 debtAssetUnit;
    uint256 liquidationBonus;
    uint256 borrowerCollateralBalance;
    uint256 liquidationFee;
    uint256 actualDebtToLiquidate;
    uint256 totalBorrowerReserveDebt;
  }

  struct TestAvailableCollateralToLiquidate {
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationFeeAmount;
  }

  /// fuzz test where actualDebtToLiquidate = 0
  /// forces maxCollateralToLiquidate < borrowerCollateralBalanceInBaseCurrency
  function test_calculateAvailableCollateralToLiquidate_fuzz_actualDebtToLiquidate_zero(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = bound(params);
    params.actualDebtToLiquidate = 0;
    params.totalBorrowerReserveDebt = bound(
      params.totalBorrowerReserveDebt,
      calculateMinLeftoverBaseAmount(params) + 1,
      MAX_SUPPLY_AMOUNT
    );

    DataTypes.LiquidationCallLocalVars memory args = setStructFields(params);

    TestAvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationFeeAmount,

    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    // actualCollateralToLiquidate is always >= 1
    assertEq(res.actualCollateralToLiquidate, 1, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, 0, 'actualDebtToLiquidate');
    assertEq(res.liquidationFeeAmount, 0, 'liquidationFeeAmount');
  }

  /// fuzz test where borrowerCollateralBalance < maxCollateralToLiquidate
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateAvailableCollateralToLiquidate_fuzz_borrowerCollateralBalance_lt_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public {
    params = bound(params);
    // bound to prevent overflow
    params.collateralAssetPrice = bound(
      params.collateralAssetPrice,
      1,
      1e59 / params.borrowerCollateralBalance
    );
    params.actualDebtToLiquidate = bound(
      params.actualDebtToLiquidate,
      1,
      1e59 / params.debtAssetPrice
    );

    uint256 maxCollateralToLiquidateInBaseCurrency = calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidateInBaseCurrency < 1e59 / params.collateralAssetUnit);
    // so that borrowerCollateralBalanceInBaseCurrency < maxCollateralToLiquidate
    vm.assume(
      params.borrowerCollateralBalance <
        _convertBaseCurrencyToAmount(
          maxCollateralToLiquidateInBaseCurrency,
          params.collateralAssetPrice,
          params.collateralAssetUnit
        )
    );
    // ensure leftover dust debt does not remain
    vm.assume(
      params.totalBorrowerReserveDebt >
        calcDebtAmountNeeded(params) + calculateMinLeftoverBaseAmount(params) ||
        params.totalBorrowerReserveDebt == calcDebtAmountNeeded(params)
    );

    uint256 leftoverDebtAmount = _convertAmountToBaseCurrency(
      params.totalBorrowerReserveDebt - calcDebtAmountNeeded(params),
      params.debtAssetPrice,
      params.debtAssetUnit
    );

    DataTypes.LiquidationCallLocalVars memory vars = setStructFields(params);

    TestAvailableCollateralToLiquidate memory res;

    if (leftoverDebtAmount < LiquidationLogic.MIN_LEFTOVER_BASE && leftoverDebtAmount != 0) {
      vm.expectRevert(LiquidationLogic.MustNotLeaveDust.selector);
      LiquidationLogic.calculateAvailableCollateralToLiquidate(vars);
    }
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationFeeAmount,

    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(vars);

    if (params.liquidationFee == 0) {
      assertEq(
        res.actualCollateralToLiquidate,
        params.borrowerCollateralBalance,
        'actualCollateralToLiquidate without liquidationFee'
      );
      assertEq(
        res.actualDebtToLiquidate,
        calcDebtAmountNeeded(params),
        'actualDebtToLiquidate without liquidationFee'
      );
      assertEq(res.liquidationFeeAmount, 0, 'liquidationFeeAmount without liquidationFee');
    } else {
      (uint256 collateralAmount, uint256 liquidationFeeAmount) = calcLiquidationFeeAmount(
        params,
        params.borrowerCollateralBalance
      );

      assertEq(res.actualCollateralToLiquidate, collateralAmount, 'actualCollateralToLiquidate');
      assertEq(res.actualDebtToLiquidate, calcDebtAmountNeeded(params), 'actualDebtToLiquidate');
      assertEq(res.liquidationFeeAmount, liquidationFeeAmount, 'liquidationFeeAmount');
    }
  }

  /// fuzz test where borrowerCollateralBalance >= maxCollateralToLiquidate
  function test_calculateAvailableCollateralToLiquidate_fuzz_borrowerCollateralBalance_gte_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = bound(params);
    // prevent overflow
    vm.assume(params.borrowerCollateralBalance * params.collateralAssetPrice < 1e59);
    vm.assume(params.actualDebtToLiquidate * params.debtAssetPrice < 1e59);

    uint256 maxCollateralToLiquidate = calcMaxCollateralToLiquidate(params);
    vm.assume(maxCollateralToLiquidate < 1e59 / params.collateralAssetUnit);
    // so that maxCollateralToLiquidate > borrowerCollateralBalanceInBaseCurrency
    vm.assume(
      params.borrowerCollateralBalance >
        (maxCollateralToLiquidate * params.collateralAssetUnit).fromWadDown() /
          params.collateralAssetPrice
    );
    vm.assume(
      params.totalBorrowerReserveDebt >
        params.actualDebtToLiquidate + calculateMinLeftoverBaseAmount(params)
    );

    DataTypes.LiquidationCallLocalVars memory vars = setStructFields(params);

    TestAvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationFeeAmount,

    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(vars);

    uint256 collateralAmount = ((maxCollateralToLiquidate * params.collateralAssetUnit) /
      params.collateralAssetPrice).fromWadDown() + 1;
    (uint256 actualCollateralToLiquidate, uint256 liquidationFeeAmount) = calcLiquidationFeeAmount(
      params,
      collateralAmount
    );

    if (params.liquidationFee == 0) {
      assertEq(
        res.actualCollateralToLiquidate,
        actualCollateralToLiquidate,
        'collateralAmount without liquidationFee'
      );
      assertEq(
        res.actualDebtToLiquidate,
        params.actualDebtToLiquidate,
        'debtAmountNeeded without liquidationFee'
      );
      assertEq(res.liquidationFeeAmount, 0, 'liquidationFeeAmount without liquidationFee');
    } else {
      assertEq(
        res.actualCollateralToLiquidate,
        actualCollateralToLiquidate,
        'actualCollateralToLiquidate'
      );
      assertEq(res.actualDebtToLiquidate, params.actualDebtToLiquidate, 'actualDebtToLiquidate');
      assertEq(res.liquidationFeeAmount, liquidationFeeAmount, 'liquidationFeeAmount');
    }
  }

  /// debtAssetUnit should never be 0 in practice
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateAvailableCollateralToLiquidate_debtAssetUnit_zero() public {
    TestAvailableCollateralParams memory params = randomizedParams();
    params.debtAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = setStructFields(params);

    vm.expectRevert(stdError.divisionError);
    LiquidationLogic.calculateAvailableCollateralToLiquidate(args);
  }

  /// debtAssetPrice should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_debtAssetPrice_zero() public {
    TestAvailableCollateralParams memory params = randomizedParams();
    params.debtAssetPrice = 0;
    DataTypes.LiquidationCallLocalVars memory args = setStructFields(params);

    TestAvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationFeeAmount,

    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    assertEq(res.actualCollateralToLiquidate, 1, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, params.actualDebtToLiquidate, 'actualDebtToLiquidate');
    assertEq(res.liquidationFeeAmount, 0, 'liquidationFeeAmount');
  }

  /// collateralAssetUnit should never be 0 in practice
  /// forge-config: default.allow_internal_expect_revert = true
  function test_calculateAvailableCollateralToLiquidate_collateralAssetUnit_zero() public {
    TestAvailableCollateralParams memory params = randomizedParams();
    params.collateralAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = setStructFields(params);

    vm.expectRevert(stdError.divisionError);
    LiquidationLogic.calculateAvailableCollateralToLiquidate(args);
  }

  /// collateralAssetPrice should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_collateralAssetPrice_zero() public {
    TestAvailableCollateralParams memory params = randomizedParams();
    params.collateralAssetPrice = 0;
    DataTypes.LiquidationCallLocalVars memory args = setStructFields(params);

    TestAvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationFeeAmount,

    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    (uint256 collateralAmount, uint256 protocolLiquidationFee) = calcLiquidationFeeAmount(
      params,
      params.borrowerCollateralBalance
    );
    assertEq(res.actualCollateralToLiquidate, collateralAmount, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, 0, 'actualDebtToLiquidate');
    assertEq(res.liquidationFeeAmount, protocolLiquidationFee, 'liquidationFeeAmount');
  }

  function calculateMinLeftoverBaseAmount(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    return
      _convertBaseCurrencyToAmount(
        LiquidationLogic.MIN_LEFTOVER_BASE,
        params.debtAssetPrice,
        params.debtAssetUnit
      );
  }
  function setStructFields(
    TestAvailableCollateralParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.debtAssetPrice = params.debtAssetPrice;
    result.actualDebtToLiquidate = params.actualDebtToLiquidate;
    result.collateralAssetUnit = params.collateralAssetUnit;
    result.collateralAssetPrice = params.collateralAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.liquidationBonus = params.liquidationBonus;
    result.borrowerCollateralBalance = params.borrowerCollateralBalance;
    result.liquidationFee = params.liquidationFee;
    result.totalBorrowerReserveDebt = params.totalBorrowerReserveDebt;
  }

  function bound(
    TestAvailableCollateralParams memory params
  ) internal pure returns (TestAvailableCollateralParams memory) {
    params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    params.collateralAssetUnit = bound(
      params.collateralAssetUnit,
      1,
      10 ** MAX_TOKEN_DECIMALS_SUPPORTED
    );
    params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    params.debtAssetUnit = bound(params.debtAssetUnit, 1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    params.borrowerCollateralBalance = bound(
      params.borrowerCollateralBalance,
      1,
      MAX_SUPPLY_AMOUNT
    );
    params.liquidationFee = bound(
      params.liquidationFee,
      0,
      MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE
    );
    params.actualDebtToLiquidate = bound(params.actualDebtToLiquidate, 1, MAX_SUPPLY_AMOUNT);

    params.totalBorrowerReserveDebt = bound(
      params.totalBorrowerReserveDebt,
      calculateMinLeftoverBaseAmount(params),
      MAX_SUPPLY_AMOUNT
    );

    return params;
  }

  /// @return maxCollateralToLiquidate in base currency
  function calcMaxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    return
      _convertAmountToBaseCurrency(
        params.actualDebtToLiquidate,
        params.debtAssetPrice,
        params.debtAssetUnit
      ).percentMulDown(params.liquidationBonus);
  }

  function calcLiquidationFeeAmount(
    TestAvailableCollateralParams memory params,
    uint256 collateralAmount
  ) internal pure returns (uint256, uint256) {
    uint256 bonusCollateral = collateralAmount -
      collateralAmount.percentDivUp(params.liquidationBonus);

    uint256 liquidationFeeAmount = bonusCollateral.percentMulUp(params.liquidationFee);

    return (collateralAmount - liquidationFeeAmount, liquidationFeeAmount);
  }

  /// calc amount of debt needed to cover the collateral
  /// needed when maxCollateralToLiquidate > borrowerCollateralBalanceInBaseCurrency
  function calcDebtAmountNeeded(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    uint256 borrowerCollateralBalanceInBaseCurrency = (params.borrowerCollateralBalance *
      params.collateralAssetPrice).toWad() / params.collateralAssetUnit;

    return
      ((params.debtAssetUnit * borrowerCollateralBalanceInBaseCurrency) / params.debtAssetPrice)
        .percentDivDown(params.liquidationBonus)
        .fromWadDown();
  }

  function randomizedParams() internal returns (TestAvailableCollateralParams memory params) {
    params.debtAssetUnit = vm.randomUint(1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    params.debtAssetPrice = vm.randomUint(1, MAX_ASSET_PRICE);
    params.collateralAssetUnit = vm.randomUint(1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    params.collateralAssetPrice = vm.randomUint(1, MAX_ASSET_PRICE);
    params.borrowerCollateralBalance = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    params.liquidationBonus = vm.randomUint(MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    params.liquidationFee = vm.randomUint(0, MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE);
    params.actualDebtToLiquidate = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    params.totalBorrowerReserveDebt = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
  }
}
