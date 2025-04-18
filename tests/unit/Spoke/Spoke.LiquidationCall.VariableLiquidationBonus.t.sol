// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function test_liquidationCall_variableLB1_unit1() public {
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

  function test_liquidationCall_variableLB1_unit2() public {
    test_liquidationCall_fuzz_variableLB1(
      DataTypes.LiquidationConfig({
        closeFactor: 1.03e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      105_00,
      10e18,
      0.95e18
    );
  }

  /// weth collateral / dai debt
  function test_liquidationCall_fuzz_variableLB1(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      0
    );

    _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB weth/dai');
  }

  function test_liquidationCall_variableLB2_unit1() public {
    test_liquidationCall_fuzz_variableLB2(
      DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.88e18,
        liquidationBonusFactor: 70_00
      }),
      107_00,
      1e18,
      0.93e18
    );
  }

  function test_liquidationCall_variableLB2_unit2() public {
    test_liquidationCall_fuzz_variableLB2(
      DataTypes.LiquidationConfig({
        closeFactor: 1.04e18,
        healthFactorBonusThreshold: 0.88e18,
        liquidationBonusFactor: 83_00
      }),
      107_00,
      1e18,
      0.93e18
    );
  }

  /// weth collateral / usdx debt
  function test_liquidationCall_fuzz_variableLB2(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e13, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      0
    );

    _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB weth/usdx');
  }

  /// usdx collateral / weth debt
  function test_liquidationCall_fuzz_variableLB3(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e7, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      0
    );

    _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB usdx/weth');
  }

  /// dai collateral / usdx debt
  function test_liquidationCall_fuzz_variableLB4(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e16, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      0
    );

    _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB dai/usdx');
  }

  // function _fuzz_liqCall(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf,
  //   uint256 collateralReserveId,
  //   uint256 debtReserveId,
  //   string memory label
  // ) internal {
  //   LiquidationTestLocalParams memory state;
  //   state.collateralReserve = spoke1.getReserve(collateralReserveId);
  //   state.debtReserve = spoke1.getReserve(debtReserveId);

  //   liqConfig = _bound(liqConfig);
  //   liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
  //   desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);

  //   _config = liqConfig;
  //   spoke1.updateLiquidationConfig(_config);

  //   updateLiquidationBonus(spoke1, collateralReserveId, liqBonus);
  //   Utils.supplyCollateral({
  //     spoke: spoke1,
  //     reserveId: collateralReserveId,
  //     user: alice,
  //     amount: supplyAmount,
  //     onBehalfOf: alice
  //   });

  //   (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
  //     spoke1,
  //     alice,
  //     debtReserveId,
  //     desiredHf
  //   );
  //   state.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

  //   state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);

  //   state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
  //   state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);

  //   vm.prank(LIQUIDATOR);
  //   spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

  //   state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
  //   state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);
  //   state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);

  //   // convert
  //   state.collateralBaseDiff = _convertAmountToBaseCurrency(
  //     state.collateralReserve.assetId,
  //     state.liquidator.balanceAfter - state.liquidator.balanceBefore
  //   );
  //   state.debtBaseDiff = _convertAmountToBaseCurrency(
  //     state.debtReserve.assetId,
  //     state.debt.balanceBefore - state.debt.balanceAfter
  //   );

  //   _assertLiquidationBonusEarned(state, label);
  // }

  function _assertLiquidationBonusEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal pure {
    assertApproxEqRel(
      state.collateralBaseDiff,
      state.debtBaseDiff.percentMul(state.liquidationBonus),
      _approxRelFromBps(10),
      string.concat('liquidationBonus earned in base currency ', label)
    );
  }
}
