// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {LiquidationLogic} from 'src/libraries/logic/LiquidationLogic.sol';

contract SpokeLiquidationBase is SpokeBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  uint256 minSupplyInBaseCurrency = 10e26; // $10 in base currency
  uint256 remainingBaseCurrencyBound = 1e26; // $1 in base currency units

  struct Balance {
    uint256 balanceBefore;
    uint256 balanceAfter;
    uint256 balanceChange;
    uint256 baseChange;
  }

  struct LiquidationTestLocalParams {
    Balance liquidator;
    Balance user;
    Balance treasury;
    Balance collateral;
    Balance debt;
    Balance supply;
    uint256 liquidationBonus;
    uint256 collateralAssetId;
    uint256 debtAssetId;
    uint256 liquidationProtocolFeePercentage;
    DataTypes.Reserve collateralReserve;
    DataTypes.Reserve debtReserve;
    DataTypes.Reserve[] collateralReserves;
    DataTypes.Reserve[] debtReserves;
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
    uint256 requiredDebtAmount = _convertBaseCurrencyToAmount(assetId, requiredDebtInBase) + 1;

    vm.assume(requiredDebtAmount < MAX_SUPPLY_AMOUNT);

    // mock price to 0 to circumvent borrow validation
    vm.mockCall(
      address(oracle),
      abi.encodeWithSelector(IPriceOracle.getAssetPrice.selector, assetId),
      abi.encode(0)
    );
    vm.prank(user);
    spoke.borrow(reserveId, requiredDebtAmount, user);
    vm.clearMockedCalls();

    uint256 finalHf = spoke.getHealthFactor(user);
    console.log('final hf %e | desired hf %e', finalHf, desiredHf);
    assertLt(finalHf, desiredHf);
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

    requiredDebt =
      (
        (totalCollateralBase.percentMul(currentAvgCollateralFactor.dewadify() + 1))
          .wadMul(HEALTH_FACTOR_LIQUIDATION_THRESHOLD)
          .wadDiv(desiredHf)
      ) -
      totalDebtBase;
    // add rounding to num/denom to round debt up (ie making sure resultant HF is less than desired)
  }

  function _bound(
    DataTypes.LiquidationConfig memory liqConfig
  ) internal pure virtual returns (DataTypes.LiquidationConfig memory) {
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

  function _execLiqCallFuzzTest(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage
  ) internal returns (LiquidationTestLocalParams memory) {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 0.1e18); // enough buffer so that collateral to be liquidated is not dust
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);
    supplyAmount = bound(
      supplyAmount,
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e26),
      _convertBaseCurrencyToAmount(state.collateralReserve.assetId, 1e9 * 1e26)
    );

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

    console.log('   fuzz inputs');
    console.log('   collateralReserveId %e', collateralReserveId);
    console.log('   debtReserveId %e', debtReserveId);
    console.log('   supplyAmount %e', supplyAmount);
    console.log('   closeFactor %e', liqConfig.closeFactor);
    console.log('   healthFactorBonusThreshold %e', liqConfig.healthFactorBonusThreshold);
    console.log('   liquidationBonusFactor %e', liqConfig.liquidationBonusFactor);
    console.log('   liqBonus %e', liqBonus);
    console.log('   liquidationProtocolFeePercentage %e', liquidationProtocolFeePercentage);
    console.log('   desiredHf %e', desiredHf);

    _config = liqConfig;
    spoke1.updateLiquidationConfig(_config);
    updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
    updateLiquidationProtocolFeePercentage(
      spoke1,
      collateralReserveId,
      state.liquidationProtocolFeePercentage
    );

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: collateralReserveId,
      user: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });

    (uint256 hfAfterBorrow, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = _getVariableLiquidationBonus(
      spoke1,
      collateralReserveId,
      hfAfterBorrow
    );

    console.log('   state.liquidationBonus %e', state.liquidationBonus);

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.supply.balanceBefore = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    console.log(
      'before liq: debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.debtReserve.assetId,
        spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice)
      )
    );
    console.log(
      'before liq: collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.collateralReserve.assetId,
        spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice)
      )
    );

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    console.log(
      'after liq: debt amt remaining %e | base %e',
      spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.debtReserve.assetId,
        spoke1.getUserTotalDebt(state.debtReserve.reserveId, alice)
      )
    );
    console.log(
      'after liq: collateral amt remaining %e | base %e',
      spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice),
      _convertAmountToBaseCurrency(
        state.collateralReserve.assetId,
        spoke1.getUserSuppliedAmount(state.collateralReserve.reserveId, alice)
      )
    );

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.supply.balanceAfter = spoke1.getUserSuppliedAmount(collateralReserveId, alice);

    state.liquidator.balanceChange = _absDiff(
      state.liquidator.balanceAfter,
      state.liquidator.balanceBefore
    );
    state.supply.balanceChange = _absDiff(state.supply.balanceAfter, state.supply.balanceBefore);
    state.debt.balanceChange = _absDiff(state.debt.balanceAfter, state.debt.balanceBefore);

    // convert
    state.liquidator.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidator.balanceChange
    );
    state.supply.baseChange = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.supply.balanceChange
    );
    state.debt.baseChange = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      state.debt.balanceChange
    );

    return state;
  }

  function _assertAccounting(
    LiquidationTestLocalParams memory state,
    ISpoke spoke,
    uint256 remainingBaseCurrencyBound
  ) internal view {
    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      remainingBaseCurrencyBound &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      remainingBaseCurrencyBound
    ) {
      assertEq(
        state.supply.baseChange.percentDiv(state.debt.baseChange),
        state.liquidationBonus,
        'liquidationBonus'
      );
    }
  }

  function _getCloseFactor(ISpoke spoke) internal view returns (uint256) {
    return spoke.getLiquidationConfig().closeFactor;
  }

  function _percentDiff(uint256 a, uint256 b) internal pure returns (uint256) {
    return a != 0 ? (_absDiff(a, b) * PercentageMath.PERCENTAGE_FACTOR) / a : type(uint256).max;
  }

  function _absDiff(uint256 a, uint256 b) internal pure returns (uint256) {
    return a > b ? (a - b) : b - a;
  }

  function _assertHealthFactor(
    LiquidationTestLocalParams memory state,
    ISpoke spoke
  ) internal view virtual {
    uint256 finalHf = spoke.getHealthFactor(alice);

    console.log('hf %e cf %e', finalHf, _getCloseFactor(spoke));

    // ensure HF is lte close factor
    assertLe(finalHf, _getCloseFactor(spoke), 'Health factor <= close factor');
    // at low amounts of coll/debt, HF can diverge from close factor due to rounding/precision
    if (
      _convertAmountToBaseCurrency(state.debtReserve.assetId, state.debt.balanceAfter) >
      remainingBaseCurrencyBound &&
      _convertAmountToBaseCurrency(state.collateralReserve.assetId, state.supply.balanceAfter) >
      remainingBaseCurrencyBound
    ) {
      assertApproxEqRel(
        finalHf,
        _getCloseFactor(spoke),
        _approxRelFromBps(10),
        'HF matches closeFactor within 0.1%'
      );
    }
  }
}
