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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
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

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
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
