// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';

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

  uint256 daiAmount = 2000e18;
  uint256 wethAmount = 1e18;

  uint256 spoke1RiskPremiumRad = uint256(50_00).bpsToRad();
  uint256 spoke2RiskPremiumRad = uint256(20_00).bpsToRad();
  uint256 spoke3RiskPremiumRad = uint256(30_00).bpsToRad();

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function bound(
    TestDrawAmountAndRiskPremiumRadInput memory input,
    uint256 minDrawAmount,
    uint256 maxDrawAmount
  ) internal pure returns (TestDrawAmountAndRiskPremiumRadInput memory) {
    input.drawAmount.spoke1 = bound(input.drawAmount.spoke1, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke2 = bound(input.drawAmount.spoke2, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke3 = bound(input.drawAmount.spoke3, minDrawAmount, maxDrawAmount);

    uint256 maxRiskPremiumRad = PercentageMath.PERCENTAGE_FACTOR.bpsToRad();
    input.riskPremiumRad.spoke1 = bound(input.riskPremiumRad.spoke1, 0, maxRiskPremiumRad);
    input.riskPremiumRad.spoke2 = bound(input.riskPremiumRad.spoke2, 0, maxRiskPremiumRad);
    input.riskPremiumRad.spoke3 = bound(input.riskPremiumRad.spoke3, 0, maxRiskPremiumRad);

    vm.assume(input.drawAmount.spoke1 + input.drawAmount.spoke2 + input.drawAmount.spoke3 != 0);

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
    hub.draw(daiAssetId, usdxDrawnAmount, spoke2RiskPremiumRad, alice);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke2RiskPremiumRad);
  }

  function test_multipleDrawSameAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 usdxDrawnAmount = daiAmount / 3;
    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, usdxDrawnAmount, spoke2RiskPremiumRad, alice);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke2RiskPremiumRad);

    // spoke 3 draws
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, usdxDrawnAmount, spoke3RiskPremiumRad, alice);

    uint256 totalBaseDebt = usdxDrawnAmount * 2;
    uint256 expectedRiskPremium = (usdxDrawnAmount *
      spoke2RiskPremiumRad +
      usdxDrawnAmount *
      spoke3RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    // spoke 1 draws remaining liquidity
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, usdxDrawnAmount, spoke1RiskPremiumRad, alice);

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
    hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremiumRad, alice);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke1RiskPremiumRad);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremiumRad, alice);

    totalBaseDebt += spoke2DrawAmount;
    uint256 expectedRiskPremium = (spoke1DrawAmount *
      spoke1RiskPremiumRad +
      spoke2DrawAmount *
      spoke2RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremiumRad, alice);

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

  function test_fuzzDrawAndPremium(TestDrawAmountAndRiskPremiumRadInput memory p) public {
    p = bound({input: p, minDrawAmount: 1, maxDrawAmount: daiAmount});
    uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, totalToDraw, spoke1RiskPremiumRad, alice);

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, p.drawAmount.spoke1, p.riskPremiumRad.spoke1, alice);

    uint256 totalBaseDebt = p.drawAmount.spoke1;
    assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, p.riskPremiumRad.spoke1);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, p.drawAmount.spoke2, p.riskPremiumRad.spoke2, alice);

    totalBaseDebt += p.drawAmount.spoke2;
    uint256 expectedRiskPremium = (p.drawAmount.spoke1 *
      p.riskPremiumRad.spoke1 +
      p.drawAmount.spoke2 *
      p.riskPremiumRad.spoke2) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 1);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, p.drawAmount.spoke3, p.riskPremiumRad.spoke3, alice);

    totalBaseDebt += p.drawAmount.spoke3;
    expectedRiskPremium =
      (p.drawAmount.spoke1 *
        p.riskPremiumRad.spoke1 +
        p.drawAmount.spoke2 *
        p.riskPremiumRad.spoke2 +
        p.drawAmount.spoke3 *
        p.riskPremiumRad.spoke3) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 1);
  }
}

