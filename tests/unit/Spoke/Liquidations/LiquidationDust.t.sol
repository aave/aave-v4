// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract LiquidationDustTest is SpokeLiquidationCallBaseTest {
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

    _updateCollateralFactor(spoke, _daiReserveId(spoke), 90_00);
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 99_99);
    _updateCollateralFactor(spoke, _usdyReserveId(spoke), 99_99);

    _openSupplyPosition(spoke, _daiReserveId(spoke), 1e30);
    _openSupplyPosition(spoke, _usdxReserveId(spoke), 1e30);
    _openSupplyPosition(spoke, _usdyReserveId(spoke), 1e30);
  }

  /// @dev debtToTarget is limiting factor that would result in dust collateral
  function testCollDust() public {
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

    console.log('dai collateral $%18e', spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice));
    console.log('usdy collateral $%18e', spoke.getUserSuppliedAssets(_usdyReserveId(spoke), alice));
    console.log('usdx debt $%6e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
    console.log('usdy debt $%18e', spoke.getUserTotalDebt(_usdyReserveId(spoke), alice));
    console.log('health factor %18e', spoke.getUserAccountData(alice).healthFactor);

    vm.startPrank(liquidator);
    spoke.liquidationCall(_daiReserveId(spoke), _usdxReserveId(spoke), alice, 1020e6);

    console.log(
      'dai collateral after liq %18e',
      spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice)
    );
    console.log(
      'usdy collateral after liq %18e',
      spoke.getUserSuppliedAssets(_usdyReserveId(spoke), alice)
    );
    console.log('usdx debt after liq $%6e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
    console.log('usdy debt after liq $%18e', spoke.getUserTotalDebt(_usdyReserveId(spoke), alice));
    console.log('health factor %18e', spoke.getUserAccountData(alice).healthFactor);
  }

  function testCollDust2() public {
    vm.prank(SPOKE_ADMIN);
    spoke.updateLiquidationConfig(
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.0001e18,
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 0
      })
    );

    _updateCollateralFactorAndLiquidationBonus(spoke, _daiReserveId(spoke), 80_00, 124_00);
    _increaseCollateralSupply(spoke, _daiReserveId(spoke), 1100e18, alice);
    _increaseCollateralSupply(spoke, _usdyReserveId(spoke), 10_000e18, alice);

    Utils.borrow({
      spoke: spoke,
      reserveId: _usdyReserveId(spoke),
      caller: alice,
      amount: 8_500e18,
      onBehalfOf: alice
    });
    _borrowToBeAtHf(spoke, alice, _usdxReserveId(spoke), 0.98e18);

    console.log('dai collateral $%18e', spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice));
    console.log('usdy collateral $%18e', spoke.getUserSuppliedAssets(_usdyReserveId(spoke), alice));
    console.log('usdx debt $%6e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
    console.log('usdy debt $%18e', spoke.getUserTotalDebt(_usdyReserveId(spoke), alice));
    console.log('health factor %18e', spoke.getUserAccountData(alice).healthFactor);

    uint256 debtToCover = 1800e6;
    console.log('debtToCover $%6e', debtToCover);

    vm.startPrank(liquidator);
    spoke.liquidationCall(_daiReserveId(spoke), _usdxReserveId(spoke), alice, debtToCover);

    console.log(
      'dai collateral after liq %18e',
      spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice)
    );
    console.log(
      'usdy collateral after liq %18e',
      spoke.getUserSuppliedAssets(_usdyReserveId(spoke), alice)
    );
    console.log('usdx debt after liq $%6e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
    console.log('usdy debt after liq $%18e', spoke.getUserTotalDebt(_usdyReserveId(spoke), alice));
    console.log('health factor %18e', spoke.getUserAccountData(alice).healthFactor);
  }

  //   function testCollDust(
  //     uint256 collateralAmount,
  //     uint256 healthFactor,
  //     uint256 cf,
  //     uint256 lb
  //   ) public {
  //     collateralAmount = bound(collateralAmount, 100e18, 3_000e18);
  //     healthFactor = bound(healthFactor, 0.9e18, 0.99e18);
  //     cf = bound(cf, 10_00, 99_00);
  //     lb = bound(lb, 100_00, PercentageMath.PERCENTAGE_FACTOR.percentDivDown(cf + 1));

  //     console.log('cf %e', cf);
  //     console.log('lb %e', lb);

  //     _updateCollateralFactorAndLiquidationBonus(spoke, _daiReserveId(spoke), cf, lb);

  //     _increaseCollateralSupply(spoke, _daiReserveId(spoke), collateralAmount, alice);
  //     _borrowToBeAtHf(spoke, alice, _usdxReserveId(spoke), healthFactor);

  //     // console.log('collateral %e', spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice));
  //     // console.log('debt %e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
  //     // console.log('health factor %e', spoke.getUserAccountData(alice).healthFactor);

  //     // vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
  //     vm.startPrank(liquidator);
  //     spoke.liquidationCall(
  //       _daiReserveId(spoke),
  //       _usdxReserveId(spoke),
  //       alice,
  //       spoke.getUserTotalDebt(_usdxReserveId(spoke), alice)
  //     );
  //     vm.stopPrank();

  //     // console.log(
  //     //   'collateral after liq %e',
  //     //   spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice)
  //     // );
  //     // console.log('debt after liq %e', spoke.getUserTotalDebt(_usdxReserveId(spoke), alice));
  //   }
}
