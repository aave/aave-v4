// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeZeroPremiumDeltaTest is SpokeBase {
  using SafeCast for uint256;

  DataTypes.PremiumDelta public zeroPremiumDelta;
  function setUp() public override {
    super.setUp();
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _wethReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _wbtcReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _usdyReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    zeroPremiumDelta = DataTypes.PremiumDelta(0, 0, 0);
  }

  /// @dev Updating risk premium without change in accrued premium causes 0 premium delta
  function test_updateRiskPremium() public {
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 50e6, alice);

    assertEq(spoke1.getUserRiskPremium(alice), _getCollateralRisk(spoke1, _daiReserveId(spoke1)));

    // Updating risk premium without change in accrued premium, op skipped
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.refreshPremium, (_usdxReserveId(spoke1), zeroPremiumDelta)),
      0
    );
    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    assertEq(spoke1.getUserRiskPremium(alice), _getCollateralRisk(spoke1, _daiReserveId(spoke1)));
  }

  /// @dev Updating risk premium with change in accrued premium causes non-zero premium delta
  function test_updateRiskPremium_accruedPremium() public {
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 50e6, alice);

    (, uint256 accruedPremium) = spoke1.getUserDebt(_usdxReserveId(spoke1), alice);
    uint256 userRiskPremium = spoke1.getUserRiskPremium(alice);
    skip(123 days);
    (, uint256 accruedPremiumAfter) = spoke1.getUserDebt(_usdxReserveId(spoke1), alice);
    uint256 userRiskPremiumAfter = spoke1.getUserRiskPremium(alice);

    assertGt(accruedPremiumAfter, accruedPremium);
    // user risk premium remains the same, but Premium Delta is non zero
    assertEq(userRiskPremiumAfter, userRiskPremium);

    // Updating risk premium without change in accrued premium, op not skipped
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 1);
    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);
  }

  /// @dev Actions with zero collateral risk collateral causes zero premium delta
  function test_zeroCollateralRisk() public {
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    assertEq(spoke1.getUserRiskPremium(alice), 0);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 0);

    // first borrow, 0 rp -> 0 rp
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 50e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), 0);

    // second borrow, 0 rp -> 0 rp
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 10e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), 0);

    // repay, 0 rp -> 0 rp
    Utils.repay(spoke1, _usdxReserveId(spoke1), alice, 20e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), 0);

    // withdraw, 0 rp -> 0 rp
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, 10e18, alice);
    assertEq(spoke1.getUserRiskPremium(alice), 0);
  }

  function test_nonZeroCollateralRisk() public {
    uint256 collateralRisk = 10_00;
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), collateralRisk.toUint24());
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector));

    // first borrow, 0 rp -> non zero rp
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 50e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.refreshPremium, (_usdxReserveId(spoke1), zeroPremiumDelta)),
      0
    );

    // second borrow, non zero rp stays the same
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 10e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);

    // repay, 0 rp -> 0 rp
    Utils.repay(spoke1, _usdxReserveId(spoke1), alice, 20e6, alice);
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);

    // withdraw, 0 rp -> 0 rp
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, 10e18, alice);
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);
  }

  function test_zeroCollateralRisk_multiReserves() public {
    _updateCollateralRisk(spoke1, _daiReserveId(spoke1), 0);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice); // $1k
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), 10_00);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice); // $2k

    // first borrow covered by 0 CF asset, op skipped
    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.refreshPremium, (_usdxReserveId(spoke1), zeroPremiumDelta)),
      0
    );
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice); // $1k
    assertEq(spoke1.getUserRiskPremium(alice), 0);

    // second borrow covered by non zero CF asset, op not skipped
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector));
    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 100e6, alice);
    assertGt(spoke1.getUserRiskPremium(alice), 0);
  }

  function test_multiDebtReserves() public {
    uint256 collateralRisk = 10_00;
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), collateralRisk.toUint24());
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice); // $2k

    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 100e6, alice); // $100
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);

    // only 1 op expected for dai; usdx is skipped
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 1);

    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice); // $100
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);
  }

  function test_multiDebtReserves_accrual() public {
    uint256 collateralRisk = 10_00;
    _updateCollateralRisk(spoke1, _wethReserveId(spoke1), collateralRisk.toUint24());
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice); // $2k

    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 100e6, alice); // $100
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);

    skip(123 days);

    // due to accrual, both borrowed reserves are refreshed
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 2);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice); // $100
    assertEq(spoke1.getUserRiskPremium(alice), collateralRisk);
  }

  function test_withdraw_excess() public {
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1_000_000e18, alice);

    Utils.borrow(spoke1, _usdxReserveId(spoke1), alice, 50e6, alice);
    Utils.borrow(spoke1, _usdyReserveId(spoke1), alice, 50e6, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), alice, 1e16, alice);
    Utils.borrow(spoke1, _wbtcReserveId(spoke1), alice, 1e4, alice);

    uint256 userRiskPremium = spoke1.getUserRiskPremium(alice);

    // all ops skipped
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.refreshPremium.selector), 0);
    // withdraw excess that doesnt change user rp
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, 10e18, alice);
    // user risk premium remains the same
    assertEq(spoke1.getUserRiskPremium(alice), userRiskPremium);
  }
}
