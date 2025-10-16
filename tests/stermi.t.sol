// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {console} from 'forge-std/console.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ISpokeBase, ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract _RecalcLiquidV3vsV4Test is Test {
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for *;
  using MathUtils for uint256;

  struct LiquidationParams {
    uint256 liquidationBonus;
    uint256 liquidationFee;
    uint256 debtToLiquidate;
    uint256 borrowerCollateralBalance;
    uint256 collateralAssetPrice;
    uint256 debtAssetPrice;
    uint256 collateralAssetUnit;
    uint256 debtAssetUnit;
  }

  struct LiquidationReturnV3 {
    uint256 collateralToLiquidator;
    uint256 debtToLiquidate;
    uint256 protocolFee;
    bool notEnoughCollateral;
  }

  struct LiquidationReturnV4 {
    uint256 collateralToLiquidate;
    uint256 collateralToLiquidator;
    uint256 debtToLiquidate;
    bool notEnoughCollateral;
    uint256 protocolFee;
  }

  /// forge-config: default.fuzz.max-test-rejects = 10_065_536
  function testV3vsV4LiqRecalcFuzz(
    uint256 liquidationBonus,
    uint256 liquidationFee,
    uint256 debtToLiquidate,
    uint256 borrowerCollateralBalance,
    uint256 collateralAssetPrice,
    uint256 debtAssetPrice,
    uint256 debtDecimal,
    uint256 collateralDecimal
  ) public {
    debtDecimal = bound(debtDecimal, 6, 18);
    collateralDecimal = bound(collateralDecimal, 6, 18);

    uint256 collateralAssetUnit = 10 ** collateralDecimal;
    uint256 debtAssetUnit = 10 ** debtDecimal;

    liquidationBonus = bound(liquidationBonus, 1e4, 120_00);
    liquidationFee = bound(liquidationFee, 0, 20_00);
    debtToLiquidate = bound(debtToLiquidate, 1, 100_000_000 * debtAssetUnit);
    borrowerCollateralBalance = bound(
      borrowerCollateralBalance,
      1,
      100_000_000 * collateralAssetUnit
    );

    collateralAssetPrice = bound(collateralAssetPrice, 0.1e8, 10_000e8);
    debtAssetPrice = bound(debtAssetPrice, 0.1e8, 10_000e8);

    LiquidationParams memory f1 = LiquidationParams(
      liquidationBonus,
      liquidationFee,
      debtToLiquidate,
      borrowerCollateralBalance,
      collateralAssetPrice,
      debtAssetPrice,
      collateralAssetUnit,
      debtAssetUnit
    );

    vm.assume(
      v3_collateralToLiquidateGreaterThanBalance(f1) &&
        v4_collateralToLiquidateGreaterThanBalance(f1)
    );

    LiquidationReturnV3 memory v3Return;
    LiquidationReturnV4 memory v4v1Return;
    LiquidationReturnV4 memory v4v2Return;

    // Aave v3
    (
      v3Return.collateralToLiquidator,
      v3Return.debtToLiquidate,
      v3Return.protocolFee,
      v3Return.notEnoughCollateral
    ) = v3(f1);

    // Aave v4 v2: percentDivUp(f.liquidationBonus) applied at last stage
    (
      v4v2Return.collateralToLiquidate,
      v4v2Return.collateralToLiquidator,
      v4v2Return.debtToLiquidate,
      v4v2Return.notEnoughCollateral
    ) = v4v2(f1);
    v4v2Return.protocolFee = v4v2Return.collateralToLiquidate - v4v2Return.collateralToLiquidator;

    // Aave v4 v1: percentDivUp(f.liquidationBonus) applied first (truncate early)
    (
      v4v1Return.collateralToLiquidate,
      v4v1Return.collateralToLiquidator,
      v4v1Return.debtToLiquidate,
      v4v1Return.notEnoughCollateral
    ) = v4(f1);
    v4v1Return.protocolFee = v4v1Return.collateralToLiquidate - v4v1Return.collateralToLiquidator;

    if (v4v2Return.debtToLiquidate >= v4v1Return.debtToLiquidate) {
      // asssert that the delta is at most 1
      assertApproxEqAbs(v4v1Return.debtToLiquidate, v4v2Return.debtToLiquidate, 1);
    } else {
      assertApproxEqAbs(v4v1Return.debtToLiquidate, v4v2Return.debtToLiquidate, 97098036108421119);
    }

    assertApproxEqAbs(v3Return.debtToLiquidate, v4v2Return.debtToLiquidate, 1);
  }

  function v4_collateralToLiquidateGreaterThanBalance(
    LiquidationParams memory f
  ) public returns (bool) {
    uint256 debtToCollateral = f.debtToLiquidate.mulDivDown(
      f.debtAssetPrice * f.collateralAssetUnit,
      f.debtAssetUnit * f.collateralAssetPrice
    );
    uint256 collateralToLiquidate = debtToCollateral.percentMulDown(f.liquidationBonus);
    return collateralToLiquidate > f.borrowerCollateralBalance;
  }

  function v3_collateralToLiquidateGreaterThanBalance(
    LiquidationParams memory f
  ) public returns (bool) {
    uint256 baseCollateral = (f.debtAssetPrice * f.debtToLiquidate * f.collateralAssetUnit) /
      (f.collateralAssetPrice * f.debtAssetUnit);

    uint256 maxCollateralToLiquidate = percentMul(baseCollateral, f.liquidationBonus);

    return maxCollateralToLiquidate > f.borrowerCollateralBalance;
  }

  function v4(LiquidationParams memory f) public returns (uint256, uint256, uint256, bool) {
    bool notEnoughCollateral = false;
    uint256 debtToLiquidate = f.debtToLiquidate;
    uint256 debtToCollateral = f.debtToLiquidate.mulDivDown(
      f.debtAssetPrice * f.collateralAssetUnit,
      f.debtAssetUnit * f.collateralAssetPrice
    );
    uint256 collateralToLiquidate = debtToCollateral.percentMulDown(f.liquidationBonus);
    if (collateralToLiquidate > f.borrowerCollateralBalance) {
      collateralToLiquidate = f.borrowerCollateralBalance;
      debtToCollateral = collateralToLiquidate.percentDivUp(f.liquidationBonus);
      debtToLiquidate = debtToCollateral.mulDivUp(
        f.collateralAssetPrice * f.debtAssetUnit,
        f.debtAssetPrice * f.collateralAssetUnit
      );
      notEnoughCollateral = true;
    }

    uint256 collateralToLiquidator = collateralToLiquidate -
      (collateralToLiquidate - debtToCollateral).percentMulDown(f.liquidationFee);

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate, notEnoughCollateral);
  }

  function v4v2(LiquidationParams memory f) public returns (uint256, uint256, uint256, bool) {
    bool notEnoughCollateral = false;
    uint256 debtToLiquidate = f.debtToLiquidate;
    uint256 debtToCollateral = f.debtToLiquidate.mulDivDown(
      f.debtAssetPrice * f.collateralAssetUnit,
      f.debtAssetUnit * f.collateralAssetPrice
    );
    uint256 collateralToLiquidate = debtToCollateral.percentMulDown(f.liquidationBonus);
    if (collateralToLiquidate > f.borrowerCollateralBalance) {
      collateralToLiquidate = f.borrowerCollateralBalance;
      debtToCollateral = collateralToLiquidate.percentDivUp(f.liquidationBonus);
      debtToLiquidate = collateralToLiquidate
        .mulDivUp(
          f.collateralAssetPrice * f.debtAssetUnit,
          f.debtAssetPrice * f.collateralAssetUnit
        )
        .percentDivUp(f.liquidationBonus);
      notEnoughCollateral = true;
    }

    uint256 collateralToLiquidator = collateralToLiquidate -
      (collateralToLiquidate - debtToCollateral).percentMulDown(f.liquidationFee);

    return (collateralToLiquidate, collateralToLiquidator, debtToLiquidate, notEnoughCollateral);
  }

  function v3(LiquidationParams memory f) public returns (uint256, uint256, uint256, bool) {
    bool notEnoughCollateral = false;
    uint256 liquidationProtocolFee = 0;
    uint256 bonusCollateral = 0;
    uint256 collateralAmount = 0;
    uint256 debtAmountNeeded = 0;
    uint256 baseCollateral = (f.debtAssetPrice * f.debtToLiquidate * f.collateralAssetUnit) /
      (f.collateralAssetPrice * f.debtAssetUnit);

    uint256 maxCollateralToLiquidate = percentMul(baseCollateral, f.liquidationBonus);

    if (maxCollateralToLiquidate > f.borrowerCollateralBalance) {
      collateralAmount = f.borrowerCollateralBalance;
      debtAmountNeeded = percentDivCeil(
        (f.collateralAssetPrice * collateralAmount * f.debtAssetUnit) /
          (f.debtAssetPrice * f.collateralAssetUnit),
        f.liquidationBonus
      );
      notEnoughCollateral = true;
    } else {
      collateralAmount = maxCollateralToLiquidate;
      debtAmountNeeded = f.debtToLiquidate;
    }

    if (f.liquidationFee != 0) {
      bonusCollateral = collateralAmount - percentDiv(collateralAmount, f.liquidationBonus);

      liquidationProtocolFee = percentMul(bonusCollateral, f.liquidationFee);
      collateralAmount -= liquidationProtocolFee;
    }
    return (collateralAmount, debtAmountNeeded, liquidationProtocolFee, notEnoughCollateral);
  }

  //////////////////////////////////////////////////////
  // Aave v3 Math utils
  //////////////////////////////////////////////////////
  function percentDivCeil(
    uint256 value,
    uint256 percentage
  ) internal pure returns (uint256 result) {
    // to avoid overflow, value <= type(uint256).max / PERCENTAGE_FACTOR
    uint256 PERCENTAGE_FACTOR = 1e4;
    assembly ('memory-safe') {
      if or(iszero(percentage), iszero(iszero(gt(value, div(not(0), PERCENTAGE_FACTOR))))) {
        revert(0, 0)
      }
      let val := mul(value, PERCENTAGE_FACTOR)
      result := add(div(val, percentage), iszero(iszero(mod(val, percentage))))
    }
  }

  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
    uint256 PERCENTAGE_FACTOR = 1e4;
    uint256 HALF_PERCENTAGE_FACTOR = 0.5e4;
    assembly ('memory-safe') {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    uint256 PERCENTAGE_FACTOR = 1e4;
    // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
    assembly ('memory-safe') {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }
}
