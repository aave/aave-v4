// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Liquidations/Spoke.LiquidationCall.Base.t.sol';

contract SpokeLiquidationCallScenariosTest is SpokeLiquidationCallBaseTest {
  using SafeCast for *;

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
      Utils.approve(spoke, reserveId, liquidator, MAX_SUPPLY_AMOUNT);
    }
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRemove() public {
    uint256 collateralReserveId = _daiReserveId(spoke);
    uint256 debtReserveId = _wethReserveId(spoke);
    _increaseCollateralSupply(spoke, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke),
      ISpokeBase.liquidationCall.selector
    );

    vm.mockFunction(
      address(_hub(spoke, collateralReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.remove.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRestore() public {
    uint256 collateralReserveId = _daiReserveId(spoke);
    uint256 debtReserveId = _wethReserveId(spoke);
    _increaseCollateralSupply(spoke, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke),
      ISpokeBase.liquidationCall.selector
    );

    vm.mockFunction(
      address(_hub(spoke, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.restore.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRefreshPremium()
    public
  {
    uint256 collateralReserveId = _daiReserveId(spoke);
    uint256 debtReserveId = _wethReserveId(spoke);
    _increaseCollateralSupply(spoke, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke),
      ISpokeBase.liquidationCall.selector
    );

    vm.mockFunction(
      address(_hub(spoke, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubReportDeficit() public {
    uint256 collateralReserveId = _daiReserveId(spoke);
    uint256 debtReserveId = _wethReserveId(spoke);
    _increaseCollateralSupply(spoke, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.5e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke),
      ISpokeBase.liquidationCall.selector
    );

    vm.mockFunction(
      address(_hub(spoke, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }

  // User is solvent, but health factor decreases after liquidation due to high liquidation bonus.
  // A new collateral factor is set for WETH, but it does not affect the user since dynamic config
  // key is not refreshed during liquidations.
  function test_liquidationCall_scenario1() public {
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
    assertEq(userAccountData.riskPremium, 5_00, 'pre liquidation: risk premium');

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
    //   - Debt: $4000 / ($1 * 1.24) = ~3225.8 DAI
    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: _wethReserveId(spoke),
        debtReserveId: _daiReserveId(spoke),
        user: user,
        debtToCover: 4000e18,
        liquidator: liquidator,
        isSolvent: true,
        receiveShares: false
      })
    );

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
    assertApproxEqAbs(userAccountData.riskPremium, 13_97, 1, 'post liquidation: risk premium');
  }

  // User is solvent, but health factor decreases after liquidation due to high collateral factor.
  function test_liquidationCall_scenario2() public {
    _updateMaxLiquidationBonus(spoke, _wethReserveId(spoke), 103_00);
    _updateCollateralFactor(spoke, _wethReserveId(spoke), 97_00);

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
    //   - Collaterals: 1.65 WETH, 0.01 WBTC, 100 USDX ($3900)
    //   - Debts: 3600 DAI
    _increaseCollateralSupply(spoke, _wethReserveId(spoke), 1.65e18, user);
    _increaseCollateralSupply(spoke, _wbtcReserveId(spoke), 0.01e8, user);
    _increaseCollateralSupply(spoke, _usdxReserveId(spoke), 100e6, user);
    _increaseReserveDebt(spoke, _daiReserveId(spoke), 3600e18, user);

    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);

    // Health Factor: ($3300 * 0.97 + $500 * 0.7 + $100 * 0.72) / $3600 = ~1.00639
    assertApproxEqAbs(
      userAccountData.healthFactor,
      1.0063e18,
      0.0001e18,
      'pre liquidation: health factor'
    );
    // Risk Premium: ceil(($3300 * 5% + $100 * 10% + $200 * 15%) / $3600) = ceil(~5.694%) = ~5.70%
    assertEq(userAccountData.riskPremium, 5_70, 'pre liquidation: risk premium');

    skip(365 days / 2);
    userAccountData = spoke.getUserAccountData(user);

    // Debt after half of year: 3600$ * 1.015 + $3600 * 0.0569 * 0.015 = ~$3657.0726
    // Health Factor after half of year: ($3300 * 0.97 + $500 * 0.7 + $100 * 0.72) /$3657.0726 = ~0.99068
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.990e18,
      0.001e18,
      'pre liquidation: health factor after half of year'
    );

    // Debt to target: $3657.0726 * (1.05 - 0.99068) / ($1 * (1.05 - 1.03 * 0.97)) = ~4262.03431
    // Liquidation Parameters:
    //   - Collateral: WETH
    //   - Debt: DAI
    //   - Debt to cover: 4000
    // Liquidated amounts:
    //   - Collateral: 1.65 WETH
    //   - Debt: $3300 / ($1 * 1.03) = ~3203.8835 DAI
    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: _wethReserveId(spoke),
        debtReserveId: _daiReserveId(spoke),
        user: user,
        debtToCover: 4000e18,
        liquidator: liquidator,
        isSolvent: true,
        receiveShares: false
      })
    );

    // Debt left after liquidation: 3657.0726 - 3203.8835 = 453.1891 DAI (all drawn)
    assertApproxEqAbs(
      getUserDebt(spoke, user, _daiReserveId(spoke)).drawnDebt,
      453.1891e18,
      0.1e18,
      'post liquidation: drawn debt left'
    );
    assertApproxEqAbs(
      getUserDebt(spoke, user, _daiReserveId(spoke)).premiumDebt,
      0,
      2,
      'post liquidation: premium debt left'
    );
    // Health Factor after liquidation: ($500 * 0.7 + $100 * 0.72) / ($3657.0726 - $3203.8835) = ~0.9311
    userAccountData = spoke.getUserAccountData(user);
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.9311e18,
      0.0001e18,
      'post liquidation: health factor'
    );
    // Risk Premium after liquidation: ($100 * 10% + $353.1891 * 15%) / $453.1891 = 13.89%
    assertApproxEqAbs(userAccountData.riskPremium, 13_89, 1, 'post liquidation: risk premium');
  }

  // Liquidated collateral is between 0 and 1 wei. It is rounded down and hub.remove is skipped to avoid reverting.
  function test_liquidationCall_scenario3() public {
    // Liquidation bonus: 0
    _updateMaxLiquidationBonus(spoke, _wethReserveId(spoke), 100_00);

    // The collateral has a price 100 times higher than the debt
    _mockReservePrice(spoke, _wethReserveId(spoke), 100e8);
    _mockReservePrice(spoke, _daiReserveId(spoke), 1e8);

    // Collateral: 1 wei of WETH
    _increaseCollateralSupply(spoke, _wethReserveId(spoke), 1, user);

    // Max borrow: 79 wei of DAI (collateral factor of WETH is 80%)
    assertEq(_getCollateralFactor(spoke, _wethReserveId(spoke)), 80_00);
    _increaseReserveDebt(spoke, _daiReserveId(spoke), 79, user);

    // Decrease WETH price by 10% to make user unhealthy
    _mockReservePriceByPercent(spoke, _wethReserveId(spoke), 90_00);

    // User is liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // Perform liquidation
    // Liquidated amounts:
    //   - Collateral: 79 * 1 / 90 = 0 rounded down (hub call will be skipped, otherwise liquidation would revert)
    //   - Debt: 79 wei of DAI
    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: _wethReserveId(spoke),
        debtReserveId: _daiReserveId(spoke),
        user: user,
        debtToCover: type(uint256).max,
        liquidator: liquidator,
        isSolvent: true,
        receiveShares: false
      })
    );

    assertEq(spoke.getUserSuppliedAssets(_wethReserveId(spoke), user), 1, 'Collateral should be 1');
    assertEq(spoke.getUserTotalDebt(_daiReserveId(spoke), user), 0, 'Debt should be 0');
    assertEq(
      _hub(spoke, _daiReserveId(spoke)).getAssetDeficitRay(
        _reserveAssetId(spoke, _daiReserveId(spoke))
      ),
      0,
      'Deficit should be 0'
    );
  }

  /// @dev when receiving shares, liquidator can already have setUsingAsCollateral
  function test_liquidationCall_scenario4() public {
    uint256 collateralReserveId = _wethReserveId(spoke);
    uint256 debtReserveId = _daiReserveId(spoke);
    // liquidator can receive shares even if they have already set as collateral
    bool receiveShares = true;

    // liquidator sets as collateral
    vm.prank(liquidator);
    spoke.setUsingAsCollateral(collateralReserveId, true, liquidator);

    _increaseCollateralSupply(spoke, collateralReserveId, 10e18, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.95e18);
    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        user: user,
        debtToCover: type(uint256).max,
        liquidator: liquidator,
        isSolvent: true,
        receiveShares: receiveShares
      })
    );
  }

  // When liquidation bonus is 0, effective collateral liquidated must be less than effective debt liquidated.
  // Full debt is liquidated, and amount of collateral liquidated must be computed based on the effective debt liquidated.
  function test_liquidationCall_scenario5() public {
    // Liquidation bonus: 0
    _updateMaxLiquidationBonus(spoke, _wethReserveId(spoke), 100_00);

    // Supply share price: 1.25
    _mockSupplySharePrice(hub1, wethAssetId, 12_500.25e6, 10_000e6);

    // The collateral and debt have the same price
    _mockReservePrice(spoke, _wethReserveId(spoke), 1e8);
    _mockReservePrice(spoke, _daiReserveId(spoke), 1e8);

    // Update WETH collateral factor to 80%
    _updateCollateralFactor(spoke, _wethReserveId(spoke), 80_00);

    // Collateral: 3 wei of USDX -> 2 share = 2.5 USDX
    _increaseCollateralSupply(spoke, _wethReserveId(spoke), 3, user);

    // Mock interest rate to 10%
    _mockInterestRateBps(10_00);

    // Borrow: 1 wei of DAI
    _increaseReserveDebt(spoke, _daiReserveId(spoke), 1, user);

    // Skip 1 year to increase drawn index
    skip(365 days);
    assertEq(hub1.getAssetDrawnIndex(daiAssetId), 1.1e27);

    // Increase DAI price by 101%
    _mockReservePriceByPercent(spoke, _daiReserveId(spoke), 201_00);

    // User is fully liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // User position before liquidation
    ISpoke.UserPosition memory userCollateralPositionBefore = spoke.getUserPosition(
      _wethReserveId(spoke),
      user
    );
    assertEq(userCollateralPositionBefore.suppliedShares, 2, 'User should have 2 shares of WETH');
    ISpoke.UserPosition memory userDebtPositionBefore = spoke.getUserPosition(
      _daiReserveId(spoke),
      user
    );
    assertEq(userDebtPositionBefore.drawnShares, 1, 'User should have 1 drawn share of DAI');
    assertEq(
      userDebtPositionBefore.premiumShares * 1.1e27 -
        userDebtPositionBefore.premiumOffsetRay.toUint256(),
      0.1e27,
      'User should have 0.1 premium'
    );

    // Perform liquidation
    // 1 drawn share of DAI is liquidated = 1.1 wei of DAI = 2.211 wei of USD = 2.211 wei of WETH = 1.7688 wei of WETH shares
    _checkedLiquidationCall(
      CheckedLiquidationCallParams({
        spoke: spoke,
        collateralReserveId: _wethReserveId(spoke),
        debtReserveId: _daiReserveId(spoke),
        user: user,
        debtToCover: type(uint256).max,
        liquidator: liquidator,
        isSolvent: true,
        receiveShares: false
      })
    );

    // User position after liquidation
    ISpoke.UserPosition memory userCollateralPositionAfter = spoke.getUserPosition(
      _wethReserveId(spoke),
      user
    );
    assertEq(
      userCollateralPositionAfter.suppliedShares,
      1,
      'User should have 1 share of WETH after liquidation'
    );
    ISpoke.UserPosition memory userDebtPositionAfter = spoke.getUserPosition(
      _daiReserveId(spoke),
      user
    );
    assertEq(
      userDebtPositionAfter.drawnShares,
      0,
      'User should have 0 drawn share of DAI after liquidation'
    );
    assertEq(
      userDebtPositionAfter.premiumShares,
      0,
      'User should have 0 premium share of DAI after liquidation'
    );
    assertEq(
      userDebtPositionAfter.premiumOffsetRay,
      0,
      'User should have 0 premium offset after liquidation'
    );
  }

  // When (at least) debtRayToTarget is liquidated, user should not be below target health factor even if debtRayToTarget
  // cannot be represented within the precision of the debt token but can be represented within the precision of the collateral token.
  function test_liquidationCall_scenario6() public {
    // set target health factor to 1
    _updateTargetHealthFactor(spoke, 1e18);

    // mock prices such that dust is not created
    _mockReservePrice(spoke, _usdxReserveId(spoke), 1000e14);
    _mockReservePrice(spoke, _wbtcReserveId(spoke), 500e17);
    _mockReservePrice(spoke, _usdyReserveId(spoke), 1000e27);

    // collateral configs
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 100_00);
    _updateMaxLiquidationBonus(spoke, _wbtcReserveId(spoke), 100_00);
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 70_00);
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 99_00);
    _updateCollateralRisk(spoke, _usdxReserveId(spoke), 0);
    _updateCollateralRisk(spoke, _wbtcReserveId(spoke), 0);

    // mock interest rate
    _mockInterestRateBps(50_00);

    // User collaterals: 20 wei of USDX, 3 wei of WBTC
    // User debt: 1 wei of USDY
    _increaseCollateralSupply(spoke, _usdxReserveId(spoke), 20, user);
    _increaseCollateralSupply(spoke, _wbtcReserveId(spoke), 3, user);
    _increaseReserveDebt(spoke, _usdyReserveId(spoke), 2, user);

    ISpoke.UserPosition memory usdxUserPosition = spoke.getUserPosition(
      _usdxReserveId(spoke),
      user
    );
    assertEq(
      usdxUserPosition.suppliedShares,
      20,
      'User should have 20 supplied shares of USDX before liquidation'
    );
    ISpoke.UserPosition memory usdyUserPosition = spoke.getUserPosition(
      _usdyReserveId(spoke),
      user
    );
    assertEq(
      usdyUserPosition.drawnShares,
      2,
      'User should have 2 drawn shares of USDY before liquidation'
    );

    // Skip 1 year to increase drawn index
    skip(365 days);
    assertEq(hub1.getAssetDrawnIndex(usdyAssetId), 1.5e27);

    // User is liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // Perform liquidation
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: _usdxReserveId(spoke),
      debtReserveId: _usdyReserveId(spoke),
      user: user,
      debtToCover: type(uint256).max,
      receiveShares: false
    });

    usdxUserPosition = spoke.getUserPosition(_usdxReserveId(spoke), user);
    assertEq(
      usdxUserPosition.suppliedShares,
      5,
      'User should have 5 supplied shares of USDX after liquidation'
    );
    usdyUserPosition = spoke.getUserPosition(_usdyReserveId(spoke), user);
    // check liquidation was partial. since debtToCover was max, it means that target should be reached.
    assertEq(
      usdyUserPosition.drawnShares,
      1,
      'User should have 1 drawn shares of USDY after liquidation'
    );

    // user should not be liquidatable anymore, which means that he cannot be under the target health factor
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: _wbtcReserveId(spoke),
      debtReserveId: _usdyReserveId(spoke),
      user: user,
      debtToCover: type(uint256).max,
      receiveShares: false
    });
  }

  // When (at least) debtRayToTarget is liquidated, user should not be below target health factor even if debtRayToTarget
  // cannot be represented within the precision of the debt token but can be represented within the precision of the collateral token.
  function test_liquidationCall_scenario7() public {
    // set target health factor to 1
    _updateTargetHealthFactor(spoke, 1e18);

    // mock prices such that dust is not created
    _mockReservePrice(spoke, _usdxReserveId(spoke), 1000e14);
    _mockReservePrice(spoke, _wbtcReserveId(spoke), 500e17);
    _mockReservePrice(spoke, _usdyReserveId(spoke), 1000e27);

    // collateral configs
    _updateMaxLiquidationBonus(spoke, _usdxReserveId(spoke), 100_00);
    _updateMaxLiquidationBonus(spoke, _wbtcReserveId(spoke), 100_00);
    _updateCollateralFactor(spoke, _usdxReserveId(spoke), 70_00);
    _updateCollateralFactor(spoke, _wbtcReserveId(spoke), 99_00);
    _updateCollateralRisk(spoke, _usdxReserveId(spoke), 50_00);
    _updateCollateralRisk(spoke, _wbtcReserveId(spoke), 50_00);

    // set interest rate
    _mockInterestRateBps(60_00);
    address randomUser = makeAddr('randomUser');

    // Skip 1 year to increase drawn index to 1.6
    _increaseCollateralSupply(spoke, _usdyReserveId(spoke), 2, randomUser);
    _increaseReserveDebt(spoke, _usdyReserveId(spoke), 1, randomUser);
    skip(365 days);
    assertEq(hub1.getAssetDrawnIndex(usdyAssetId), 1.6e27);

    // set interest rate
    _mockInterestRateBps(56_25);

    // User collaterals: 40 wei of USDX, 5 wei of WBTC
    // User debt: 2 wei of USDY
    _increaseCollateralSupply(spoke, _usdxReserveId(spoke), 40, user);
    _increaseCollateralSupply(spoke, _wbtcReserveId(spoke), 5, user);
    _increaseReserveDebt(spoke, _usdyReserveId(spoke), 2, user);

    ISpoke.UserPosition memory usdxUserPosition = spoke.getUserPosition(
      _usdxReserveId(spoke),
      user
    );
    assertEq(
      usdxUserPosition.suppliedShares,
      40,
      'User should have 40 supplied shares of USDX before liquidation'
    );
    ISpoke.UserPosition memory usdyUserPosition = spoke.getUserPosition(
      _usdyReserveId(spoke),
      user
    );
    assertEq(
      usdyUserPosition.drawnShares,
      2,
      'User should have 2 drawn shares of USDY before liquidation'
    );

    // Skip 1 year to increase drawn index to 2.5
    skip(365 days);
    assertEq(hub1.getAssetDrawnIndex(usdyAssetId), 2.5e27);

    // User is liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // Perform liquidation
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: _usdxReserveId(spoke),
      debtReserveId: _usdyReserveId(spoke),
      user: user,
      debtToCover: type(uint256).max,
      receiveShares: false
    });

    usdxUserPosition = spoke.getUserPosition(_usdxReserveId(spoke), user);
    assertEq(
      usdxUserPosition.suppliedShares,
      6,
      'User should have 6 supplied shares of USDX after liquidation'
    );
    usdyUserPosition = spoke.getUserPosition(_usdyReserveId(spoke), user);
    assertEq(
      usdyUserPosition.drawnShares,
      1,
      'User should have 1 drawn shares of USDY after liquidation'
    );

    // user should not be liquidatable anymore, which means that he cannot be under the target health factor
    vm.expectRevert(ISpoke.HealthFactorNotBelowThreshold.selector);
    vm.prank(liquidator);
    spoke.liquidationCall({
      collateralReserveId: _wbtcReserveId(spoke),
      debtReserveId: _usdyReserveId(spoke),
      user: user,
      debtToCover: type(uint256).max,
      receiveShares: false
    });
  }

  /// @dev a halted peripheral asset won't block a liquidation
  function test_scenario_halted_asset() public {
    uint256 collateralReserveId = _wethReserveId(spoke);
    uint256 debtReserveId = _daiReserveId(spoke);

    _increaseCollateralSupply(spoke, collateralReserveId, 10e18, user);
    // borrow usdx as peripheral debt asset not directly involved in liquidation
    _openSupplyPosition(spoke, _usdxReserveId(spoke), 100e6);
    Utils.borrow(spoke, _usdxReserveId(spoke), user, 100e6, user);
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.95e18);

    // set spoke halted
    IHub hub = _hub(spoke, _usdxReserveId(spoke));
    _updateSpokeHalted(hub, usdxAssetId, address(spoke), true);

    _openSupplyPosition(spoke, collateralReserveId, MAX_SUPPLY_AMOUNT);

    vm.expectCall(
      address(hub),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector, usdxAssetId)
    );

    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }

  /// @dev a halted peripheral asset won't block a liquidation with deficit
  function test_scenario_halted_asset_with_deficit() public {
    uint256 collateralReserveId = _wethReserveId(spoke);
    uint256 debtReserveId = _daiReserveId(spoke);

    _increaseCollateralSupply(spoke, collateralReserveId, 10e18, user);
    // borrow usdx as peripheral debt asset not directly involved in liquidation
    _openSupplyPosition(spoke, _usdxReserveId(spoke), 100e6);
    Utils.borrow(spoke, _usdxReserveId(spoke), user, 100e6, user);
    // make user unhealthy to result in deficit
    _makeUserLiquidatable(spoke, user, debtReserveId, 0.5e18);

    // set spoke halted
    IHub hub = _hub(spoke, _usdxReserveId(spoke));
    _updateSpokeHalted(hub, usdxAssetId, address(spoke), true);

    _openSupplyPosition(spoke, collateralReserveId, MAX_SUPPLY_AMOUNT);

    vm.expectCall(
      address(hub),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector, usdxAssetId)
    );

    vm.prank(liquidator);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, type(uint256).max, false);
  }
}
