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

  struct TestCloseFactorDebtParams {
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 avgCollateralFactor;
    uint256 debtAssetUnit;
  }

  function _bound(
    TestCloseFactorDebtParams memory params
  ) internal returns (TestCloseFactorDebtParams memory) {
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    params.collateralFactor = bound(params.collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    params.avgCollateralFactor = bound(params.avgCollateralFactor, 1, MAX_COLLATERAL_FACTOR);
    params.totalDebtInBaseCurrency = bound(
      params.totalDebtInBaseCurrency,
      1,
      MAX_TOTAL_DEBT_IN_BASE_CURRENCY
    );
    params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_DEBT_ASSET_PRICE);
    params.closeFactor = bound(
      params.closeFactor,
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
      MAX_CLOSE_FACTOR
    );

    return params;
  }

  function _setFunctionArgs(
    TestCloseFactorDebtParams memory params
  ) internal returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.liquidationBonus = params.liquidationBonus;
    result.collateralFactor = params.collateralFactor;
    result.closeFactor = params.closeFactor;
    result.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;
    result.debtAssetPrice = params.debtAssetPrice;
    result.avgCollateralFactor = params.avgCollateralFactor;
    result.debtAssetUnit = params.debtAssetUnit;
  }

  /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  function testCalculateActualDebtToLiquidate_debtAssetUnit_zero(
    TestCloseFactorDebtParams memory params
  ) public {
    params = _bound(params);
    DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

    // units is 0
    args.debtAssetUnit = 0;

    assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 0, 'closeFactorDebt is 0');
  }

  // /// if debtAssetUnit == 0, then result is 0 (should not happen in practice as unit is 10**decimals)
  // function testCalculateActualDebtToLiquidate_avgCollateralFactor_zero(
  //   TestCloseFactorDebtParams memory params
  // ) public {
  //   params = _bound(params, FieldsToSkip.AvgCollateralFactor);
  //   DataTypes.LiquidationCallLocalVars memory args = _setFunctionArgs(params);

  //   args.avgCollateralFactor = 0;

  //   assertEq(LiquidationLogic.calculateCloseFactorDebt(args), 0, 'closeFactorDebt is 0');
  // }

  // for close factor > effectiveLiquidationPenalty, and positive denominator in calc
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
