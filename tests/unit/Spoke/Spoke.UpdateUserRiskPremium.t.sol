// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUserRiskPremiumUpdate is SpokeBase {
  uint256 internal riskPremiumBefore;

  function setUp() public override {
    super.setUp();

    _openSupplyPosition(spoke1, _daiReserveId(spoke1), 2500e18);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice); // 2k usd
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 2000e6, alice); // 2k usd
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 2500e18, alice);

    riskPremiumBefore = spoke1.getUserRiskPremium(alice);
    assertEq(riskPremiumBefore, _calculateExpectedUserRP(alice, spoke1));

    assertLt(
      _getCollateralRisk(spoke1, _wethReserveId(spoke1)),
      _getCollateralRisk(spoke1, _usdxReserveId(spoke1))
    );
  }

  function test_updateUserRiskPremium_on_rpDecrease(address caller) public {
    // double weth price, decreasing user rp since it's the less risky collateral
    _mockReservePriceByPercent(spoke1, _wethReserveId(spoke1), 100_00);

    uint256 riskPremiumAfter = spoke1.getUserRiskPremium(alice);
    assertEq(riskPremiumAfter, _calculateExpectedUserRP(alice, spoke1));
    assertLe(riskPremiumAfter, riskPremiumBefore);

    bool hasPermission = _hasRole(
      IAccessManager(spoke1.authority()),
      Roles.USER_POSITION_UPDATER_ROLE,
      caller
    );
    if (caller != alice && !hasPermission) {
      vm.expectRevert(
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.UserRiskPremiumUpdate(alice, riskPremiumAfter);
    }
    vm.prank(caller);
    spoke1.updateUserRiskPremium(alice);
  }

  function test_updateUserRiskPremium_on_rpIncrease(address caller) public {
    // half weth price, increasing user rp since it's the less risky collateral
    _mockReservePriceByPercent(spoke1, _wethReserveId(spoke1), 50_00);

    uint256 riskPremiumAfter = spoke1.getUserRiskPremium(alice);
    assertEq(riskPremiumAfter, _calculateExpectedUserRP(alice, spoke1));
    assertGt(riskPremiumAfter, riskPremiumBefore);

    bool hasPermission = _hasRole(
      IAccessManager(spoke1.authority()),
      Roles.USER_POSITION_UPDATER_ROLE,
      caller
    );
    if (caller != alice && !hasPermission) {
      vm.expectRevert(
        abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, caller)
      );
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.UserRiskPremiumUpdate(alice, riskPremiumAfter);
    }
    vm.prank(caller);
    spoke1.updateUserRiskPremium(alice);
  }
}
