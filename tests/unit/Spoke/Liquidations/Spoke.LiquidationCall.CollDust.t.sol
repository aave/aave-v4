// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract SpokeLiquidationCallCollDustTest is SpokeLiquidationCallBaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  ISpoke spoke;
  address liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();
    spoke = spoke1;

    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.000001e18,
        healthFactorForMaxBonus: 0.9e18,
        liquidationBonusFactor: 0
      })
    );

    _updateMaxLiquidationBonus(spoke, _daiReserveId(spoke), 111_00);
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 100_00);
    _updateMaxLiquidationBonus(spoke, _usdyReserveId(spoke), 100_00);

    deal(spoke, _usdxReserveId(spoke), liquidator, 1e30);
    deal(spoke, _daiReserveId(spoke), liquidator, 1e30);
    deal(spoke, _usdyReserveId(spoke), liquidator, 1e30);

    Utils.approve(spoke, _usdxReserveId(spoke), liquidator, type(uint256).max);
    Utils.approve(spoke, _daiReserveId(spoke), liquidator, type(uint256).max);
    Utils.approve(spoke, _usdyReserveId(spoke), liquidator, type(uint256).max);

    updateCollateralFactor(spoke, _daiReserveId(spoke), 90_00);
    updateCollateralFactor(spoke, _usdxReserveId(spoke), 99_99);
    updateCollateralFactor(spoke, _usdyReserveId(spoke), 99_99);

    _openSupplyPosition(spoke, _daiReserveId(spoke), 1e30);
    _openSupplyPosition(spoke, _usdxReserveId(spoke), 1e30);
    _openSupplyPosition(spoke, _usdyReserveId(spoke), 1e30);
  }

  /// @dev Test that collateral dust is not allowed
  /// if liquidator intends to fully cover the collateral, it will succeed
  /// otherwise if debtToCover leaves dust, it will revert
  function testCollateralDust() public {
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.0001e18,
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(spoke, _daiReserveId(spoke), 80_00, 124_00);
    _increaseCollateralSupply(spoke, _daiReserveId(spoke), 1010e18, alice);
    _increaseCollateralSupply(spoke, _usdyReserveId(spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: spoke,
      reserveId: _usdyReserveId(spoke),
      caller: alice,
      amount: 9_000e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(spoke, alice, _usdxReserveId(spoke), 0.9999e18);
    uint256 debtReserveBalance = spoke.getUserTotalDebt(_usdxReserveId(spoke), alice);

    // insufficient debtToCover that would result in dust collateral
    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    vm.startPrank(liquidator);
    spoke.liquidationCall(
      _daiReserveId(spoke),
      _usdxReserveId(spoke),
      alice,
      debtReserveBalance / 2
    );

    // sufficient debtToCover to repay full debtReserveBalance
    spoke.liquidationCall(_daiReserveId(spoke), _usdxReserveId(spoke), alice, debtReserveBalance);
    vm.stopPrank();

    // whole collateral should be liquidated
    assertEq(spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice), 0);
  }
}
