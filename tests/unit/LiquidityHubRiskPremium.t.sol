// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

struct TestDrawAmountInput {
  uint256 spoke1;
  uint256 spoke2;
  uint256 spoke3;
}

struct TestRiskPremiumRadInput {
  uint256 spoke1;
  uint256 spoke2;
  uint256 spoke3;
}

struct TestDrawAmountAndRiskPremiumRadInput {
  TestDrawAmountInput drawAmount;
  TestRiskPremiumRadInput riskPremiumRad;
}

contract LiquidityHubRiskPremiumTest_Base is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // todo: move to base test after conflict resolution
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;

  uint256 daiAmount = 2000e18;
  uint256 wethAmount = 1e18;

  uint256 spoke1RiskPremiumRad = uint256(0.5e4).toRad();
  uint256 spoke2RiskPremiumRad = uint256(0.2e4).toRad();
  uint256 spoke3RiskPremiumRad = uint256(0.3e4).toRad();

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function _bound(
    TestDrawAmountAndRiskPremiumRadInput memory input,
    uint256 minDrawAmount,
    uint256 maxDrawAmount
  ) internal returns (TestDrawAmountAndRiskPremiumRadInput memory) {
    input.drawAmount.spoke1 = bound(input.drawAmount.spoke1, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke2 = bound(input.drawAmount.spoke2, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke3 = bound(input.drawAmount.spoke3, minDrawAmount, maxDrawAmount);

    uint256 maxRiskPremiumRad = uint256(PercentageMath.PERCENTAGE_FACTOR).toRad();
    input.riskPremiumRad.spoke1 = bound(input.riskPremiumRad.spoke1, 0, maxRiskPremiumRad);
    input.riskPremiumRad.spoke1 = bound(input.riskPremiumRad.spoke1, 0, maxRiskPremiumRad);
    input.riskPremiumRad.spoke1 = bound(input.riskPremiumRad.spoke1, 0, maxRiskPremiumRad);

    vm.assume(input.drawAmount.spoke1 + input.drawAmount.spoke2 + input.drawAmount.spoke2 != 0);

    return input;
  }
}

contract LiquidityHubRiskPremium_ConstantTimeAndRiskPremium is LiquidityHubRiskPremiumTest_Base {
  function test_riskPremiumOnNoDraw() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, 0); // since no drawn liquidity
  }

  function test_singleDrawSameAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 usdxDrawnAmount = daiAmount / 2;
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke2RiskPremiumRad);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke2RiskPremiumRad);
  }

  function test_multipleDrawSameAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 usdxDrawnAmount = daiAmount / 3;
    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke2RiskPremiumRad);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke2RiskPremiumRad);

    // spoke 3 draws
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke3RiskPremiumRad);

    uint256 totalBaseDebt = usdxDrawnAmount * 2;
    uint256 expectedRiskPremium = (usdxDrawnAmount *
      spoke2RiskPremiumRad +
      usdxDrawnAmount *
      spoke3RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    // spoke 1 draws remaining liquidity
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke1RiskPremiumRad);

    totalBaseDebt = usdxDrawnAmount * 3;
    expectedRiskPremium =
      (usdxDrawnAmount *
        spoke1RiskPremiumRad +
        usdxDrawnAmount *
        spoke2RiskPremiumRad +
        usdxDrawnAmount *
        spoke3RiskPremiumRad) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);
  }

  function test_multipleDrawMultipleAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, spoke1DrawAmount, spoke1RiskPremiumRad);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke1RiskPremiumRad);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, spoke2DrawAmount, spoke2RiskPremiumRad);

    totalBaseDebt += spoke2DrawAmount;
    uint256 expectedRiskPremium = (spoke1DrawAmount *
      spoke1RiskPremiumRad +
      spoke2DrawAmount *
      spoke2RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, spoke3DrawAmount, spoke3RiskPremiumRad);

    totalBaseDebt += spoke3DrawAmount;
    expectedRiskPremium =
      (spoke1DrawAmount *
        spoke1RiskPremiumRad +
        spoke2DrawAmount *
        spoke2RiskPremiumRad +
        spoke3DrawAmount *
        spoke3RiskPremiumRad) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);
  }

  function test_fuzzDrawAndAmount(TestDrawAmountAndRiskPremiumRadInput memory p) public {
    p = _bound({input: p, minDrawAmount: 0, maxDrawAmount: daiAmount});
    uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, totalToDraw, spoke1RiskPremiumRad, alice);

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke1, p.riskPremiumRad.spoke1);

    uint256 totalBaseDebt = p.drawAmount.spoke1;
    assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, p.riskPremiumRad.spoke1);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke2, p.riskPremiumRad.spoke2);

    totalBaseDebt += p.drawAmount.spoke2;
    uint256 expectedRiskPremium = (p.drawAmount.spoke1 *
      p.riskPremiumRad.spoke1 +
      p.drawAmount.spoke2 *
      p.riskPremiumRad.spoke2) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke1, p.riskPremiumRad.spoke3);

    totalBaseDebt += p.drawAmount.spoke1;
    expectedRiskPremium =
      (p.drawAmount.spoke1 *
        p.riskPremiumRad.spoke1 +
        p.drawAmount.spoke2 *
        p.riskPremiumRad.spoke2 +
        p.drawAmount.spoke1 *
        p.riskPremiumRad.spoke3) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);
  }
}
