// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
  }

  struct LiquidationTestLocalParams {
    Balance liquidator;
    Balance user;
    Balance treasury;
    Balance debt;
    uint256 collateralBaseDiff;
    uint256 debtBaseDiff;
    uint256 liquidationBonus;
    uint256 collateralAssetId;
    uint256 debtAssetId;
    DataTypes.Reserve collateralReserve;
    DataTypes.Reserve debtReserve;
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
    uint256 requiredDebtAmount = _convertBaseCurrencyToAmount(assetId, requiredDebtInBase);

    console.log('requiredDebtAmount %e', requiredDebtAmount);

    vm.assume(requiredDebtAmount > 0 && requiredDebtAmount < MAX_SUPPLY_AMOUNT);

    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, requiredDebtAmount, user);
    vm.clearMockedCalls();

    uint256 finalHf = spoke.getHealthFactor(user);

    assertLt(finalHf, desiredHf);
    console.log('final hf %e, desired hf %e', finalHf, desiredHf);

    return (finalHf, requiredDebtAmount);
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

    // console.log(
    //   'original %e, calc %e',
    //   ((totalCollateralBase.percentMul(currentAvgCollateralFactor.dewadify() + 1) *
    //     HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / desiredHf),
    //   (
    //     totalCollateralBase.wadMul(currentAvgCollateralFactor + 1).wadMul(
    //       HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    //     )
    //   ).wadDiv(desiredHf).fromBps()
    // );
    // 1.684421052631578947368421052631e30
    // 1.6842105263157894736844210526315789e34

    requiredDebt =
      ((totalCollateralBase.percentMulUp(currentAvgCollateralFactor.dewadify() + 1) *
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / desiredHf) -
      totalDebtBase +
      1;
    // requiredDebt =
    //   (
    //     totalCollateralBase.wadMul(currentAvgCollateralFactor + 1).wadMul(
    //       HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    //     )
    //   ).wadDiv(desiredHf).fromBps() -
    //   totalDebtBase;
  }
}
