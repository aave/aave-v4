// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract LiquidityHubInterestRateTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();
  }

  function test_getInterestRate_NoActionTaken() public {
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    assertEq(borrowRate, 0);
  }

  function test_getInterestRate_Supply() public {
    vm.startPrank(address(spoke1));
    SpokeData memory test = hub.getSpoke(daiAssetId, address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    // No change to risk premium, so borrow rate is just the base rate
    assertEq(_getBaseBorrowRate(daiAssetId), _getBorrowRate(daiAssetId));
    vm.stopPrank();
  }

  function test_getInterestRate_Borrow() public {
    // Spoke 1's first borrow should adjust the overall borrow rate with a risk premium of 10%
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
  }

  function test_getInterestRate_fuzz_Borrow(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, MAX_BPS.bpsToRad());
    // Spoke 1's first borrow should set the overall borrow rate
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    vm.stopPrank();
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
  }

  function test_getInterestRate_BorrowAndSupply() public {
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowAndSupply(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, MAX_BPS.bpsToRad());
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // Now if we supply again, passing same risk premium, RP doesn't update
    hub.supply(daiAssetId, 1000e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_BorrowTwice() public {
    uint256 newRiskPremium = uint256(10_00).bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // New risk premium from same spoke should replace avg risk premium
    uint256 newRiskPremium2 = uint256(20_00).bpsToRad();
    hub.draw(daiAssetId, 100e18, newRiskPremium2, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium2.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_BorrowTwice(uint256 newRiskPremium) public {
    newRiskPremium = bound(newRiskPremium, 0, MAX_BPS.bpsToRad());
    uint256 firstRiskPremium = uint256(10_00).bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, firstRiskPremium, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (firstRiskPremium.radToRay().rayMul(baseBorrowRate)));

    // New risk premium from same spoke should replace avg risk premium
    hub.draw(daiAssetId, 100e18, newRiskPremium, address(spoke1));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (newRiskPremium.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokes() public {
    uint256 rpSpoke1 = uint256(10_00).bpsToRad();
    uint256 rpSpoke2 = uint256(20_00).bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, rpSpoke1, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, 100e18, rpSpoke2, address(spoke2));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(
      borrowRate,
      baseBorrowRate +
        ((rpSpoke1 + rpSpoke2).radToRay().rayMul(baseBorrowRate)).rayDiv(2 * WadRayMath.RAY)
    );
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokes(uint256 rpSpoke1, uint256 rpSpoke2) public {
    rpSpoke1 = bound(rpSpoke1, 0, MAX_BPS.bpsToRad());
    rpSpoke2 = bound(rpSpoke2, 0, MAX_BPS.bpsToRad());
    rpSpoke1 = rpSpoke1.bpsToRad();
    rpSpoke2 = rpSpoke2.bpsToRad();
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, 100e18, rpSpoke1, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, 100e18, rpSpoke2, address(spoke2));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(
      borrowRate,
      baseBorrowRate +
        (((rpSpoke1 + rpSpoke2).radToRay().rayMul(baseBorrowRate)).rayDiv(2 * WadRayMath.RAY))
    );
    vm.stopPrank();
  }

  function test_getInterestRate_DrawTwoSpokesDiffWeights() public {
    uint256 rpSpoke1 = uint256(10_00).bpsToRad();
    uint256 rpSpoke2 = uint256(20_00).bpsToRad();
    uint256 drawSpoke1 = 100e18;
    uint256 drawSpoke2 = 200e18;
    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke1));
    hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 1000e18, 0, address(spoke2));
    hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    assertEq(borrowRate, baseBorrowRate + (calcRp.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawTwoSpokesDiffWeights(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 supplySpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 supplySpoke2
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, MAX_BPS.bpsToRad());
    supplySpoke1 = bound(supplySpoke1, 2, 1e60);
    drawSpoke1 = bound(drawSpoke1, 1, supplySpoke1 / 2);

    rpSpoke2 = bound(rpSpoke2, 0, MAX_BPS.bpsToRad());
    supplySpoke2 = bound(supplySpoke2, 2, 1e60);
    drawSpoke2 = bound(drawSpoke2, 1, supplySpoke2 / 2);

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, supplySpoke1, 0, address(spoke1));
    hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    assertEq(borrowRate, baseBorrowRate + (rpSpoke1.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();

    // Next spoke risk premium should be averaged with the first
    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, supplySpoke2, 0, address(spoke2));
    hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    borrowRate = _getBorrowRate(daiAssetId);
    baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 calcRp = (rpSpoke1 * drawSpoke1 + rpSpoke2 * drawSpoke2) / (drawSpoke1 + drawSpoke2);
    assertEq(borrowRate, baseBorrowRate + (calcRp.radToRay().rayMul(baseBorrowRate)));
    vm.stopPrank();
  }

  function test_getInterestRate_fuzz_DrawThreeSpokesDiffWeights(
    uint256 rpSpoke1,
    uint256 drawSpoke1,
    uint256 rpSpoke2,
    uint256 drawSpoke2,
    uint256 rpSpoke3,
    uint256 drawSpoke3
  ) public {
    rpSpoke1 = bound(rpSpoke1, 0, MAX_BPS.bpsToRad());
    drawSpoke1 = bound(drawSpoke1, 1, 1e40);

    rpSpoke2 = bound(rpSpoke2, 0, MAX_BPS.bpsToRad());
    drawSpoke2 = bound(drawSpoke2, 1, 1e40);

    rpSpoke3 = bound(rpSpoke3, 0, MAX_BPS.bpsToRad());
    drawSpoke3 = bound(drawSpoke3, 1, 1e40);

    vm.startPrank(address(spoke1));
    hub.supply(daiAssetId, 2e40, 0, address(spoke1));
    hub.draw(daiAssetId, drawSpoke1, rpSpoke1, address(spoke1));
    vm.stopPrank();

    vm.startPrank(address(spoke2));
    hub.supply(daiAssetId, 2e40, 0, address(spoke2));
    hub.draw(daiAssetId, drawSpoke2, rpSpoke2, address(spoke2));
    vm.stopPrank();

    vm.startPrank(address(spoke3));
    hub.supply(daiAssetId, 2e40, 0, address(spoke3));
    hub.draw(daiAssetId, drawSpoke3, rpSpoke3, address(spoke3));
    vm.stopPrank();

    uint256 borrowRate = _getBorrowRate(daiAssetId);
    uint256 baseBorrowRate = _getBaseBorrowRate(daiAssetId);
    uint256 newRp = hub.getAsset(daiAssetId).riskPremiumRad;
    assertEq(borrowRate, baseBorrowRate + (newRp.radToRay().rayMul(baseBorrowRate)));
  }
  function _getBaseBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getBaseInterestRate(assetId);
  }

  function _getBorrowRate(uint256 assetId) internal view returns (uint256) {
    return hub.getInterestRate(assetId);
  }
}
