// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowScenarioTest is SpokeBase {
  address liquidator;
  function setUp() public override {
    super.setUp();

    updateCollateralFactor(spoke1, _daiReserveId(spoke1), 99_99);
    updateCollateralFactor(spoke1, _wethReserveId(spoke1), 99_99);
    updateCollateralFactor(spoke1, _usdxReserveId(spoke1), 99_99);
    updateCollateralFactor(spoke1, _wbtcReserveId(spoke1), 99_99);

    _updateMaxLiquidationBonus(spoke1, _daiReserveId(spoke1), 100_00);
    _updateMaxLiquidationBonus(spoke1, _wethReserveId(spoke1), 100_00);
    _updateMaxLiquidationBonus(spoke1, _usdxReserveId(spoke1), 100_00);
    _updateMaxLiquidationBonus(spoke1, _wbtcReserveId(spoke1), 100_00);

    _updateLiquidationFee(spoke1, _daiReserveId(spoke1), 100_00);
    _updateLiquidationFee(spoke1, _wethReserveId(spoke1), 100_00);
    _updateLiquidationFee(spoke1, _usdxReserveId(spoke1), 100_00);
    _updateLiquidationFee(spoke1, _wbtcReserveId(spoke1), 100_00);

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 1e22);
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    updateCollateralRisk(spoke1, _usdxReserveId(spoke1), 0);
    updateCollateralRisk(spoke1, _wbtcReserveId(spoke1), 0);
    updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);

    liquidator = makeAddr('liquidator');
    deal(address(tokenList.dai), liquidator, 1e30);

    vm.prank(liquidator);
    tokenList.dai.approve(address(hub1), MAX_SUPPLY_AMOUNT);
  }

  function test_liq_donation() public {
    // console.log('test');
    // assertEq(true, false);

    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 100e18, alice);
    _mockInterestRateBps(500_00);

    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);

    skip(365 days);
    // now debt index is 1.5

    console.log('TEST debt index %e', hub1.getAssetDrawnIndex(_daiReserveId(spoke1)));
    console.log('TEST supply ex rate %e', hub1.convertToAddedAssets(_daiReserveId(spoke1), 1e30));
    console.log('liquidator balance before %e', tokenList.dai.balanceOf(liquidator));

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 1_100e18, bob);
    _borrowToBeAtHf(spoke1, bob, _daiReserveId(spoke1), 0.75e18);

    // console.log('%e', spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob));
    // console.log('%e', spoke1.getUserAccountData(bob).healthFactor);

    console.log('hf %e', spoke1.getUserAccountData(bob).healthFactor);

    uint256 numIterations = 10000;
    uint256[] memory supplyExRate = new uint256[](numIterations);

    uint256 supplyAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob);
    uint256 debtAmountBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 debtAmountSharesBefore = spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares;

    console.log('supply ex rate %e', hub1.convertToAddedAssets(_daiReserveId(spoke1), 1e30));

    vm.startPrank(liquidator);
    for (uint256 i = 0; i < numIterations; i++) {
      tokenList.dai.approve(address(hub1), MAX_SUPPLY_AMOUNT);
      // spoke1.supply(_daiReserveId(spoke1), 1e28, liquidator);

      spoke1.liquidationCall(_daiReserveId(spoke1), _daiReserveId(spoke1), bob, 5); // liquidate less than 1 full debt share
      // supplyExRate[i] = hub1.convertToAddedAssets(_daiReserveId(spoke1), 1e30);
      // bool increased = i > 0 && supplyExRate[i] > supplyExRate[i - 1];

      // spoke1.withdraw(_daiReserveId(spoke1), UINT256_MAX, liquidator);

      // console.log('supply ex rate incr?', increased);
      // console.log('hf %e', spoke1.getUserAccountData(bob).healthFactor);
      // if (increased) {
      //   console.log(
      //     'ex rate %e | delta %e',
      //     supplyExRate[i],
      //     stdMath.delta(supplyExRate[i], supplyExRate[i - 1])
      //   );
      // }
      // console.log('supply ex rate %e', hub1.convertToAddedShares(_daiReserveId(spoke1), 1e30));
      // console.log('liquidity %e', hub1.getAsset(_daiReserveId(spoke1)).liquidity);

      // console.log(
      //   'TEST supplied shares after %e',
      //   spoke1.getUserSuppliedShares(_daiReserveId(spoke1), bob)
      // );
    }
    vm.stopPrank();

    uint256 supplyAmountAfter = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob);
    uint256 debtAmountAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 debtAmountSharesAfter = spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares;

    // console.log('TEST BEFORE supplied amt %e debt amt %e', supplyAmountBefore, debtAmountBefore);
    // console.log('TEST AFTER supplied amt %e debt amt %e', supplyAmountAfter, debtAmountAfter);

    console.log('supply ex rate %e', hub1.convertToAddedAssets(_daiReserveId(spoke1), 1e30));

    console.log(
      'TEST bob supplied amt before/after %e %e delta: %e',
      supplyAmountBefore,
      supplyAmountAfter,
      supplyAmountBefore - supplyAmountAfter
    );
    console.log(
      'TEST debt amt before/after %e %e delta: %e',
      debtAmountBefore,
      debtAmountAfter,
      debtAmountBefore - debtAmountAfter
    );
    // console.log(
    //   'TEST debt shares delta %e',
    //   stdMath.delta(debtAmountSharesAfter, debtAmountSharesBefore)
    // );

    console.log('liquidator balance after %e', tokenList.dai.balanceOf(liquidator));
    console.log('hf %e', spoke1.getUserAccountData(bob).healthFactor);

    // console.log(spoke1.getUserTotalDebt(_daiReserveId(spoke1), alice));
    // console.log(hub1.getAssetDrawnIndex(_daiReserveId(spoke1)));
  }
}
