// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract LiquidityHubInterestRateTest is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();
  }

  function test_getInterestRate_NoActionTaken() public {
    vm.skip(true, 'pending refactor');

    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // assertEq(borrowRate, 0);
  }

  function test_getInterestRate_Supply() public {
    vm.skip(true, 'pending refactor');

    // vm.startPrank(address(spoke1));
    // DataTypes.SpokeData memory test = hub.getSpoke(daiAssetId, address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // // No change to risk premium, so borrow rate is just the base rate
    // assertEq(_getBaseBorrowRate(daiAssetId), _getBorrowRate(daiAssetId));
    // vm.stopPrank();
  }

  function test_getInterestRate_Borrow() public {
    vm.skip(true, 'pending refactor');

    // // Spoke 1's first borrow should adjust the overall borrow rate with a risk premium of 10%
    // uint32 newRiskPremium = 10_00;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // vm.stopPrank();
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(newRiskPremium));
  }

  function test_getInterestRate_fuzz_Borrow(uint32 newRiskPremium) public {
    vm.skip(true, 'pending refactor');

    // newRiskPremium %= MAX_RISK_PREMIUM_BPS;
    // // Spoke 1's first borrow should set the overall borrow rate
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // vm.stopPrank();
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));
  }

  function test_getInterestRate_BorrowAndSupply() public {
    vm.skip(true, 'pending refactor');

    // uint32 newRiskPremium = 10_00;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));

    // // Now if we supply again, passing same risk premium, RP doesn't update
    // hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));
    // vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowAndSupply(uint32 newRiskPremium) public {
    vm.skip(true, 'pending refactor');

    // newRiskPremium %= MAX_RISK_PREMIUM_BPS;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));

    // // Now if we supply again, passing same risk premium, RP doesn't update
    // hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));
    // vm.stopPrank();
  }

  function test_getInterestRate_BorrowTwice() public {
    vm.skip(true, 'pending refactor');

    // uint32 newRiskPremium = 10_00;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));

    // // New risk premium from same spoke should replace avg risk premium
    // uint32 newRiskPremium2 = 20_00;
    // hub.draw(daiAssetId, 100e18, newRiskPremium2, address(spoke1));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(newRiskPremium2));
    // vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowTwice(uint32 newRiskPremium) public {
    vm.skip(true, 'pending refactor');

    // newRiskPremium %= MAX_RISK_PREMIUM_BPS;
    // uint32 firstRiskPremium = 10_00;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, firstRiskPremium, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(firstRiskPremium));

    // // New risk premium from same spoke should replace avg risk premium
    // hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + (baseBorrowRate.percentMul(newRiskPremium)));
    // vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokes() public {
    vm.skip(true, 'pending refactor');

    // uint32 rpSpoke1 = 10_00;
    // uint32 rpSpoke2 = 20_00;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, rpSpoke1, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(rpSpoke1));
    // vm.stopPrank();

    // // Next spoke risk premium should be averaged with the first
    // vm.startPrank(address(spoke2));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    // hub.draw(daiAssetId, 100e18, rpSpoke2, address(spoke2));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul((rpSpoke1 + rpSpoke2) / 2));
    // vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokes(uint32 rpSpoke1, uint32 rpSpoke2) public {
    vm.skip(true, 'pending refactor');

    // rpSpoke1 %= MAX_RISK_PREMIUM_BPS;
    // rpSpoke2 %= MAX_RISK_PREMIUM_BPS;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, 100e18, rpSpoke1, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(rpSpoke1));
    // vm.stopPrank();

    // // Next spoke risk premium should be averaged with the first
    // vm.startPrank(address(spoke2));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    // hub.draw(daiAssetId, 100e18, rpSpoke2, address(spoke2));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul((rpSpoke1 + rpSpoke2) / 2));
    // vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokesDiffWeights() public {
    vm.skip(true, 'pending refactor');

    // uint32 rpSpoke1 = 10_00;
    // uint32 rpSpoke2 = 20_00;
    // uint256 drawSpoke1 = 100e18;
    // uint256 drawSpoke2 = 200e18;
    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(rpSpoke1));
    // vm.stopPrank();

    // // Next spoke risk premium should be averaged with the first
    // vm.startPrank(address(spoke2));
    // hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    // hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    // assertEq(calcRp, hub.getAsset(daiAssetId).riskPremium.derayify());
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(calcRp));
    // vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokesDiffWeights(
    uint32 rpSpoke1,
    uint256 drawSpoke1,
    uint256 supplySpoke1,
    uint32 rpSpoke2,
    uint256 drawSpoke2,
    uint256 supplySpoke2
  ) public {
    vm.skip(true, 'pending refactor');

    // rpSpoke1 %= MAX_RISK_PREMIUM_BPS;
    // supplySpoke1 = bound(supplySpoke1, 2, 1e30);
    // drawSpoke1 = bound(drawSpoke1, 1, supplySpoke1 / 2);

    // rpSpoke2 %= MAX_RISK_PREMIUM_BPS;
    // supplySpoke2 = bound(supplySpoke2, 2, 1e30);
    // drawSpoke2 = bound(drawSpoke2, 1, supplySpoke2 / 2);

    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, supplySpoke1, 0, address(spoke1));
    // hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(rpSpoke1));
    // vm.stopPrank();

    // // Next spoke risk premium should be averaged with the first
    // vm.startPrank(address(spoke2));
    // hub.supply(daiAssetId, supplySpoke2, 0, address(spoke2));
    // hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    // borrowRate = _getBorrowRate(daiAssetId);
    // baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(calcRp));
    // vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawThreeSpokesDiffWeights(
    uint32 rpSpoke1,
    uint256 drawSpoke1,
    uint32 rpSpoke2,
    uint256 drawSpoke2,
    uint32 rpSpoke3,
    uint256 drawSpoke3
  ) public {
    vm.skip(true, 'pending refactor');

    // rpSpoke1 %= MAX_RISK_PREMIUM_BPS;
    // drawSpoke1 = bound(drawSpoke1, 1, 1e30);

    // rpSpoke2 %= MAX_RISK_PREMIUM_BPS;
    // drawSpoke2 = bound(drawSpoke2, 1, 1e30);

    // rpSpoke3 %= MAX_RISK_PREMIUM_BPS;
    // drawSpoke3 = bound(drawSpoke3, 1, 1e30);

    // vm.startPrank(address(spoke1));
    // hub.supply(daiAssetId, 2e30, 0, address(spoke1));
    // hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    // vm.stopPrank();

    // vm.startPrank(address(spoke2));
    // hub.supply(daiAssetId, 2e30, 0, address(spoke2));
    // hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    // vm.stopPrank();

    // vm.startPrank(address(spoke3));
    // hub.supply(daiAssetId, 2e30, 0, address(spoke3));
    // hub.draw(daiAssetId, drawSpoke3, rpSpoke3, address(spoke3));
    // vm.stopPrank();

    // uint256 borrowRate = _getBorrowRate(daiAssetId);
    // uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    // uint256 newRp = hub.getAsset(daiAssetId).riskPremium.derayify();
    // uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2 + rpSpoke3 * drawSpoke3) /
    //   (drawSpoke1 + drawSpoke2 + drawSpoke3);

    // assertApproxEqAbs(calcRp, newRp, 1);
    // assertEq(borrowRate, baseBorrowRate + baseBorrowRate.percentMul(newRp));
  }
  function _getBaseBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getBaseInterestRate(assetId);
  }

  function _getBorrowRate(uint256 assetId) internal view returns (uint256) {
    revert('not needed anymore, rm me');
  }
}
