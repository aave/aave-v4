// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/liquidation/Spoke.BabylonLiquidationCall.Base.t.sol';

/// @dev Babylon liquidation scenarios, mirroring the canonical `SpokeLiquidationCallScenariosTest`.
/// Canonical scenarios 1 and 2 are rederived as a single-collateral health factor decrease
/// scenario. Scenario 4 is dropped (the liquidator never receives shares), scenarios 6 and 7 are
/// dropped (no target health factor sizing) and scenario 8 is dropped (the liquidation fee is
/// never charged, so splitting liquidations cannot grief the treasury). Cap sizing, skipped debt
/// reserves and per debt reserve events are covered by the unit suite.
contract SpokeBabylonLiquidationCallScenariosTest is SpokeBabylonLiquidationCallBaseTest {
  using SafeCast for *;

  bytes4 internal constant BABYLON_LIQUIDATION_CALL_SELECTOR =
    bytes4(keccak256('liquidationCall(uint256[],uint256[],address,uint256)'));

  address public user = makeAddr('user');

  function setUp() public virtual override {
    super.setUp();

    _updateCollateralFactor(spoke4, _wethReserveId(spoke4), 80_00);
    _updateCollateralFactor(spoke4, _wbtcReserveId(spoke4), 70_00);
    _updateCollateralFactor(spoke4, _usdxReserveId(spoke4), 72_00);
    _updateCollateralFactor(spoke4, _daiReserveId(spoke4), 75_00);

    _updateCollateralRisk(spoke4, _wethReserveId(spoke4), 5_00);
    _updateCollateralRisk(spoke4, _wbtcReserveId(spoke4), 15_00);
    _updateCollateralRisk(spoke4, _usdxReserveId(spoke4), 10_00);
    _updateCollateralRisk(spoke4, _daiReserveId(spoke4), 12_00);

    _updateMaxLiquidationBonus(spoke4, _wethReserveId(spoke4), 105_00);
    _updateMaxLiquidationBonus(spoke4, _wbtcReserveId(spoke4), 103_00);
    _updateMaxLiquidationBonus(spoke4, _usdxReserveId(spoke4), 101_00);
    _updateMaxLiquidationBonus(spoke4, _daiReserveId(spoke4), 106_00);

    _updateLiquidationConfig(
      spoke4,
      ISpoke.LiquidationConfig({
        targetHealthFactor: _getTargetHealthFactor(spoke4),
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 100_00
      })
    );

    for (uint256 reserveId = 0; reserveId < spoke4.getReserveCount(); reserveId++) {
      _fundLiquidationManager(reserveId, MAX_SUPPLY_AMOUNT);
    }
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRemove() public {
    _setManagedCollateralReserve(_daiReserveId(spoke4));
    uint256 debtReserveId = _wethReserveId(spoke4);
    _increaseCollateralSupply(spoke4, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(babylonSpoke),
      BABYLON_LIQUIDATION_CALL_SELECTOR
    );

    vm.mockFunction(
      address(_hub(spoke4, collateralReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.remove.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(UINT256_MAX), user, UINT256_MAX);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRestore() public {
    _setManagedCollateralReserve(_daiReserveId(spoke4));
    uint256 debtReserveId = _wethReserveId(spoke4);
    _increaseCollateralSupply(spoke4, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(babylonSpoke),
      BABYLON_LIQUIDATION_CALL_SELECTOR
    );

    vm.mockFunction(
      address(_hub(spoke4, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.restore.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(UINT256_MAX), user, UINT256_MAX);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubRefreshPremium()
    public
  {
    _setManagedCollateralReserve(_daiReserveId(spoke4));
    uint256 debtReserveId = _wethReserveId(spoke4);
    _increaseCollateralSupply(spoke4, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.999e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(babylonSpoke),
      BABYLON_LIQUIDATION_CALL_SELECTOR
    );

    vm.mockFunction(
      address(_hub(spoke4, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector)
    );
    // a partial repayment leaves debt behind, so its premium is refreshed after the liquidation
    uint256 debtToCover = spoke4.getUserTotalDebt(debtReserveId, user) / 2;
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(debtToCover), user, UINT256_MAX);
  }

  function test_liquidationCall_revertsWith_ReentrancyGuardReentrantCall_hubReportDeficit() public {
    _setManagedCollateralReserve(_daiReserveId(spoke4));
    uint256 debtReserveId = _wethReserveId(spoke4);
    _increaseCollateralSupply(spoke4, collateralReserveId, 100000e18, user);
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.5e18);

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(babylonSpoke),
      BABYLON_LIQUIDATION_CALL_SELECTOR
    );

    vm.mockFunction(
      address(_hub(spoke4, debtReserveId)),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(UINT256_MAX), user, UINT256_MAX);
  }

  // User is solvent, but the health factor decreases after liquidation due to a high liquidation
  // bonus: with a single collateral, the decrease happens if and only if lb * cf > hf.
  function test_liquidationCall_scenario_healthFactorDecrease() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));
    // A high liquidation bonus will be applied
    _updateMaxLiquidationBonus(spoke4, _wethReserveId(spoke4), 124_00);

    // Drawn rates:
    //   - DAI: 3%
    vm.prank(address(hub1));
    irStrategy.setInterestRateData(
      _daiReserveId(spoke4),
      abi.encode(
        IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: 90_00,
          baseDrawnRate: 3_00,
          rateGrowthBeforeOptimal: 0,
          rateGrowthAfterOptimal: 0
        })
      )
    );

    // Collateral and debt composition
    //   - Collateral: 2 WETH ($4000)
    //   - Debt: 3150 DAI
    _increaseCollateralSupply(spoke4, _wethReserveId(spoke4), 2e18, user);
    _increaseReserveDebtNoCollateral(spoke4, _daiReserveId(spoke4), 3150e18, user);

    ISpoke.UserAccountData memory userAccountData = spoke4.getUserAccountData(user);

    // Health Factor: $4000 * 0.8 / $3150 = ~1.0158
    assertApproxEqAbs(
      userAccountData.healthFactor,
      1.0158e18,
      0.0001e18,
      'pre liquidation: health factor'
    );
    // Risk Premium: 5%
    assertEq(userAccountData.riskPremium, 5_00, 'pre liquidation: risk premium');

    skip(365 days);
    userAccountData = spoke4.getUserAccountData(user);

    // Debt after 1 year: $3150 * 1.03 + $3150 * 0.05 * 0.03 = ~$3249.2
    // Health Factor after 1 year: $4000 * 0.8 / $3249.2 = ~0.9848
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.9848e18,
      0.0001e18,
      'pre liquidation: health factor after 1 year'
    );

    // Liquidated amounts for a 2000 DAI cover:
    //   - Collateral: $2000 * 1.24 = $2480 = 1.24 WETH
    //   - Debt: 2000 DAI (premium first, then drawn)
    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveIds: _arr(_daiReserveId(spoke4)),
        debtToCoverAmounts: _arr(2000e18),
        user: user,
        maxCollateralToRemove: UINT256_MAX,
        isSolvent: true
      })
    );

    // Debt left after liquidation: 3249.2 - 2000 = 1249.2 DAI (all drawn)
    assertApproxEqAbs(
      _getUserDebt(spoke4, user, _daiReserveId(spoke4)).drawnDebt,
      1249.2e18,
      0.1e18,
      'post liquidation: drawn debt left'
    );
    assertApproxEqAbs(
      _getUserDebt(spoke4, user, _daiReserveId(spoke4)).premiumDebt,
      0,
      2,
      'post liquidation: premium debt left'
    );
    // Health Factor after liquidation: ($4000 - $2480) * 0.8 / $1249.2 = ~0.9734
    // The health factor decreased: lb * cf = 1.24 * 0.8 = 0.992 > 0.9848
    userAccountData = spoke4.getUserAccountData(user);
    assertApproxEqAbs(
      userAccountData.healthFactor,
      0.9734e18,
      0.0001e18,
      'post liquidation: health factor'
    );
    // Risk Premium after liquidation: 5% over the single collateral
    assertEq(userAccountData.riskPremium, 5_00, 'post liquidation: risk premium');
  }

  // Liquidated collateral is between 0 and 1 wei. It is rounded down and hub.remove is skipped to avoid reverting.
  function test_liquidationCall_scenario3() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));
    // Liquidation bonus: 0
    _updateMaxLiquidationBonus(spoke4, _wethReserveId(spoke4), 100_00);

    // The collateral has a price 100 times higher than the debt
    _mockReservePrice({spoke: spoke4, reserveId: _wethReserveId(spoke4), price: 100e8});
    _mockReservePrice({spoke: spoke4, reserveId: _daiReserveId(spoke4), price: 1e8});

    // Collateral: 1 wei of WETH
    _increaseCollateralSupply(spoke4, _wethReserveId(spoke4), 1, user);

    // Max borrow: 79 wei of DAI (collateral factor of WETH is 80%)
    assertEq(_getCollateralFactor(spoke4, _wethReserveId(spoke4)), 80_00);
    _increaseReserveDebtNoCollateral(spoke4, _daiReserveId(spoke4), 79, user);

    // Decrease WETH price by 10% to make user unhealthy
    _mockReservePriceByPercent({
      spoke: spoke4,
      reserveId: _wethReserveId(spoke4),
      percentage: 90_00
    });

    // User is liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke4.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // Perform liquidation
    // Liquidated amounts:
    //   - Collateral: 79 * 1 / 90 = 0 rounded down (hub call will be skipped, otherwise liquidation would revert)
    //   - Debt: 79 wei of DAI
    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveIds: _arr(_daiReserveId(spoke4)),
        debtToCoverAmounts: _arr(UINT256_MAX),
        user: user,
        maxCollateralToRemove: UINT256_MAX,
        isSolvent: true
      })
    );

    assertEq(
      spoke4.getUserSuppliedAssets(_wethReserveId(spoke4), user),
      1,
      'Collateral should be 1'
    );
    assertEq(spoke4.getUserTotalDebt(_daiReserveId(spoke4), user), 0, 'Debt should be 0');
    assertEq(
      _hub(spoke4, _daiReserveId(spoke4)).getAssetDeficitRay(
        _reserveAssetId(spoke4, _daiReserveId(spoke4))
      ),
      0,
      'Deficit should be 0'
    );
  }

  // When liquidation bonus is 0, effective collateral liquidated must be less than effective debt liquidated.
  // Full debt is liquidated, and amount of collateral liquidated must be computed based on the effective debt liquidated.
  // The engine requires a supply share price of one, so the call is asserted directly.
  function test_liquidationCall_scenario5() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));
    // Liquidation bonus: 0
    _updateMaxLiquidationBonus(spoke4, _wethReserveId(spoke4), 100_00);

    // Supply share price: 1.25
    _mockSupplySharePrice({
      hub: hub1,
      assetId: wethAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke4)
    });

    // The collateral and debt have the same price
    _mockReservePrice({spoke: spoke4, reserveId: _wethReserveId(spoke4), price: 1e8});
    _mockReservePrice({spoke: spoke4, reserveId: _daiReserveId(spoke4), price: 1e8});

    // Collateral: 3 wei of WETH -> 2 shares = 2.5 WETH
    _increaseCollateralSupply(spoke4, _wethReserveId(spoke4), 3, user);

    // Mock drawn rate to 10%
    _mockDrawnRateBps({irStrategy: address(irStrategy), drawnRateBps: 10_00});

    // Borrow: 1 wei of DAI
    _increaseReserveDebtNoCollateral(spoke4, _daiReserveId(spoke4), 1, user);

    // Skip 1 year to increase drawn index
    skip(365 days);
    assertEq(hub1.getAssetDrawnIndex(daiAssetId), 1.1e27);

    // Increase DAI price by 101%
    _mockReservePriceByPercent({
      spoke: spoke4,
      reserveId: _daiReserveId(spoke4),
      percentage: 201_00
    });

    // User is fully liquidatable
    ISpoke.UserAccountData memory userAccountData = spoke4.getUserAccountData(user);
    assertLe(userAccountData.healthFactor, 1e18, 'User should be unhealthy');

    // User position before liquidation
    ISpoke.UserPosition memory userCollateralPositionBefore = spoke4.getUserPosition(
      _wethReserveId(spoke4),
      user
    );
    assertEq(userCollateralPositionBefore.suppliedShares, 2, 'User should have 2 shares of WETH');
    ISpoke.UserPosition memory userDebtPositionBefore = spoke4.getUserPosition(
      _daiReserveId(spoke4),
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
    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(_daiReserveId(spoke4)), _arr(UINT256_MAX), user, UINT256_MAX);

    // User position after liquidation
    ISpoke.UserPosition memory userCollateralPositionAfter = spoke4.getUserPosition(
      _wethReserveId(spoke4),
      user
    );
    assertEq(
      userCollateralPositionAfter.suppliedShares,
      1,
      'User should have 1 share of WETH after liquidation'
    );
    ISpoke.UserPosition memory userDebtPositionAfter = spoke4.getUserPosition(
      _daiReserveId(spoke4),
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

  // A full multi-debt liquidation consuming all collateral reports deficit on every debt reserve.
  function test_liquidationCall_scenario_multiDebtDeficit() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));

    // Collateral: 1 WETH ($2000); Debts: 500 USDX and DAI debt pushing the health factor to 0.5
    _increaseCollateralSupply(spoke4, _wethReserveId(spoke4), 1e18, user);
    _increaseReserveDebtNoCollateral(spoke4, _usdxReserveId(spoke4), 500e6, user);
    _makeUserLiquidatable(spoke4, user, _daiReserveId(spoke4), 0.5e18);

    _checkedBabylonLiquidationCall(
      CheckedBabylonLiquidationCallParams({
        debtReserveIds: _arr(_daiReserveId(spoke4), _usdxReserveId(spoke4)),
        debtToCoverAmounts: _arr(UINT256_MAX, UINT256_MAX),
        user: user,
        maxCollateralToRemove: UINT256_MAX,
        isSolvent: false
      })
    );

    // the collateral is fully consumed and the remaining debt is written off as deficit
    assertEq(
      spoke4.getUserSuppliedShares(_wethReserveId(spoke4), user),
      0,
      'collateral fully removed'
    );
    assertEq(spoke4.getUserTotalDebt(_daiReserveId(spoke4), user), 0, 'dai debt cleared');
    assertEq(spoke4.getUserTotalDebt(_usdxReserveId(spoke4), user), 0, 'usdx debt cleared');
    assertGt(
      _hub(spoke4, _daiReserveId(spoke4)).getAssetDeficitRay(
        _reserveAssetId(spoke4, _daiReserveId(spoke4))
      ),
      0,
      'dai deficit reported'
    );
  }

  /// @dev a halted peripheral asset won't block a liquidation
  function test_scenario_halted_asset() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));
    uint256 debtReserveId = _daiReserveId(spoke4);

    _increaseCollateralSupply(spoke4, collateralReserveId, 10e18, user);
    // borrow usdx as peripheral debt asset not directly involved in liquidation
    _openSupplyPositionNoCollateral(spoke4, _usdxReserveId(spoke4), 100e6);
    SpokeActions.borrow({
      spoke: spoke4,
      reserveId: _usdxReserveId(spoke4),
      caller: user,
      amount: 100e6,
      onBehalfOf: user
    });
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.95e18);

    // set spoke halted
    IHub hub = _hub(spoke4, _usdxReserveId(spoke4));
    _updateSpokeHalted(hub, usdxAssetId, address(spoke4), true);

    _openSupplyPosition(spoke4, collateralReserveId, MAX_SUPPLY_AMOUNT);

    vm.expectCall(
      address(hub),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector, usdxAssetId)
    );

    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(UINT256_MAX), user, UINT256_MAX);
  }

  /// @dev a halted peripheral asset won't block a liquidation with deficit
  function test_scenario_halted_asset_with_deficit() public {
    _setManagedCollateralReserve(_wethReserveId(spoke4));
    uint256 debtReserveId = _daiReserveId(spoke4);

    _increaseCollateralSupply(spoke4, collateralReserveId, 10e18, user);
    // borrow usdx as peripheral debt asset not directly involved in liquidation
    _openSupplyPositionNoCollateral(spoke4, _usdxReserveId(spoke4), 100e6);
    SpokeActions.borrow({
      spoke: spoke4,
      reserveId: _usdxReserveId(spoke4),
      caller: user,
      amount: 100e6,
      onBehalfOf: user
    });
    // make user unhealthy to result in deficit
    _makeUserLiquidatable(spoke4, user, debtReserveId, 0.5e18);

    // set spoke halted
    IHub hub = _hub(spoke4, _usdxReserveId(spoke4));
    _updateSpokeHalted(hub, usdxAssetId, address(spoke4), true);

    _openSupplyPosition(spoke4, collateralReserveId, MAX_SUPPLY_AMOUNT);

    vm.expectCall(
      address(hub),
      abi.encodeWithSelector(IHubBase.reportDeficit.selector, usdxAssetId)
    );

    vm.prank(liquidationManager);
    babylonSpoke.liquidationCall(_arr(debtReserveId), _arr(UINT256_MAX), user, UINT256_MAX);
  }
}
