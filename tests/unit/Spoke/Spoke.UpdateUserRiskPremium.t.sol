// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeUpdateUserRiskPremium is SpokeBase {
  function test_updateUserRiskPremium_on_rpIncrease(address caller) public {
    _deployLiquidity(spoke1, _daiReserveId(spoke1), 2500e18);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 1e18, alice); // 2k usd
    Utils.supplyCollateral(spoke1, _usdxReserveId(spoke1), alice, 1000e6, alice); // 1k usd
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 2200e18, alice);

    uint256 riskPremiumBefore = spoke1.getUserRiskPremium(alice);
    assertEq(riskPremiumBefore, _calculateExpectedUserRP(alice, spoke1));

    assertLt(
      spoke1.getLiquidityPremium(_wethReserveId(spoke1)),
      spoke1.getLiquidityPremium(_usdxReserveId(spoke1))
    );
    // half weth price, increasing user rp since it's the less risky collateral
    setNewPrice(wethAssetId, 50_00);

    uint256 riskPremiumAfter = spoke1.getUserRiskPremium(alice);
    assertEq(riskPremiumAfter, _calculateExpectedUserRP(alice, spoke1));

    assertGt(riskPremiumAfter, riskPremiumBefore);

    if (caller != alice) {
      vm.expectRevert(ISpoke.Unauthorized.selector);
    } else {
      vm.expectEmit(address(spoke1));
      emit ISpoke.UserRiskPremiumUpdate(alice, riskPremiumAfter);
    }
    vm.prank(caller);
    spoke1.updateUserRiskPremium(alice);
  }
}
