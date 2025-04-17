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

    // _config = DataTypes.LiquidationConfig({
    //   closeFactor: 1e18,
    //   healthFactorBonusThreshold: 0.9e18,
    //   liquidationBonusFactor: 70_00 // 40%
    // });
    // spoke1.updateLiquidationConfig(_config);
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
    Balance debt;
    uint256 collateralBaseDiff;
    uint256 debtBaseDiff;
    uint256 liquidationBonus;
  }

  function test_liquidationCall_fuzz_variableLB(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount
  ) public {
    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e6, MAX_SUPPLY_AMOUNT / 1e4);

    LiquidationBalances memory balances;

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);

    updateLiquidationBonus(spoke1, _wethReserveId(spoke1), liqBonus);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 debtAmount) = _borrowToBeBelowHf(spoke1, alice, daiAssetId, 0.95e18);
    balances.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      _wethReserveId(spoke1),
      finalHf
    );

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice);

    balances.liquidator.balanceBefore = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceBefore = tokenList.weth.balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(_wethReserveId(spoke1), _daiReserveId(spoke1), alice, debtAmount);

    balances.liquidator.balanceAfter = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceAfter = tokenList.weth.balanceOf(TREASURY);
    balances.debt.balanceAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice);

    // convert
    balances.collateralBaseDiff = _convertAmountToBaseCurrency(
      wethAssetId,
      balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    );
    balances.debtBaseDiff = _convertAmountToBaseCurrency(
      daiAssetId,
      balances.debt.balanceBefore - balances.debt.balanceAfter
    );

    _assertLiquidationBonusEarned(balances, 'test_liquidationCall_fuzz_variableLB');

    // collateral should be LB.percentMul(debt)

    // uint256 diff = _convertBaseCurrencyToAmount(
    //   daiAssetId,
    //   _convertAmountToBaseCurrency(
    //     wethAssetId,
    //     balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    //   )
    // );

    // console.log('dai amount %e %e', diff, (debtBefore - debtAfter).percentMul(liquidationBonus));
    // // console.log('debt diff %e', (debtBefore - debtAfter));

    // assertEq(diff.fromBps(), (debtBefore - debtAfter).percentMul(liquidationBonus).fromBps());

    // console.log(
    //   'liq diff %e',
    //   balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    // );
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure returns (DataTypes.LiquidationConfig memory) {
    liqConfig.closeFactor = bound(
      liqConfig.closeFactor,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
      MAX_CLOSE_FACTOR
    );
    liqConfig.healthFactorBonusThreshold = bound(
      liqConfig.healthFactorBonusThreshold,
      0.01e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  function _assertLiquidationBonusEarned(
    LiquidationBalances memory balances,
    string memory label
  ) internal {
    // console.log(
    //   'cmp %e %e',
    //   balances.collateralBaseDiff,
    //   balances.debtBaseDiff.percentMul(balances.liquidationBonus)
    // );

    assertApproxEqRel(
      balances.collateralBaseDiff,
      balances.debtBaseDiff.percentMul(balances.liquidationBonus),
      _approxRelFromBps(1),
      string.concat('liquidationBonus earned in base currency', label)
    );
  }

  function test_debt() public {
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

    uint256 debtBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice);

    balances.liquidator.balanceBefore = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceBefore = tokenList.weth.balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(_wethReserveId(spoke1), _daiReserveId(spoke1), alice, debtAmount);

    balances.liquidator.balanceAfter = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceAfter = tokenList.weth.balanceOf(TREASURY);

    // collateral should be LB.percentMul(debt)

    uint256 diff = _convertBaseCurrencyToAmount(
      daiAssetId,
      _convertAmountToBaseCurrency(
        wethAssetId,
        balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
      )
    );
    uint256 debtAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice);

    console.log('dai amount %e %e', diff, (debtBefore - debtAfter).percentMul(liquidationBonus));
    // console.log('debt diff %e', (debtBefore - debtAfter));

    assertEq(diff.fromBps(), (debtBefore - debtAfter).percentMul(liquidationBonus).fromBps());

    // console.log(
    //   'liq diff %e',
    //   balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    // );
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
   * @notice Returns the required debt amount in base currency to ensure user position is below a certain health factor.
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
