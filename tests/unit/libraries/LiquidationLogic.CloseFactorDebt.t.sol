// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
// import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
// import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import 'tests/Base.t.sol';

contract LiquidationLogicCloseFactorDebtTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  // (debt * assetPrice).wadify() / assetUnit
  uint256 internal constant MAX_TOTAL_DEBT_IN_BASE_CURRENCY = 1e58;

  function testDebug() public {
    // testCalculateActualDebtToLiquidate_debtToCover_debtAssetUnitZero(
    //   11961,
    //   1,
    //   171795365432138209828527811341376943971965603010912721569924835186674,
    //   77432463920181804,
    //   1999999999999999999
    // );
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function testCalculateActualDebtToLiquidate_debtToCover_debtAssetUnitZero(
    uint256 liquidationBonus,
    uint256 collateralFactor,
    uint256 closeFactor,
    uint256 totalDebtInBaseCurrency,
    uint256 debtAssetPrice,
    uint256 avgCollateralFactor
  ) public {
    liquidationBonus = bound(liquidationBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    collateralFactor = bound(collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    avgCollateralFactor = bound(avgCollateralFactor, 1, MAX_COLLATERAL_FACTOR);
    totalDebtInBaseCurrency = bound(totalDebtInBaseCurrency, 1, MAX_TOTAL_DEBT_IN_BASE_CURRENCY);
    debtAssetPrice = bound(debtAssetPrice, 1, MAX_DEBT_ASSET_PRICE);
    closeFactor = bound(
      closeFactor,
      _calculateCloseFactorThreshold(liquidationBonus, collateralFactor),
      MAX_CLOSE_FACTOR
    );

    DataTypes.LiquidationCallLocalVars memory params;
    params.liquidationBonus = liquidationBonus;
    params.collateralFactor = collateralFactor;
    params.closeFactor = closeFactor;
    params.totalDebtInBaseCurrency = totalDebtInBaseCurrency;
    params.debtAssetPrice = debtAssetPrice;
    params.avgCollateralFactor = avgCollateralFactor;

    // units is 0
    params.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateCloseFactorDebt(params), 0, 'closeFactorDebt is 0');
  }

  function _calculateCloseFactorThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal returns (uint256) {
    return _calculateEffectiveLiquidationPenaltyThreshold(liquidationBonus, collateralFactor) + 1;
  }

  function _calculateEffectiveLiquidationPenaltyThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal returns (uint256) {
    return (liquidationBonus.wadify()).percentMul(collateralFactor).fromBps();
  }
}
