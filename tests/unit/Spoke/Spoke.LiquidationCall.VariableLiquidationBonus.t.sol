// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.LiquidationConfig internal _config;

  // variable liquidation bonus tests

  function setUp() public virtual override {
    super.setUp();
    _addBorrowableLiquidity();

    _config = DataTypes.LiquidationConfig({
      closeFactor: 1e18,
      healthFactorBonusThreshold: 0.9e18,
      liquidationBonusFactor: 70_00 // 40%
    });
    spoke1.updateLiquidationConfig(_config);
  }

  /// @notice Deploys borrowable liquidity for all reserves in spoke1
  function _addBorrowableLiquidity() public {
    _deployLiquidity(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _deployLiquidity(spoke1, _usdyReserveId(spoke1), MAX_SUPPLY_AMOUNT);
  }

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
  }

  struct LiquidationBalances {
    Balance liquidator;
    Balance user;
    Balance treasury;
  }

  function test_required_debt() public {
    LiquidationBalances memory balances;

    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), 105_00);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: alice,
      amount: 10e18,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 debtAmount) = _borrowToBeBelowHf(spoke1, alice, daiAssetId, 0.95e18);
    uint256 liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      _wethReserveId(spoke1),
      finalHf
    );

    balances.liquidator.balanceBefore = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceBefore = tokenList.weth.balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(_wethReserveId(spoke1), _daiReserveId(spoke1), alice, debtAmount);

    balances.liquidator.balanceAfter = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceAfter = tokenList.weth.balanceOf(TREASURY);

    // collateral should be LB.percentMul(debt)

    uint256 diff = balances.liquidator.balanceAfter - balances.liquidator.balanceBefore;

    console.log(
      'dai amount %e %e',
      _convertBaseCurrencyToAmount(daiAssetId, _convertAmountToBaseCurrency(wethAssetId, diff))
    );

    // console.log(
    //   'liq diff %e',
    //   balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    // );
  }

  ///
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
    uint256 amount = _convertBaseCurrencyToAmount(assetId, requiredDebtInBase);

    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, amount, user);
    vm.clearMockedCalls();

    uint256 finalHf = spoke.getHealthFactor(user);

    assertLt(finalHf, desiredHf);
    // console.log('hf after %e', spoke1.getHealthFactor(alice));

    return (finalHf, amount);
  }

  /**
   * @notice Returns the required debt amount in base currency to reach a certain health factor
   */
  function _getRequiredDebtForLtHf(
    ISpoke spoke,
    address user,
    uint256 desiredHf
  ) internal view returns (uint256) {
    (
      ,
      uint256 currentAvgCollateralFactor,
      ,
      uint256 totalCollateralBase,
      uint256 totalDebtBase
    ) = spoke.getUserAccountData(user);
    return
      ((totalCollateralBase.percentMul(currentAvgCollateralFactor.dewadify() + 1) *
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD) / desiredHf) - totalDebtBase;
  }
}
