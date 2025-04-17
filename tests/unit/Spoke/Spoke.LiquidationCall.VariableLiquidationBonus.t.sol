// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

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
    uint256 collateralAssetId;
    uint256 debtAssetId;
    IERC20 collateralAsset;
    IERC20 debtAsset;
    DataTypes.Reserve collateralReserve;
    DataTypes.Reserve debtReserve;
  }

  function test_liquidationCall_variableLB() public {
    test_liquidationCall_fuzz_variableLB1(
      DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      105_00,
      10e18,
      0.95e18
    );
  }

  /// weth collateral / dai debt
  function test_liquidationCall_fuzz_variable_PREV(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

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

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      _daiReserveId(spoke1),
      desiredHf
    );
    balances.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      _wethReserveId(spoke1),
      finalHf
    );

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice);

    balances.liquidator.balanceBefore = tokenList.weth.balanceOf(LIQUIDATOR);
    balances.treasury.balanceBefore = tokenList.weth.balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      alice,
      requiredDebtAmount
    );

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

  function test_y() public {
    test_liquidationCall_fuzz_variableLB2(
      DataTypes.LiquidationConfig({
        closeFactor: 1000000000000006192,
        healthFactorBonusThreshold: 500000000000000250,
        liquidationBonusFactor: 5182
      }),
      19_900,
      4158717544,
      900000000000021205
    );
  }

  function test_liquidationCall_fuzz_variableLB1(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    LiquidationBalances memory balances;
    balances.collateralReserve = spoke1.getReserve(collateralReserveId);
    balances.debtReserve = spoke1.getReserve(debtReserveId);

    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

    // balances.collateralAssetId = spoke1.getReserve(collateralReserveId).assetId;
    // balances.debtAssetId = spoke1.getReserve(debtReserveId).assetId;
    // balances.collateralAsset = IERC20(balances.collateralReserve.asset);
    // balances.debtAsset = IERC20(balances.debtReserve.asset);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);

    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    balances.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

    balances.liquidator.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    balances.liquidator.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);
    balances.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);

    // convert
    balances.collateralBaseDiff = _convertAmountToBaseCurrency(
      balances.collateralReserve.assetId,
      balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    );
    balances.debtBaseDiff = _convertAmountToBaseCurrency(
      balances.debtReserve.assetId,
      balances.debt.balanceBefore - balances.debt.balanceAfter
    );

    _assertLiquidationBonusEarned(balances, 'test_liquidationCall_fuzz_variableLB');
  }

  function test_liquidationCall_fuzz_variableLB2(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    LiquidationBalances memory balances;
    balances.collateralReserve = spoke1.getReserve(collateralReserveId);
    balances.debtReserve = spoke1.getReserve(debtReserveId);

    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e13, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

    // balances.collateralAssetId = spoke1.getReserve(collateralReserveId).assetId;
    // balances.debtAssetId = spoke1.getReserve(debtReserveId).assetId;
    // balances.collateralAsset = IERC20(balances.collateralReserve.asset);
    // balances.debtAsset = IERC20(balances.debtReserve.asset);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);

    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    balances.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

    balances.liquidator.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    balances.liquidator.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);
    balances.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);

    // convert
    balances.collateralBaseDiff = _convertAmountToBaseCurrency(
      balances.collateralReserve.assetId,
      balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    );
    balances.debtBaseDiff = _convertAmountToBaseCurrency(
      balances.debtReserve.assetId,
      balances.debt.balanceBefore - balances.debt.balanceAfter
    );

    _assertLiquidationBonusEarned(balances, 'test_liquidationCall_fuzz_variableLB');
  }

  function test_liquidationCall_fuzz_variableLB3(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    LiquidationBalances memory balances;
    balances.collateralReserve = spoke1.getReserve(collateralReserveId);
    balances.debtReserve = spoke1.getReserve(debtReserveId);

    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e6, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

    // balances.collateralAssetId = spoke1.getReserve(collateralReserveId).assetId;
    // balances.debtAssetId = spoke1.getReserve(debtReserveId).assetId;
    // balances.collateralAsset = IERC20(balances.collateralReserve.asset);
    // balances.debtAsset = IERC20(balances.debtReserve.asset);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);

    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    balances.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

    balances.liquidator.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    balances.liquidator.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);
    balances.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);

    // convert
    balances.collateralBaseDiff = _convertAmountToBaseCurrency(
      balances.collateralReserve.assetId,
      balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    );
    balances.debtBaseDiff = _convertAmountToBaseCurrency(
      balances.debtReserve.assetId,
      balances.debt.balanceBefore - balances.debt.balanceAfter
    );

    _assertLiquidationBonusEarned(balances, 'test_liquidationCall_fuzz_variableLB');
  }

  function test_liquidationCall_fuzz_variableLB4(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    LiquidationBalances memory balances;
    balances.collateralReserve = spoke1.getReserve(collateralReserveId);
    balances.debtReserve = spoke1.getReserve(debtReserveId);

    // uint256 liqBonus = 105_00;
    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    supplyAmount = bound(supplyAmount, 1e16, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

    // balances.collateralAssetId = spoke1.getReserve(collateralReserveId).assetId;
    // balances.debtAssetId = spoke1.getReserve(debtReserveId).assetId;
    // balances.collateralAsset = IERC20(balances.collateralReserve.asset);
    // balances.debtAsset = IERC20(balances.debtReserve.asset);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);

    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    balances.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

    balances.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

    balances.liquidator.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceBefore = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    balances.liquidator.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(
      LIQUIDATOR
    );
    balances.treasury.balanceAfter = IERC20(balances.collateralReserve.asset).balanceOf(TREASURY);
    balances.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);

    // convert
    balances.collateralBaseDiff = _convertAmountToBaseCurrency(
      balances.collateralReserve.assetId,
      balances.liquidator.balanceAfter - balances.liquidator.balanceBefore
    );
    balances.debtBaseDiff = _convertAmountToBaseCurrency(
      balances.debtReserve.assetId,
      balances.debt.balanceBefore - balances.debt.balanceAfter
    );

    _assertLiquidationBonusEarned(balances, 'test_liquidationCall_fuzz_variableLB');
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
      0.5e18,
      HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1
    );
    liqConfig.liquidationBonusFactor = bound(liqConfig.liquidationBonusFactor, 0, 100_00);

    return liqConfig;
  }

  function _assertLiquidationBonusEarned(
    LiquidationBalances memory balances,
    string memory label
  ) internal {
    console.log(
      'cmp %e %e',
      balances.collateralBaseDiff,
      balances.debtBaseDiff.percentMul(balances.liquidationBonus)
    );

    assertApproxEqRel(
      balances.collateralBaseDiff,
      balances.debtBaseDiff.percentMul(balances.liquidationBonus),
      _approxRelFromBps(10),
      string.concat('liquidationBonus earned in base currency ', label)
    );
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
