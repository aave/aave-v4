// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {stdError} from 'forge-std/StdError.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import 'tests/Base.t.sol';

contract LiquidationAvailableCollateralToLiquidateTest is Base {
  using PercentageMath for uint256;

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
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    uint256 liquidationProtocolFeeAmount;
  }

  // function test_calculateAvailableCollateralToLiquidate_fuzz_collateralAssetPrice_zero(
  //   TestAvailableCollateralParams memory params
  // ) public {
  //   FieldsToSkip memory skip = _skipOnly(SKIP_COLLATERAL_ASSET_PRICE);
  //   params = _bound(params, skip);
  //   params.collateralAssetPrice = 0;

  //   DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

  //   vm.expectRevert();
  //   LiquidationLogic.calculateAvailableCollateralToLiquidate(args);
  // }

  function test_calculateAvailableCollateralToLiquidate_fuzz_debtAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_DEBT_ASSET_PRICE);
    params = _bound(params, skip);
    params.debtAssetPrice = 0;

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    AvailableCollateralToLiquidate memory res;
    (
      res.collateralAmount,
      res.debtAmountNeeded,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    assertEq(res.collateralAmount, 0, 'collateralAmount');
    assertEq(res.debtAmountNeeded, params.actualDebtToLiquidate, 'debtAmountNeeded');
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
      res.collateralAmount,
      res.debtAmountNeeded,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    assertEq(res.collateralAmount, 0, 'collateralAmount');
    assertEq(res.debtAmountNeeded, 0, 'debtAmountNeeded');
    assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount');
  }

  function test_calculateAvailableCollateralToLiquidate_fuzz_userCollateralBalance_lt_maxCollateralToLiquidate(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_USER_COLLATERAL_BALANCE);
    params = _bound(params, skip);
    uint256 maxCollateralToLiquidate = _calcMaxCollateralToLiquidate(params);

    vm.assume(maxCollateralToLiquidate > 0);

    params.userCollateralBalance = bound(
      params.userCollateralBalance,
      0,
      maxCollateralToLiquidate - 1
    );

    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);
    AvailableCollateralToLiquidate memory res;
    (
      res.collateralAmount,
      res.debtAmountNeeded,
      res.liquidationProtocolFeeAmount
    ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);

    if (params.liquidationProtocolFeePercentage == 0) {
      assertEq(res.collateralAmount, params.userCollateralBalance, 'collateralAmount without lpfp');
      assertEq(
        res.debtAmountNeeded,
        _calcDebtAmountNeeded(params),
        'debtAmountNeeded without lpfp'
      );
      assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount without lpfp');
    } else {
      (
        uint256 collateralAmount,
        uint256 liquidationProtocolFeeAmount
      ) = _calcLiquidationProtocolFeeAmount(params, params.userCollateralBalance);

      assertEq(res.collateralAmount, collateralAmount, 'collateralAmount');
      assertEq(res.debtAmountNeeded, _calcDebtAmountNeeded(params), 'debtAmountNeeded');
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
  ) internal returns (DataTypes.LiquidationCallLocalVars memory result) {
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
  ) internal returns (TestAvailableCollateralParams memory) {
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
      params.userCollateralBalance = bound(params.userCollateralBalance, 1, type(uint256).max);
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
      ((params.debtAssetPrice * params.actualDebtToLiquidate * params.collateralAssetUnit) /
        (params.collateralAssetPrice * params.debtAssetUnit)).percentMul(params.liquidationBonus);
  }

  function _calcLiquidationProtocolFeeAmount(
    TestAvailableCollateralParams memory params,
    uint256 collateralAmount
  ) internal returns (uint256, uint256) {
    uint256 bonusCollateral = collateralAmount -
      collateralAmount.percentDiv(params.liquidationBonus);

    uint256 liquidationProtocolFeeAmount = bonusCollateral.percentMul(
      params.liquidationProtocolFeePercentage
    );

    return (collateralAmount - liquidationProtocolFeeAmount, liquidationProtocolFeeAmount);
  }

  function _calcDebtAmountNeeded(
    TestAvailableCollateralParams memory params
  ) internal returns (uint256) {
    return
      ((params.collateralAssetPrice * params.userCollateralBalance * params.debtAssetUnit) /
        (params.debtAssetPrice * params.collateralAssetUnit)).percentDiv(params.liquidationBonus);
  }

  // TODO: unit test with specific numbers and expected output
}
