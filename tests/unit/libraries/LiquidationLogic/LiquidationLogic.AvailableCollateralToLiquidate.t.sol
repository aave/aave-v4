// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/libraries/LiquidationLogic/LiquidationLogic.Base.t.sol';

contract LiquidationAvailableCollateralToLiquidateTest is LiquidationLogicBaseTest {
  using WadRayMathExtended for uint256;
  using PercentageMathExtended for uint256;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  struct TestAvailableCollateralParams {
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 debtAssetUnit;
    uint256 liquidationBonus;
    uint256 userCollateralBalance;
    uint256 liquidationProtocolFee;
    uint256 actualDebtToLiquidate;
  }

  struct AvailableCollateralToLiquidate {
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
  }

  /// fuzz test where actualDebtToLiquidate = 0
  /// forces maxCollateralToLiquidate <= userCollateralBalanceInBaseCurrency
  function test_calculateAvailableCollateralToLiquidate_fuzz_actualDebtToLiquidate_zero(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = _bound(params);
    params.actualDebtToLiquidate = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    // actualCollateralToLiquidate is always >= 1
    assertEq(res.actualCollateralToLiquidate, 1, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, 0, 'actualDebtToLiquidate');
    assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount');
  }

  /// debtAssetUnit should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_debtAssetUnit_zero(
    TestAvailableCollateralParams memory params
  ) public {
    params = _bound(params);

    params.debtAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateAvailableCollateralToLiquidate(args);
  }

  /// debtAssetPrice should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_debtAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = _bound(params);
    params.debtAssetPrice = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    assertEq(res.actualCollateralToLiquidate, 1, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, params.actualDebtToLiquidate, 'actualDebtToLiquidate');
    assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount');
  }

  /// collateralAssetUnit should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_collateralAssetUnit_zero(
    TestAvailableCollateralParams memory params
  ) public {
    params = _bound(params);

    params.collateralAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateAvailableCollateralToLiquidate(args);
  }

  /// collateralAssetPrice should never be 0 in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_collateralAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = _bound(params);
    params.collateralAssetPrice = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    (uint256 collateralAmount, uint256 protocolLiquidationFee) = _calcLiquidationProtocolFeeAmount(
      params,
      params.userCollateralBalance
    );
    assertEq(res.actualCollateralToLiquidate, collateralAmount, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, 0, 'actualDebtToLiquidate');
    assertEq(
      res.liquidationProtocolFeeAmount,
      protocolLiquidationFee,
      'liquidationProtocolFeeAmount'
    );
  }

  /// fuzz test where userCollateralBalance < maxCollateralToLiquidate
  function test_calculateAvailableCollateralToLiquidate_fuzz_userCollateralBalance_lt_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = _bound(params);
    // bound to prevent overflow
    params.collateralAssetPrice = bound(
      params.collateralAssetPrice,
      1,
      1e59 / params.userCollateralBalance
    );
    params.actualDebtToLiquidate = bound(
      params.actualDebtToLiquidate,
      1,
      1e59 / params.debtAssetPrice
    );

    uint256 maxCollateralToLiquidate = _calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidate < 1e59 / params.collateralAssetUnit);
    // so that maxCollateralToLiquidate <= userCollateralBalanceInBaseCurrency
    vm.assume(
      params.userCollateralBalance <=
        (maxCollateralToLiquidate * params.collateralAssetUnit).dewadify() /
          params.collateralAssetPrice
    );

    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    if (params.liquidationProtocolFee == 0) {
      assertEq(
        res.actualCollateralToLiquidate,
        params.userCollateralBalance,
        'actualCollateralToLiquidate without lpfp'
      );
      assertEq(
        res.actualDebtToLiquidate,
        _calcDebtAmountNeeded(params),
        'actualDebtToLiquidate without lpfp'
      );
      assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount without lpfp');
    } else {
      (
        uint256 collateralAmount,
        uint256 liquidationProtocolFeeAmount
      ) = _calcLiquidationProtocolFeeAmount(params, params.userCollateralBalance);

      assertEq(res.actualCollateralToLiquidate, collateralAmount, 'actualCollateralToLiquidate');
      assertEq(res.actualDebtToLiquidate, _calcDebtAmountNeeded(params), 'actualDebtToLiquidate');
      assertEq(
        res.liquidationProtocolFeeAmount,
        liquidationProtocolFeeAmount,
        'liquidationProtocolFeeAmount'
      );
    }
  }

  function test_calculateAvailableCollateralToLiquidate_fuzz_userCollateralBalance_gte_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public pure {
    params = _bound(params);
    // prevent overflow
    vm.assume(params.userCollateralBalance * params.collateralAssetPrice < 1e59);
    vm.assume(params.actualDebtToLiquidate * params.debtAssetPrice < 1e59);

    uint256 maxCollateralToLiquidate = _calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidate < 1e59 / params.collateralAssetUnit);
    // so that maxCollateralToLiquidate > userCollateralBalanceInBaseCurrency
    vm.assume(
      params.userCollateralBalance >
        (maxCollateralToLiquidate * params.collateralAssetUnit).dewadify() /
          params.collateralAssetPrice
    );

    DataTypes.LiquidationCallLocalVars memory args = _setStructFields(params);
    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    uint256 collateralAmount = ((maxCollateralToLiquidate * params.collateralAssetUnit) /
      params.collateralAssetPrice).dewadify() + 1;

    (
      uint256 actualCollateralToLiquidate,
      uint256 liquidationProtocolFeeAmount
    ) = _calcLiquidationProtocolFeeAmount(params, collateralAmount);

    if (params.liquidationProtocolFee == 0) {
      assertApproxEqAbs(
        res.actualCollateralToLiquidate,
        actualCollateralToLiquidate,
        1,
        'collateralAmount without lpfp'
      );
      assertEq(
        res.actualDebtToLiquidate,
        params.actualDebtToLiquidate,
        'debtAmountNeeded without lpfp'
      );
      assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount without lpfp');
    } else {
      assertApproxEqAbs(
        res.actualCollateralToLiquidate,
        actualCollateralToLiquidate,
        1,
        'actualCollateralToLiquidate'
      );
      assertEq(res.actualDebtToLiquidate, params.actualDebtToLiquidate, 'actualDebtToLiquidate');
      assertEq(
        res.liquidationProtocolFeeAmount,
        liquidationProtocolFeeAmount,
        'liquidationProtocolFeeAmount'
      );
    }
  }

  function _setStructFields(
    TestAvailableCollateralParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.debtAssetPrice = params.debtAssetPrice;
    result.actualDebtToLiquidate = params.actualDebtToLiquidate;
    result.collateralAssetUnit = params.collateralAssetUnit;
    result.collateralAssetPrice = params.collateralAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.liquidationBonus = params.liquidationBonus;
    result.userCollateralBalance = params.userCollateralBalance;
    result.liquidationProtocolFee = params.liquidationProtocolFee;
  }

  function _bound(
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
    params.userCollateralBalance = bound(params.userCollateralBalance, 1, MAX_SUPPLY_AMOUNT);
    params.liquidationProtocolFee = bound(
      params.liquidationProtocolFee,
      0,
      MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE
    );
    params.actualDebtToLiquidate = bound(params.actualDebtToLiquidate, 1, MAX_SUPPLY_AMOUNT);

    return params;
  }

  function _calcMaxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    return
      ((params.actualDebtToLiquidate * params.debtAssetPrice).wadify() / params.debtAssetUnit)
        .percentMulDown(params.liquidationBonus);
  }

  function _calcLiquidationProtocolFeeAmount(
    TestAvailableCollateralParams memory params,
    uint256 collateralAmount
  ) internal pure returns (uint256, uint256) {
    uint256 bonusCollateral = collateralAmount -
      collateralAmount.percentDivUp(params.liquidationBonus);

    uint256 liquidationProtocolFeeAmount = bonusCollateral.percentMulUp(
      params.liquidationProtocolFee
    );

    return (collateralAmount - liquidationProtocolFeeAmount, liquidationProtocolFeeAmount);
  }

  /// calc amount of debt needed to cover the collateral
  /// needed when maxCollateralToLiquidate > userCollateralBalanceInBaseCurrency
  function _calcDebtAmountNeeded(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    uint256 userCollateralBalanceInBaseCurrency = (params.userCollateralBalance *
      params.collateralAssetPrice).wadify() / params.collateralAssetUnit;

    return
      ((params.debtAssetUnit * userCollateralBalanceInBaseCurrency) / params.debtAssetPrice)
        .percentDivDown(params.liquidationBonus)
        .dewadify();
  }

  // internal helper to trigger revert checks
  function calculateAvailableCollateralToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params
  ) external pure {
    LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }
}
