// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';
import 'tests/Base.t.sol';

contract LiquidationLogicBaseTest is Base {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  uint256 internal daiUnits;
  uint256 internal usdxUnits;
  uint256 internal wethUnits;
  uint256 internal wbtcUnits;

  struct TestDebtToRestoreCloseFactorParams {
    uint256 liquidationBonus;
    uint256 collateralFactor;
    uint256 closeFactor;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 healthFactor;
    uint256 totalDebt;
  }

  function _setTokenDecimals() internal {
    daiUnits = 10 ** tokenList.dai.decimals();
    usdxUnits = 10 ** tokenList.usdx.decimals();
    wethUnits = 10 ** tokenList.weth.decimals();
    wbtcUnits = 10 ** tokenList.wbtc.decimals();
  }

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
    _setTokenDecimals();
  }

  // calculate threshold when close factor > effectiveLiquidationPenalty so that calculateDebtToRestoreCloseFactor denom is > 0
  function _calculateCloseFactorThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return _calculateEffectiveLiquidationPenaltyThreshold(liquidationBonus, collateralFactor);
  }

  function _calculateEffectiveLiquidationPenaltyThreshold(
    uint256 liquidationBonus,
    uint256 collateralFactor
  ) internal pure returns (uint256) {
    return (liquidationBonus.toWad()).percentMulDown(collateralFactor - 1).fromBpsDown();
  }

  function _setStructFields(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal pure returns (DataTypes.LiquidationCallLocalVars memory result) {
    result.liquidationBonus = params.liquidationBonus;
    result.collateralFactor = params.collateralFactor;
    result.closeFactor = params.closeFactor;
    result.totalDebtInBaseCurrency = params.totalDebtInBaseCurrency;
    result.debtAssetPrice = params.debtAssetPrice;
    result.debtAssetUnit = params.debtAssetUnit;
    result.healthFactor = params.healthFactor;
  }

  function _bound(
    TestDebtToRestoreCloseFactorParams memory params
  ) internal virtual returns (TestDebtToRestoreCloseFactorParams memory) {
    params.liquidationBonus = bound(
      params.liquidationBonus,
      MIN_LIQUIDATION_BONUS,
      MAX_LIQUIDATION_BONUS
    );
    params.collateralFactor = bound(params.collateralFactor, 1, MAX_COLLATERAL_FACTOR);
    params.totalDebtInBaseCurrency = bound(
      params.totalDebtInBaseCurrency,
      1,
      MAX_SUPPLY_IN_BASE_CURRENCY
    );
    params.debtAssetPrice = bound(params.debtAssetPrice, 1, MAX_ASSET_PRICE);
    params.closeFactor = bound(
      params.closeFactor,
      _calculateCloseFactorThreshold(params.liquidationBonus, params.collateralFactor),
      MAX_CLOSE_FACTOR
    );
    params.healthFactor = bound(params.healthFactor, 0, params.closeFactor);
    params.debtAssetUnit = bound(params.debtAssetUnit, 1, 10 ** MAX_TOKEN_DECIMALS_SUPPORTED);

    return params;
  }
}
