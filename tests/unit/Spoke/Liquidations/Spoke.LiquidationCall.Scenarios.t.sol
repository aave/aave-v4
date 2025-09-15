// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract SpokeLiquidationCallScenariosTest is SpokeLiquidationCallBaseTest {
  address user = makeAddr('user');
  address liquidator = makeAddr('liquidator');

  ISpoke spoke;

  function setUp() public virtual override {
    super.setUp();

    spoke = spoke1;

    _updateTargetHealthFactor(spoke, 1.05e18);

    _updateCollateralFactor(spoke, _wethReserveId(spoke), 80_00);
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 70_00);
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 72_00);
    _updateCollateralFactor(spoke, _daiReserveId(spoke), 75_00);

    _updateCollateralRisk(spoke, _wethReserveId(spoke), 5_00);
    _updateCollateralRisk(spoke, _wbtcReserveId(spoke), 15_00);
    _updateCollateralRisk(spoke, _usdxReserveId(spoke), 10_00);
    _updateCollateralRisk(spoke, _daiReserveId(spoke), 12_00);

    _updateMaxLiquidationBonus(spoke, _wethReserveId(spoke), 105_00);
    _updateMaxLiquidationBonus(spoke, _wbtcReserveId(spoke), 103_00);
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 101_00);
    _updateMaxLiquidationBonus(spoke, _daiReserveId(spoke), 106_00);

    _updateLiquidationFee(spoke, _wethReserveId(spoke), 10_00);
    _updateLiquidationFee(spoke, _wbtcReserveId(spoke), 15_00);
    _updateLiquidationFee(spoke, _usdxReserveId(spoke), 12_00);
    _updateLiquidationFee(spoke, _daiReserveId(spoke), 10_00);

    _updateLiquidationConfig(
      spoke,
      ISpoke.LiquidationConfig({
        targetHealthFactor: _getTargetHealthFactor(spoke),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 100_00
      })
    );

    for (uint256 reserveId = 0; reserveId < spoke.getReserveCount(); reserveId++) {
      deal(spoke, reserveId, liquidator, MAX_SUPPLY_AMOUNT);
      Utils.approve(hub1, spoke.getReserve(reserveId).assetId, liquidator, MAX_SUPPLY_AMOUNT);
    }
  }

  // User is solvent, but health factor decreases after liquidation due to high liquidation bonus.
  // A new collateral factor is set for WETH, but it does not affect the user since dynamic config
  // key is not refreshed during liquidations.
  function test_scenario1() public {
    // A high liquidation bonus will be applied
    _updateMaxLiquidationBonus(spoke, _wethReserveId(spoke), 124_00);

    // Borrow rates:
    //   - DAI: 3%
    vm.prank(address(hub1));
    irStrategy.setInterestRateData(
      _daiReserveId(spoke),
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 3_00,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        })
      )
    );

    // Collateral and debt composition
    //   - Collaterals: 2 WETH, 0.01 WBTC, 100 USDX ($4600)
    //   - Debts: 3600 DAI
    _increaseCollateralSupply(spoke, _wethReserveId(spoke), 2e18, user);
    _increaseCollateralSupply(spoke, _wbtcReserveId(spoke), 0.01e8, user);
    _increaseCollateralSupply(spoke, _usdxReserveId(spoke), 100e6, user);
    _increaseReserveDebt(spoke, _daiReserveId(spoke), 3600e18, user);

    // Update weth collateral factor to 70%.
    // This will have no effect on the user since liquidation is not refreshing user's dynamic config key.
    _updateCollateralFactor(spoke, _wethReserveId(spoke), 70_00);

    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    // Health Factor: ($4000 * 0.8 + $500 * 0.7 + $100 * 0.72) / $3600 = ~1.0061
    assertApproxEqAbs(
      userAccountData.healthFactor,
      1.0061e18,
      0.0001e18,
      'pre liquidation: health factor'
    );
    // Risk Premium: 5%
    assertEq(userAccountData.userRiskPremium, 5_00, 'pre liquidation: risk premium');

    skip(365 days);
    userAccountData = spoke.getUserAccountData(user);

    // Debt after 1 year: 3600$ * 1.03 + $3600 * 0.05 * 0.03 = $3713.4
    // Health Factor after 1 year: ($4000 * 0.8 + $500 * 0.7 + $100 * 0.72) / $3713.4 = ~0.97539
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.975e18,
      0.001e18,
      'pre liquidation: health factor after 1 year'
    );

    // Debt to target: $3713.4 * (1.05 - 0.97539) / ($1 * (1.05 - 1.24 * 0.8)) = ~4776.84
    // Liquidation Parameters:
    //   - Collateral: WETH
    //   - Debt: DAI
    //   - Debt to cover: 4000
    // Liquidated amounts:
    //   - Collateral: 2 WETH
    //   - Debt: $4000 / ($1 * 1.249) = ~3225.8 DAI
    vm.prank(liquidator);
    spoke.liquidationCall(_wethReserveId(spoke), _daiReserveId(spoke), user, 4000e18);

    // Debt left after liquidation: 3713.4 - 3225.8 = 487.6 DAI (all drawn)
    assertApproxEqAbs(
      getUserDebt(spoke, user, _daiReserveId(spoke)).drawnDebt,
      487.6e18,
      0.1e18,
      'post liquidation: drawn debt left'
    );
    assertApproxEqAbs(
      getUserDebt(spoke, user, _daiReserveId(spoke)).premiumDebt,
      0,
      2,
      'post liquidation: premium debt left'
    );
    // Health Factor after liquidation: ($500 * 0.7 + $100 * 0.72) / ($3713.4 - $3225.8) = ~0.8654
    userAccountData = spoke.getUserAccountData(user);
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.8654e18,
      0.0001e18,
      'post liquidation: health factor'
    );
    // Risk Premium after liquidation: ($100 * 10% + 387.5 * 15%) / 487.6 = 13.97%
    assertApproxEqAbs(userAccountData.userRiskPremium, 13_97, 1, 'post liquidation: risk premium');
  }

  // Same collateral is used for debt and collateral, and has low liquidity. Liquidation succeeds
  // because debt is repaid before collateral is liquidated.
  function test_scenario2() public {
    // Borrow rates:
    //   - WBTC: 3%
    vm.prank(address(hub1));
    irStrategy.setInterestRateData(
      _wbtcReserveId(spoke),
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseVariableBorrowRate: 3_00,
          variableRateSlope1: 0,
          variableRateSlope2: 0
        })
      )
    );

    // Collateral and debt composition
    //   - Collaterals: 0.2 WBTC, 0.5 WETH ($11000)
    //   - Debts: 0.18 WBTC ($9000)
    // WBTC liquidity: 0.2 - 0.18 = 0.02
    _increaseCollateralSupply(spoke, _wethReserveId(spoke), 0.5e18, user);
    _increaseCollateralSupply(spoke, _wbtcReserveId(spoke), 0.2e8, user);
    _borrowWithoutHfCheck(spoke, user, _wbtcReserveId(spoke), 0.18e8);
    assertEq(hub1.getLiquidity(wbtcAssetId), 0.02e8);

    // Health Factor: ($10000 * 0.7 + $1000 * 0.8) / $9000 = ~0.8666
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.8666e18,
      0.0001e18,
      'pre liquidation: health factor'
    );

    // Debt to target: $9000 * (1.05 - 0.8666) / ($50000 * (1.05 - 1.03 * 0.7)) = ~0.1003
    // Liquidation Parameters:
    //   - Collateral: WBTC
    //   - Debt: WBTC
    //   - Debt to cover: 0.12
    // Liquidated amounts:
    //   - Collateral: 0.1003 * 1.03 = ~0.1033 WBTC
    //   - Debt: 0.1003 WBTC
    vm.prank(liquidator);
    spoke.liquidationCall(_wbtcReserveId(spoke), _wbtcReserveId(spoke), user, 0.13e8);

    // Debt left after liquidation: 0.18 - 0.1003 = 0.0797 WBTC
    assertApproxEqAbs(
      getUserDebt(spoke, user, _wbtcReserveId(spoke)).drawnDebt,
      0.0797e8,
      0.0001e8,
      'post liquidation: drawn debt left'
    );
    // Health Factor after liquidation: ((0.2 - 0.1033) * $50000 * 0.7 + $1000 * 0.8) / (0.0797 * $50000) = ~1.05 (target health factor)
    userAccountData = spoke.getUserAccountData(user);
    assertApproxEqAbs(
      userAccountData.healthFactor,
      1.05e18,
      0.0001e18,
      'post liquidation: health factor'
    );
  }
}
