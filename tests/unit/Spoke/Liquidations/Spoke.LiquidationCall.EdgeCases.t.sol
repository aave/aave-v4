// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.Liquidation.Base.t.sol';

contract LiquidationCallEdgeCasesTest is SpokeLiquidationBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  /// test for liquidation call with max collateral amount equal to full collateral amount
  /// rare occurrence in single coll case, but can happen with multiple colls where 1 is fully liquidated
  function test_liquidationCall_validMaxCollateralAmount() public {
    // set collateral factor of coll as 100%
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 100_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 100_00);
    updateCloseFactor(spoke1, 10e18); // close factor that is too high to reach, thus all coll is liquidatable

    // 2 collaterals, so that even though one is fully liquidated, it does not become bad debt
    // second amount of coll/debt is small enough that full liquidation doesn't reach close factor
    // collateral: weth/usdx
    uint256 supplyAmount = 5 * 10 ** decimals.weth; // $10k weth
    uint256 supplyAmount2 = 1_000 * 10 ** decimals.usdx; // $1k usdx
    // debt: dai/usdy
    uint256 borrowAmount = 10_000 * 10 ** decimals.dai; // $10k dai
    uint256 borrowAmount2 = 1_000 * 10 ** decimals.usdy; // $1k usdy

    // supply
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, supplyAmount2, alice);

    // borrow
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.borrow(spoke1, _usdyReserveId(spoke1), alice, borrowAmount2, alice);

    // price drops to reach liquidatable state
    _mockReservePriceByPercent(spoke1, _wethReserveId(spoke1), 50_00);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _usdyReserveId(spoke1), alice, UINT256_MAX);

    // Alice's usdx collateral unset
    assertTrue(spoke1.isUsingAsCollateral(_usdxReserveId(spoke1), alice));

    // all collateral liquidated without overflowing
    assertEq(
      spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), alice),
      0,
      'all collateral liquidated'
    );
  }

  /// fuzz test for liquidation call with max collateral amount equal to full collateral amount
  /// rare occurrence in single coll case, but can happen with multiple colls where 1 is fully liquidated
  function test_liquidationCall_fuzz_validMaxCollateralAmount(uint256 supplyAmountInBase) public {
    supplyAmountInBase = bound(supplyAmountInBase, 10e26, 1e7 * 1e26); // $1 - $10M

    // set collateral factor of coll as 100%
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 100_00);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 100_00);
    updateCloseFactor(spoke1, 10e18); // close factor that is too high to reach, thus all coll is liquidatable

    // 2 collaterals, so that even though one is fully liquidated, it does not become bad debt
    // second amount of coll/debt is 1/10 of first
    // collateral
    uint256 supplyAmount = ((supplyAmountInBase.percentMulUp(101_00) * 10 ** decimals.weth) /
      spoke1.oracle().getReservePrice(_wethReserveId(spoke1))).fromWadDown();
    uint256 supplyAmount2 = (((supplyAmountInBase / 10) * 10 ** decimals.usdx) /
      spoke1.oracle().getReservePrice(_usdxReserveId(spoke1))).fromWadDown();
    // debt
    uint256 borrowAmount = ((supplyAmountInBase * 10 ** decimals.dai) /
      spoke1.oracle().getReservePrice(_daiReserveId(spoke1))).fromWadDown();
    uint256 borrowAmount2 = (((supplyAmountInBase / 10) * 10 ** decimals.usdy) /
      spoke1.oracle().getReservePrice(_usdyReserveId(spoke1))).fromWadDown();

    // supply
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, supplyAmount, alice);
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, supplyAmount2, alice);

    // borrow
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.borrow(spoke1, _usdyReserveId(spoke1), alice, borrowAmount2, alice);

    // price drops to reach liquidatable state
    _mockReservePriceByPercent(spoke1, _wethReserveId(spoke1), 50_00);

    // position is liquidatable
    assertLt(spoke1.getHealthFactor(alice), HEALTH_FACTOR_LIQUIDATION_THRESHOLD);

    vm.prank(bob);
    spoke1.liquidationCall(_usdxReserveId(spoke1), _usdyReserveId(spoke1), alice, UINT256_MAX);

    // Alice's usdx collateral unset
    assertTrue(spoke1.isUsingAsCollateral(_usdxReserveId(spoke1), alice));

    // all collateral liquidated without overflowing
    assertEq(
      spoke1.getUserSuppliedShares(_usdxReserveId(spoke1), alice),
      0,
      'all collateral liquidated'
    );
  }
}