contract LiquidityHubRiskPremium_VariableTimeAndConstantRiskPremium is
  LiquidityHubRiskPremiumTest_Base
{
  using WadRayMath for uint256;

  function test_fuzzMultipleDrawWhileAccruingInterest(
    uint256 timeToSkip,
    uint256 baseBorrowRate
  ) public {
    timeToSkip = bound(timeToSkip, 1 days, 10_000 days);
    baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremiumRad, alice);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke1RiskPremiumRad);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremiumRad, alice); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
      spoke1RiskPremiumRad +
      spoke2DrawAmount *
      spoke2RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    spoke1DrawAmount += spoke1AccruedDebt;
    spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremiumRad, alice);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    expectedRiskPremium =
      ((spoke1DrawAmount + spoke1AccruedDebt) *
        spoke1RiskPremiumRad +
        (spoke2DrawAmount + spoke2AccruedDebt) *
        spoke2RiskPremiumRad +
        spoke3DrawAmount *
        spoke3RiskPremiumRad) /
      totalBaseDebt;
    assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 1);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 1);
  }

  function test_multipleDrawWhileAccruingInterest() public {
    test_fuzzMultipleDrawWhileAccruingInterest({
      timeToSkip: 365 days,
      baseBorrowRate: uint256(15_00).bpsToRay()
    });
  }

  function test_multipleDrawWhileAccruingInterestWithChangingRate() public {
    uint256 timeToSkip = 365 days; // todo fuzz this and rate
    uint256 rate = uint256(15_00).bpsToRay();
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRad, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremiumRad, alice);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, spoke1RiskPremiumRad);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // borrow rate changes with this action
    rate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremiumRad, alice); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
      spoke1RiskPremiumRad +
      spoke2DrawAmount *
      spoke2RiskPremiumRad) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    spoke1DrawAmount += spoke1AccruedDebt;
    spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremiumRad, alice);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    expectedRiskPremium =
      ((spoke1DrawAmount + spoke1AccruedDebt) *
        spoke1RiskPremiumRad +
        (spoke2DrawAmount + spoke2AccruedDebt) *
        spoke2RiskPremiumRad +
        spoke3DrawAmount *
        spoke3RiskPremiumRad) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 1);
  }

  function test_fuzzMultipleDrawWhileAccruingInterest(
    TestDrawAmountAndRiskPremiumRadInput memory p,
    uint256 timeToSkip,
    uint256 baseBorrowRate
  ) public {
    // todo: minDrawAmount temp workaround
    p = bound({input: p, minDrawAmount: daiAmount / 1e9, maxDrawAmount: daiAmount});
    timeToSkip = bound(timeToSkip, 1 days, 100_000 days);
    baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, totalToDraw, p.riskPremiumRad.spoke1, alice);

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, p.drawAmount.spoke1, p.riskPremiumRad.spoke1, alice);

    uint256 totalBaseDebt = p.drawAmount.spoke1;
    assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    assertEq(hub.getAsset(daiAssetId).riskPremiumRad, p.riskPremiumRad.spoke1);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // borrow baseBorrowRate changes with this action
    baseBorrowRate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, p.drawAmount.spoke2, p.riskPremiumRad.spoke2, alice); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, p.drawAmount.spoke1);

    totalBaseDebt += spoke1AccruedDebt + p.drawAmount.spoke2;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((p.drawAmount.spoke1 + spoke1AccruedDebt) * // correctly account for spoke1 debt
      p.riskPremiumRad.spoke1 +
      p.drawAmount.spoke2 *
      p.riskPremiumRad.spoke2) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 1);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    p.drawAmount.spoke1 += spoke1AccruedDebt;
    spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = p.drawAmount.spoke2.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, p.drawAmount.spoke3, p.riskPremiumRad.spoke3, alice);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + p.drawAmount.spoke3;
    expectedRiskPremium =
      ((p.drawAmount.spoke1 + spoke1AccruedDebt) *
        p.riskPremiumRad.spoke1 +
        (p.drawAmount.spoke2 + spoke2AccruedDebt) *
        p.riskPremiumRad.spoke2 +
        p.drawAmount.spoke3 *
        p.riskPremiumRad.spoke3) /
      totalBaseDebt;
    assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 2);
    assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremiumRad, expectedRiskPremium, 3);
  }
}
