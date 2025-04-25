// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import 'tests/Base.t.sol';

contract LiquidationAvailableCollateralToLiquidateTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;
  using LiquidationLogic for DataTypes.LiquidationCallLocalVars;

  uint256 constant SKIP_NONE = 0;
  uint256 constant SKIP_DEBT_ASSET_PRICE = 1 << 0;
  uint256 constant SKIP_COLLATERAL_ASSET_UNIT = 1 << 1;
  uint256 constant SKIP_COLLATERAL_ASSET_PRICE = 1 << 2;
  uint256 constant SKIP_DEBT_ASSET_UNIT = 1 << 3;
  uint256 constant SKIP_LIQUIDATION_BONUS = 1 << 4;
  uint256 constant SKIP_USER_COLLATERAL_BALANCE = 1 << 5;
  uint256 constant SKIP_LPFP = 1 << 6;
  uint256 constant SKIP_ACTUAL_DEBT_TO_LIQUIDATE = 1 << 7;

  struct TestAvailableCollateralParams {
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 collateralAssetPrice;
    uint256 debtAssetUnit;
    uint256 liquidationBonus;
    uint256 userCollateralBalance;
    uint256 liquidationProtocolFeePercentage;
    uint256 actualDebtToLiquidate;
  }

  struct FieldsToSkip {
    uint256 flags;
  }

  struct AvailableCollateralToLiquidate {
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationProtocolFeeAmount;
  }

  function test_calculateAvailableCollateralToLiquidate_fuzz_debtAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    params = _bound(params, skip);
    params.debtAssetPrice = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    uint256 userCollateralBalanceinBaseCurrency = (params.userCollateralBalance *
      params.collateralAssetPrice).wadify() / params.collateralAssetUnit;

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

  function test_calculateAvailableCollateralToLiquidate_fuzz_actualDebtToLiquidate_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_NONE);
    params = _bound(params, skip);
    params.actualDebtToLiquidate = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    assertEq(res.actualCollateralToLiquidate, 1, 'actualCollateralToLiquidate');
    assertEq(res.actualDebtToLiquidate, 0, 'actualDebtToLiquidate');
    assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount');
  }

  /// should not happen in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_debtAssetUnit_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_DEBT_ASSET_UNIT);
    params = _bound(params, skip);

    params.debtAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateAvailableCollateralToLiquidate(args);
  }

  /// should not happen in practice
  function test_calculateAvailableCollateralToLiquidate_fuzz_collateralAssetUnit_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_COLLATERAL_ASSET_UNIT);
    params = _bound(params, skip);

    params.collateralAssetUnit = 0;
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    vm.expectRevert(stdError.divisionError);
    this.calculateAvailableCollateralToLiquidate(args);
  }

  function test_calculateAvailableCollateralToLiquidate_fuzz_collateralAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_COLLATERAL_ASSET_PRICE);
    params = _bound(params, skip);
    params.collateralAssetPrice = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

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

  function test_calculateAvailableCollateralToLiquidate_fuzz_userCollateralBalance_lt_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_NONE);
    params = _bound(params, skip);
    // prevent overflow
    vm.assume(params.userCollateralBalance * params.collateralAssetPrice < 1e59);
    vm.assume(params.actualDebtToLiquidate * params.debtAssetPrice < 1e59);

    uint256 maxCollateralToLiquidate = _calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidate < 1e59 / params.collateralAssetUnit);
    // so that maxCollateralToLiquidate <= userCollateralBalanceinBaseCurrency
    vm.assume(
      params.userCollateralBalance <=
        (maxCollateralToLiquidate * params.collateralAssetUnit).dewadify() /
          params.collateralAssetPrice
    );

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.actualCollateralToLiquidate,
      res.actualDebtToLiquidate,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    if (params.liquidationProtocolFeePercentage == 0) {
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
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_NONE);
    params = _bound(params, skip);
    // prevent overflow
    vm.assume(params.userCollateralBalance * params.collateralAssetPrice < 1e59);
    vm.assume(params.actualDebtToLiquidate * params.debtAssetPrice < 1e59);

    uint256 maxCollateralToLiquidate = _calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidate < 1e59 / params.collateralAssetUnit);
    // so that maxCollateralToLiquidate > userCollateralBalanceinBaseCurrency
    vm.assume(
      params.userCollateralBalance >
        (maxCollateralToLiquidate * params.collateralAssetUnit).dewadify() /
          params.collateralAssetPrice
    );

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // console.log('debtAssetPrice %e', args.debtAssetPrice);
    // console.log('debtAssetUnit %e', args.debtAssetUnit);
    // console.log('collateralAssetPrice %e', args.collateralAssetPrice);
    // console.log('collateralAssetUnit %e', args.collateralAssetUnit);
    // console.log('liquidationBonus %e', args.liquidationBonus);
    // console.log('userCollateralBalance %e', args.userCollateralBalance);
    // console.log('liquidationProtocolFeePercentage %e', args.liquidationProtocolFeePercentage);

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

    if (params.liquidationProtocolFeePercentage == 0) {
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

  function _isSkipped(FieldsToSkip memory skip, uint256 field) internal pure returns (bool) {
    return (skip.flags & field) != 0;
  }

  function _skipOnly(uint256 flags) internal pure returns (FieldsToSkip memory) {
    return FieldsToSkip({flags: flags});
  }

  function _setFunctionArgs(
    TestAvailableCollateralParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.debtAssetPrice = params.debtAssetPrice;
    result.actualDebtToLiquidate = params.actualDebtToLiquidate;
    result.collateralAssetUnit = params.collateralAssetUnit;
    result.collateralAssetPrice = params.collateralAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.liquidationBonus = params.liquidationBonus;
    result.userCollateralBalance = params.userCollateralBalance;
    result.liquidationProtocolFeePercentage = params.liquidationProtocolFeePercentage;
  }

  function _bound(
    TestAvailableCollateralParams memory params,
    FieldsToSkip memory skip
  ) internal pure returns (TestAvailableCollateralParams memory) {
    if (!_isSkipped(skip, SKIP_DEBT_ASSET_PRICE)) {
      params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    }

    if (!_isSkipped(skip, SKIP_COLLATERAL_ASSET_UNIT)) {
      params.collateralAssetUnit = bound(
        params.collateralAssetUnit,
        1,
        10 ** MAX_TOKEN_DECIMALS_SUPPORTED
      );
    }

    if (!_isSkipped(skip, SKIP_COLLATERAL_ASSET_PRICE)) {
      params.collateralAssetPrice = bound(params.collateralAssetPrice, 1, MAX_ASSET_PRICE);
    }

    if (!_isSkipped(skip, SKIP_DEBT_ASSET_UNIT)) {
      params.debtAssetUnit = bound(params.debtAssetUnit, 1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);
    }

    if (!_isSkipped(skip, SKIP_LIQUIDATION_BONUS)) {
      params.liquidationBonus = bound(
        params.liquidationBonus,
        MIN_LIQUIDATION_BONUS,
        MAX_LIQUIDATION_BONUS
      );
    }

    if (!_isSkipped(skip, SKIP_USER_COLLATERAL_BALANCE)) {
      params.userCollateralBalance = bound(params.userCollateralBalance, 1, MAX_SUPPLY_AMOUNT);
    }

    if (!_isSkipped(skip, SKIP_LPFP)) {
      params.liquidationProtocolFeePercentage = bound(
        params.liquidationProtocolFeePercentage,
        0,
        MAX_LIQUIDATION_PROTOCOL_FEE_PERCENTAGE
      );
    }

    if (!_isSkipped(skip, SKIP_ACTUAL_DEBT_TO_LIQUIDATE)) {
      params.actualDebtToLiquidate = bound(params.actualDebtToLiquidate, 1, MAX_SUPPLY_AMOUNT);
    }

    return params;
  }

  function _calcMaxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    return
      ((params.actualDebtToLiquidate * params.debtAssetPrice).wadify() / params.debtAssetUnit)
        .percentMul(params.liquidationBonus);
  }

  function _calcLiquidationProtocolFeeAmount(
    TestAvailableCollateralParams memory params,
    uint256 collateralAmount
  ) internal pure returns (uint256, uint256) {
    uint256 bonusCollateral = collateralAmount -
      collateralAmount.percentDiv(params.liquidationBonus);

    uint256 liquidationProtocolFeeAmount = bonusCollateral.percentMul(
      params.liquidationProtocolFeePercentage
    );

    return (collateralAmount - liquidationProtocolFeeAmount, liquidationProtocolFeeAmount);
  }

  function _calcDebtAmountNeeded(
    TestAvailableCollateralParams memory params
  ) internal pure returns (uint256) {
    uint256 userCollateralBalanceinBaseCurrency = (params.userCollateralBalance *
      params.collateralAssetPrice).wadify() / params.collateralAssetUnit;

    return
      ((params.debtAssetUnit * userCollateralBalanceinBaseCurrency.dewadify()) /
        (params.debtAssetPrice)).percentDiv(params.liquidationBonus);
  }

  // internal helper to trigger revert checks
  function calculateAvailableCollateralToLiquidate(
    DataTypes.LiquidationCallLocalVars memory params
  ) external pure {
    LiquidationLogic.calculateAvailableCollateralToLiquidate(params);
  }
}
