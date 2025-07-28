// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallVariableLiquidationBonusTest is SpokeLiquidationBase {
  /// fuzz tests with liquidationFee = 0, so all fees are paid to the liquidator
  /// single debt reserve, single collateral reserve
  /// user health factor position varies across possible desiredHf values
  /// liquidation bonus varies
  /// close factor = 1e18
  function test_liquidationCall_fuzz_variable_liqBonus(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 skipTime
  ) public {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest({
      liqConfig: liqConfig,
      liqBonus: liqBonus,
      supplyAmount: supplyAmount,
      desiredHf: desiredHf,
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liquidationFee: 0,
      skipTime: skipTime
    });

    _checkLiquidation(state, spoke1, 'liquidationCall_fuzz_variableLiqBonus');
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_variable_liqBonus_scenario1() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_variable_liqBonus_scenario2() public {
    uint256 collateralReserveId = _wethReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_variable_liqBonus_scenario3() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_variable_liqBonus_scenario4() public {
    uint256 collateralReserveId = _usdxReserveId(spoke1);
    uint256 debtReserveId = _daiReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_variable_liqBonus_scenario5() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _wethReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_variable_liqBonus_scenario6() public {
    uint256 collateralReserveId = _daiReserveId(spoke1);
    uint256 debtReserveId = _usdxReserveId(spoke1);

    test_liquidationCall_fuzz_variable_liqBonus({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      skipTime: 365 days
    });
  }
}
