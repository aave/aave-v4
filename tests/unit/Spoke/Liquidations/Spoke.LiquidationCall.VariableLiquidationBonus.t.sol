// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeLiquidationBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;

  /// fuzz tests with liquidationProtocolFeePercentage = 0
  function test_liquidationCall_fuzz_variableLB(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf
  ) public {
    // uint256 collateralReserveId = _wethReserveId(spoke1);
    // uint256 debtReserveId = _daiReserveId(spoke1);

    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    // supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest({
      liqConfig: liqConfig,
      liqBonus: liqBonus,
      supplyAmount: supplyAmount,
      desiredHf: desiredHf,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liquidationProtocolFeePercentage: 0
    });

    string memory label = 'liquidationCall_fuzz_variableLB';
    _assertProtocolFeeEarned(state, label);
    _assertLiquidationBonusEarned(state, label);
    _assertUserAccountData(state, spoke1, label);
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_variableLB_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_variableLB_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_variableLB_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_variableLB_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_variableLB_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_variableLB_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_variableLB({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18
    });
  }

  // function test_liquidationCall_variableLB1_unit2() public {
  //   test_liquidationCall_fuzz_variableLB1(
  //     DataTypes.LiquidationConfig({
  //       closeFactor: 1.03e18,
  //       healthFactorBonusThreshold: 0.9e18,
  //       liquidationBonusFactor: 70_00
  //     }),
  //     105_00,
  //     10e18,
  //     0.95e18
  //   );
  // }

  // /// weth collateral / dai debt
  // function test_liquidationCall_fuzz_variableLB1(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf
  // ) public {
  //   uint256 collateralReserveId = _wethReserveId(spoke1);
  //   uint256 debtReserveId = _daiReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e8, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     0
  //   );

  //   _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB weth/dai');
  // }

  // function test_liquidationCall_variableLB2_unit1() public {
  //   test_liquidationCall_fuzz_variableLB2(
  //     DataTypes.LiquidationConfig({
  //       closeFactor: 1e18,
  //       healthFactorBonusThreshold: 0.88e18,
  //       liquidationBonusFactor: 70_00
  //     }),
  //     107_00,
  //     1e18,
  //     0.93e18
  //   );
  // }

  // function test_liquidationCall_variableLB2_unit2() public {
  //   test_liquidationCall_fuzz_variableLB2(
  //     DataTypes.LiquidationConfig({
  //       closeFactor: 1.04e18,
  //       healthFactorBonusThreshold: 0.88e18,
  //       liquidationBonusFactor: 83_00
  //     }),
  //     107_00,
  //     1e18,
  //     0.93e18
  //   );
  // }

  // /// weth collateral / usdx debt
  // function test_liquidationCall_fuzz_variableLB2(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf
  // ) public {
  //   uint256 collateralReserveId = _wethReserveId(spoke1);
  //   uint256 debtReserveId = _usdxReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e13, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     0
  //   );

  //   _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB weth/usdx');
  // }

  // /// usdx collateral / weth debt
  // function test_liquidationCall_fuzz_variableLB3(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf
  // ) public {
  //   uint256 collateralReserveId = _usdxReserveId(spoke1);
  //   uint256 debtReserveId = _wethReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e7, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     0
  //   );

  //   _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB usdx/weth');
  // }

  // /// dai collateral / usdx debt
  // function test_liquidationCall_fuzz_variableLB4(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf
  // ) public {
  //   uint256 collateralReserveId = _daiReserveId(spoke1);
  //   uint256 debtReserveId = _usdxReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e16, MAX_SUPPLY_AMOUNT); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     0
  //   );

  //   _assertLiquidationBonusEarned(state, 'test_liquidationCall_fuzz_variableLB dai/usdx');
  // }
}
