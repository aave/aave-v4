// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUpdateUserRiskPremiumTest is SpokeBase {
  function test_updateUserRiskPremium_revertsWith_ReentrancyGuardReentrantCall() public {
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 1000e18,
      onBehalfOf: bob
    });

    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 100e18,
      onBehalfOf: bob
    });

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.updateUserRiskPremium.selector
    );

    // reentrant hub.refreshPremium call
    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.refreshPremium.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.updateUserRiskPremium(bob);
  }
}
