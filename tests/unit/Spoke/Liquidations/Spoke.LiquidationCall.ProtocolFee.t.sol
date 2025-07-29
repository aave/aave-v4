// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallProtocolFeeTest is SpokeLiquidationBase {
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  /// fuzz tests with varying liquidationFee
  /// single debt reserve, single collateral reserve
  /// user health factor position varies across possible desiredHf values
  /// close factor = 1e18
  function test_liquidationCall_fuzz_protocolFee(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationFee,
    uint256 skipTime
  ) public returns (LiquidationTestLocalParams memory) {
    collateralReserveId = bound(collateralReserveId, 0, spoke1.getReserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.getReserveCount() - 1);

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationFee,
      skipTime
    );
    _checkLiquidation(state, spoke1, 'test_liquidationCall_fuzz_protocolFee');
    return state;
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_protocolFee_scenario1() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_protocolFee_scenario2() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_protocolFee_scenario3() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_protocolFee_scenario4() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_protocolFee_scenario5() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_protocolFee_scenario6() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationFee: 12_00,
      skipTime: 365 days
    });
  }

  /// with 0 liquidation bonus, the protocol fee should also be 0
  function test_liquidationCall_fuzz_protocolFee_liqBonus_zero(uint256 liquidationFee) public {
    LiquidationTestLocalParams memory state = test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 100_00, // 0% LB
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationFee: liquidationFee,
      skipTime: 365 days
    });

    uint256 liquidationFee = hub.convertToSuppliedAssets(
      state.collateralReserve.assetId,
      state.treasury.balanceChange
    );
    assertEq(liquidationFee, 0, 'liquidationFee = 0');
  }
}
