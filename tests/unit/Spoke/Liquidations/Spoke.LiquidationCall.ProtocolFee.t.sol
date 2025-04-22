// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallProtocolFeeTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  // todo: update tests to when treasury accounting is done
  // check treasury accounting of fees instead of by token balance
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertLpfpEarned(state, 'test_liquidationCall_fuzz_protocolFee weth/dai');
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertLpfpEarned(state, 'test_liquidationCall_fuzz_protocolFee weth/usdx');
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertLpfpEarned(state, 'test_liquidationCall_fuzz_protocolFee usdx/weth');
  }

  function test_liquidationCall_fuzz_protocolFee_scenario4(
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationProtocolFeePercentage
  ) public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    supplyAmount = bound(supplyAmount, 1e16, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    _assertLpfpEarned(state, 'test_liquidationCall_fuzz_protocolFee usdx/weth');
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
