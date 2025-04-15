// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import 'tests/Base.t.sol';

contract LiquidationAvailableCollateralToLiquidateTest is Base {
  uint256 constant SKIP_NONE = 0;
  uint256 constant SKIP_DEBT_ASSET_PRICE = 1 << 0;
  uint256 constant SKIP_COLLATERAL_ASSET_UNIT = 1 << 1;
  uint256 constant SKIP_COLLATERAL_ASSET_PRICE = 1 << 2;
  uint256 constant SKIP_DEBT_ASSET_UNIT = 1 << 3;
  uint256 constant SKIP_LIQUIDATION_BONUS = 1 << 4;
  uint256 constant SKIP_USER_COLLATERAL_BALANCE = 1 << 5;
  uint256 constant SKIP_LPFP = 1 << 6;

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

  function testCalculateAvailableCollateralToLiquidate_collateralAssetPrice_zero(
    TestAvailableCollateralParams memory params
  ) public {
    FieldsToSkip memory skip = _skipOnly(SKIP_COLLATERAL_ASSET_PRICE);
    params = _bound(params, skip);
    params.collateralAssetPrice = 0;

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

  function testCalculateAvailableCollateralToLiquidate_debtAssetPrice_zero(
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

  function testCalculateAvailableCollateralToLiquidate_actualDebtToLiquidate_zero(
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

  function testCalculateAvailableCollateralToLiquidate_userCollateralBalance(
    TestAvailableCollateralParams memory params
  ) public {
    // FieldsToSkip memory skip = _skipOnly(SKIP_USER_COLLATERAL_BALANCE);
    // params = _bound(params, skip);
    // params.userCollateralBalance = bound(params.userCollateralBalance, 1, type(uint256).max);
    // DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);
    // AvailableCollateralToLiquidate memory res;
    // (
    //   res.collateralAmount,
    //   res.debtAmountNeeded,
    //   res.liquidationProtocolFeeAmount
    // ) = LiquidationLogic.calculateAvailableCollateralToLiquidate(args);
    // assertEq(res.collateralAmount, 0, 'collateralAmount');
    // assertEq(res.debtAmountNeeded, 0, 'debtAmountNeeded');
    // assertEq(res.liquidationProtocolFeeAmount, 0, 'liquidationProtocolFeeAmount');
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

    return params;
  }
}
