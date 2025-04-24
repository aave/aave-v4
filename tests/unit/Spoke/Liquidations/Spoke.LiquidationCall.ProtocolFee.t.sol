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

  /// fuzz tests with liquidationProtocolFeePercentage = 0
  function test_liquidationCall_fuzz_protocolFee(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    DataTypes.LiquidationConfig memory liqConfig,
    uint256 liqBonus,
    uint256 supplyAmount,
    uint256 desiredHf,
    uint256 liquidationProtocolFeePercentage
  ) public returns (LiquidationTestLocalParams memory) {
    // uint256 collateralReserveId = _wethReserveId(spoke1);
    // uint256 debtReserveId = _daiReserveId(spoke1);
    collateralReserveId = bound(collateralReserveId, 0, spoke1.reserveCount() - 1);
    debtReserveId = bound(debtReserveId, 0, spoke1.reserveCount() - 1);

    // supplyAmount = bound(
    //   supplyAmount,
    //   _convertBaseCurrencyToAmount(spoke1.getReserve(collateralReserveId).assetId, 1e26),
    //   MAX_SUPPLY_AMOUNT / 1e4
    // ); // bounds to ensure HF is below desiredHf within precision

    LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
      liqConfig,
      liqBonus,
      supplyAmount,
      desiredHf,
      collateralReserveId,
      debtReserveId,
      liquidationProtocolFeePercentage
    );

    string memory label = 'test_liquidationCall_fuzz_protocolFee';
    _assertLiquidationBonusEarned(state, label);
    _assertProtocolFeeEarned(state, label);
    _assertUserAccountData(state, spoke1, label);

    return state;
  }

  /// coll: weth / debt: dai
  function test_liquidationCall_protocolFee_scenario1() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// coll: weth / debt: usdx
  function test_liquidationCall_protocolFee_scenario2() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _wethReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10e18,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// coll: usdx / debt: weth
  function test_liquidationCall_protocolFee_scenario3() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// coll: usdx / debt: dai
  function test_liquidationCall_protocolFee_scenario4() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _usdxReserveId(spoke1),
      debtReserveId: _daiReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e6,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// coll: dai / debt: weth
  function test_liquidationCall_protocolFee_scenario5() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _wethReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// coll: dai / debt: usdx
  function test_liquidationCall_protocolFee_scenario6() public {
    test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 105_00,
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: 12_00
    });
  }

  /// with 0 liquidation bonus, the protocol fee should also be 0
  function test_liquidationCall_fuzz_protocolFee_lb_zero(
    uint256 liquidationProtocolFeePercentage
  ) public {
    LiquidationTestLocalParams memory state = test_liquidationCall_fuzz_protocolFee({
      collateralReserveId: _daiReserveId(spoke1),
      debtReserveId: _usdxReserveId(spoke1),
      liqConfig: DataTypes.LiquidationConfig({
        closeFactor: 1e18,
        healthFactorBonusThreshold: 0.9e18,
        liquidationBonusFactor: 70_00
      }),
      liqBonus: 100_00, // 0% LB
      supplyAmount: 10_000e18,
      desiredHf: 0.95e18,
      liquidationProtocolFeePercentage: liquidationProtocolFeePercentage
    });

    uint256 liqProtocolFee = _absDiff(state.supply.baseChange, state.liquidator.baseChange);
    assertEq(liqProtocolFee, 0, 'liqProtocolFee = 0');
  }

  // function test_liquidationCall_protocolFeeDefault() public {
  //   //usdx
  //   // test_liquidationCall_fuzz_protocolFeeDefault({
  //   //   collateralReserveId: 3,
  //   //   debtReserveId: 3,
  //   //   liqConfig: DataTypes.LiquidationConfig({
  //   //     closeFactor: 1.000000000000000086e18,
  //   //     healthFactorBonusThreshold: 5.76415242868556263e17,
  //   //     liquidationBonusFactor: 7.853e3
  //   //   }),
  //   //   liqBonus: 1.0747e4,
  //   //   supplyAmount: 5.87169236211854176781982e23,
  //   //   desiredHf: 9.99999999999999999e17,
  //   //   liquidationProtocolFeePercentage: 2.878e3
  //   // });

  //   test_liquidationCall_fuzz_protocolFeeDefault({
  //     collateralReserveId: 1,
  //     debtReserveId: 3,
  //     liqConfig: DataTypes.LiquidationConfig({
  //       closeFactor: 1.49743817868908754e18,
  //       healthFactorBonusThreshold: 9.37331172915977868e17,
  //       liquidationBonusFactor: 1e0
  //     }),
  //     liqBonus: 1.9996e4,
  //     supplyAmount: 6.4600970028233e13,
  //     desiredHf: 8.05853276202398084e17,
  //     liquidationProtocolFeePercentage: 2.535e3
  //   });
  // }

  // function test_liquidationCall_fuzz_protocolFee1(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf,
  //   uint256 liquidationProtocolFeePercentage
  // ) public {
  //   uint256 collateralReserveId = _wethReserveId(spoke1);
  //   uint256 debtReserveId = _daiReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e11, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     liquidationProtocolFeePercentage
  //   );

  //   _assertProtocolFeeEarned(state, 'test_liquidationCall_fuzz_protocolFee weth/dai');
  // }

  // function test_liquidationCall_fuzz_protocolFee2(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf,
  //   uint256 liquidationProtocolFeePercentage
  // ) public {
  //   uint256 collateralReserveId = _wethReserveId(spoke1);
  //   uint256 debtReserveId = _usdxReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e14, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     liquidationProtocolFeePercentage
  //   );

  //   _assertProtocolFeeEarned(state, 'test_liquidationCall_fuzz_protocolFee weth/usdx');
  // }

  // function test_liquidationCall_fuzz_protocolFee3(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf,
  //   uint256 liquidationProtocolFeePercentage
  // ) public {
  //   uint256 collateralReserveId = _usdxReserveId(spoke1);
  //   uint256 debtReserveId = _wethReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e5, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     liquidationProtocolFeePercentage
  //   );

  //   _assertProtocolFeeEarned(state, 'test_liquidationCall_fuzz_protocolFee usdx/weth');
  // }

  // function test_liquidationCall_fuzz_protocolFee_scenario4(
  //   DataTypes.LiquidationConfig memory liqConfig,
  //   uint256 liqBonus,
  //   uint256 supplyAmount,
  //   uint256 desiredHf,
  //   uint256 liquidationProtocolFeePercentage
  // ) public {
  //   uint256 collateralReserveId = _daiReserveId(spoke1);
  //   uint256 debtReserveId = _wethReserveId(spoke1);

  //   supplyAmount = bound(supplyAmount, 1e16, MAX_SUPPLY_AMOUNT / 1e4); // bounds to ensure HF is below desiredHf within precision

  //   LiquidationTestLocalParams memory state = _execLiqCallFuzzTest(
  //     liqConfig,
  //     liqBonus,
  //     supplyAmount,
  //     desiredHf,
  //     collateralReserveId,
  //     debtReserveId,
  //     liquidationProtocolFeePercentage
  //   );

  //   _assertProtocolFeeEarned(state, 'test_liquidationCall_fuzz_protocolFee usdx/weth');
  // }

  // function _assertProtocolFeeEarned(
  //   LiquidationTestLocalParams memory state,
  //   string memory label
  // ) internal view {
  //   ConvertedValues memory liqBonusEarned;
  //   ConvertedValues memory liqProtocolFee;

  //   liqBonusEarned.base = state.debt.baseChange.percentMul(
  //     state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR
  //   );
  //   liqBonusEarned.amount = _convertBaseCurrencyToAmount(
  //     state.collateralReserve.assetId,
  //     liqBonusEarned.base
  //   );

  //   console.log('lb % %e', state.liquidationBonus - PercentageMath.PERCENTAGE_FACTOR);

  //   if (state.collateralReserve.assetId == state.debtReserve.assetId) {
  //     // when collateral and debt are the same asset, protocol fee is calculated as
  //     liqProtocolFee.base = _absDiff(
  //       _absDiff(state.supply.baseChange, state.debt.baseChange),
  //       state.liquidator.baseChange
  //     );
  //   } else {
  //     liqProtocolFee.base = _absDiff(state.supply.baseChange, state.liquidator.baseChange);
  //   }
  //   liqProtocolFee.amount = _convertBaseCurrencyToAmount(
  //     state.collateralReserve.assetId,
  //     liqProtocolFee.base
  //   );

  //   console.log(
  //     'amount diff liquidator: %e | supplyvsDebt %e',
  //     _convertBaseCurrencyToAmount(state.collateralReserve.assetId, state.liquidator.baseChange),
  //     _convertBaseCurrencyToAmount(
  //       state.collateralReserve.assetId,
  //       _absDiff(state.supply.baseChange, state.debt.baseChange)
  //     )
  //   );

  //   console.log('liqBonusEarned amt: %e base: %e', liqBonusEarned.amount, liqBonusEarned.base);
  //   console.log('liqProtocolFee amt: %e base: %e', liqProtocolFee.amount, liqProtocolFee.base);
  //   // console.log(
  //   //   'liqProtocolFee %e',
  //   //   _convertBaseCurrencyToAmount(
  //   //     state.collateralReserve.assetId,
  //   //     _absDiff(state.supply.baseChange, state.liquidator.baseChange)
  //   //   )
  //   // );

  //   console.log('final hf %e', spoke1.getHealthFactor(alice));

  //   // constrain due to rounding/precisio
  //   if (liqProtocolFee.amount < 1e4) {
  //     // at low amounts, abs diff is greater than rel
  //     assertApproxEqAbs(
  //       liqBonusEarned.amount.percentMul(state.liquidationProtocolFeePercentage),
  //       liqProtocolFee.amount,
  //       5,
  //       string.concat('protocol fee amount abs ', label)
  //     );
  //     assertApproxEqRel(
  //       _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
  //       _convertBaseCurrencyToAmount(
  //         state.collateralAssetId,
  //         state.debt.baseChange.percentMul(state.liquidationBonus)
  //       ),
  //       _approxRelFromBps(1_00),
  //       string.concat('total collateral seized should match debt rel ', label)
  //     );
  //   } else {
  //     assertApproxEqRel(
  //       liqBonusEarned.amount.percentMul(state.liquidationProtocolFeePercentage),
  //       liqProtocolFee.amount,
  //       _approxRelFromBps(10),
  //       string.concat('protocol fee amount rel ', label)
  //     );
  //     assertApproxEqRel(
  //       _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
  //       _convertBaseCurrencyToAmount(
  //         state.collateralAssetId,
  //         state.debt.baseChange.percentMul(state.liquidationBonus)
  //       ),
  //       _approxRelFromBps(10),
  //       string.concat('total collateral seized should match debt rel ', label)
  //     );
  //   }

  //   // if (state.supply.balanceChange > 1e4) {
  //   //   assertApproxEqRel(
  //   //     _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.collateralAssetId,
  //   //       state.debt.baseChange.percentMul(state.liquidationBonus)
  //   //     ),
  //   //     _approxRelFromBps(10),
  //   //     string.concat('total collateral seized should match debt rel ', label)
  //   //   );
  //   // } else {
  //   //   assertApproxEqRel(
  //   //     _convertBaseCurrencyToAmount(state.collateralAssetId, state.supply.baseChange),
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.collateralAssetId,
  //   //       state.debt.baseChange.percentMul(state.liquidationBonus)
  //   //     ),
  //   //     _approxRelFromBps(1_00),
  //   //     string.concat('total collateral seized should match debt rel ', label)
  //   //   );
  //   // }

  //   // console.log('coll change %e', state.collateral.baseChange);
  //   // console.log('debt change %e', state.debt.baseChange);

  //   // console.log('coll bal change %e', state.supply.balanceChange);
  //   // console.log('debt bal change %e', state.debt.balanceChange);

  //   // console.log(
  //   //   'expected coll/debt %e %e',
  //   //   state.debt.baseChange.percentMul(state.liquidationBonus),
  //   //   state.supply.balanceChange
  //   // );

  //   // console.log(
  //   //   'bonus %e %e',
  //   //   _absDiff(
  //   //     state.liquidator.baseChange,
  //   //     state.debt.baseChange.percentMul(state.liquidationBonus - 100_00)
  //   //   ),
  //   //   _convertBaseCurrencyToAmount(
  //   //     state.collateralReserve.assetId,
  //   //     _absDiff(state.liquidator.baseChange, state.supply.baseChange - state.debt.baseChange)
  //   //   )
  //   // );

  //   // if (
  //   //   _convertBaseCurrencyToAmount(state.collateralReserve.reserveId, state.collateral.baseChange) <
  //   //   1e4
  //   // ) {
  //   //   assertApproxEqAbs(
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.collateralReserve.reserveId,
  //   //       state.collateral.baseChange
  //   //     ),
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.collateralReserve.reserveId,
  //   //       state.debt.baseChange.percentMul(state.liquidationBonus)
  //   //     ),
  //   //     1,
  //   //     string.concat('total collateral seized should match debt abs ', label)
  //   //   );
  //   // } else {
  //   //   assertApproxEqRel(
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.collateralReserve.reserveId,
  //   //       state.collateral.baseChange
  //   //     ),
  //   //     _convertBaseCurrencyToAmount(
  //   //       state.debtReserve.reserveId,
  //   //       state.debt.baseChange.percentMul(state.liquidationBonus)
  //   //     ),
  //   //     _approxRelFromBps(10),
  //   //     string.concat('total collateral seized should match debt rel ', label)
  //   //   );
  //   // }
  // }
}
