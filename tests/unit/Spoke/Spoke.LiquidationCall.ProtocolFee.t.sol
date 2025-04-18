// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallProtocolFeeTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  function test_liquidationCall_protocolFee1() public {
    test_liquidationCall_fuzz_protocolFee1(
      DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      105_00,
      10e18,
      0.95e18,
      12_00
    );
  }

  function test_liquidationCall_fuzz_protocolFee1(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e11, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage,
      'test_liquidationCall_fuzz_protocolFee weth/dai'
    );
  }

  function test_liquidationCall_fuzz_protocolFee2(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e14, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage,
      'test_liquidationCall_fuzz_protocolFee weth/usdx'
    );
  }

  function test_liquidationCall_fuzz_protocolFee3(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e5, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    _fuzz_liqCall(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage,
      'test_liquidationCall_fuzz_protocolFee usdx/weth'
    );
  }

  function _fuzz_liqCall(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 collateralReserveId,
    uint256 debtReserveId,
    uint256 liquidationProtocolFeePercentage,
    string memory label
  ) internal {
    LiquidationTestLocalParams memory state;
    state.collateralReserve = spoke1.getReserve(collateralReserveId);
    state.debtReserve = spoke1.getReserve(debtReserveId);

    liqConfig = _bound(liqConfig);
    liqBonus = bound(liqBonus, MIN_LIQUIDATION_BONUS, MAX_LIQUIDATION_BONUS);
    desiredHf = bound(desiredHf, 0.1e18, HEALTH_FACTOR_LIQUIDATION_THRESHOLD - 1);
    liquidationProtocolFeePercentage = bound(liquidationProtocolFeePercentage, 0, 100_00);

    state.liquidationProtocolFeePercentage = liquidationProtocolFeePercentage;

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

    (uint256 finalHf, uint256 requiredDebtAmount) = _borrowToBeBelowHf(
      spoke1,
      alice,
      debtReserveId,
      desiredHf
    );
    state.liquidationBonus = _getVariableLiquidationBonus(spoke1, collateralReserveId, finalHf);

    state.debt.balanceBefore = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.liquidator.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.treasury.balanceBefore = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);

    vm.prank(LIQUIDATOR);
    spoke1.liquidationCall(collateralReserveId, debtReserveId, alice, requiredDebtAmount);

    state.liquidator.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(LIQUIDATOR);
    state.debt.balanceAfter = spoke1.getUserTotalDebt(debtReserveId, alice);
    state.treasury.balanceAfter = IERC20(state.collateralReserve.asset).balanceOf(TREASURY);

    // convert
    state.collateralBaseDiff = _convertAmountToBaseCurrency(
      state.collateralReserve.assetId,
      state.liquidator.balanceAfter -
        state.liquidator.balanceBefore +
        state.treasury.balanceAfter -
        state.treasury.balanceBefore
    );
    state.debtBaseDiff = _convertAmountToBaseCurrency(
      state.debtReserve.assetId,
      state.debt.balanceBefore - state.debt.balanceAfter
    );

    _assertLpfpEarned(state, label);
  }

  function _assertLpfpEarned(
    LiquidationTestLocalParams memory state,
    string memory label
  ) internal view {
    uint256 liqBonusEarned = _convertBaseCurrencyToAmount(
      state.collateralReserve.assetId,
      state.debtBaseDiff.percentMul(state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR)
    );
    uint256 liqProtocolFee = state.treasury.balanceAfter - state.treasury.balanceBefore;

    if (liqProtocolFee < 1e4) {
      assertApproxEqAbs(
        liqBonusEarned.percentMul(state.liquidationProtocolFeePercentage),
        liqProtocolFee,
        1,
        string.concat('protocol fee amount abs ', label)
      );
    } else {
      assertApproxEqRel(
        liqBonusEarned.percentMul(state.liquidationProtocolFeePercentage),
        liqProtocolFee,
        _approxRelFromBps(10),
        string.concat('protocol fee amount rel ', label)
      );
    }
    if (
      _convertBaseCurrencyToAmount(state.collateralReserve.reserveId, state.collateralBaseDiff) <
      1e4
    ) {
      assertApproxEqAbs(
        _convertBaseCurrencyToAmount(state.collateralReserve.reserveId, state.collateralBaseDiff),
        _convertBaseCurrencyToAmount(
          state.collateralReserve.reserveId,
          state.debtBaseDiff.percentMul(state.liquidationBonus)
        ),
        1,
        string.concat('total collateral seized should match debt abs ', label)
      );
    } else {
      assertApproxEqRel(
        _convertBaseCurrencyToAmount(state.collateralReserve.reserveId, state.collateralBaseDiff),
        _convertBaseCurrencyToAmount(
          state.collateralReserve.reserveId,
          state.debtBaseDiff.percentMul(state.liquidationBonus)
        ),
        _approxRelFromBps(10),
        string.concat('total collateral seized should match debt rel ', label)
      );
    }
  }
}
