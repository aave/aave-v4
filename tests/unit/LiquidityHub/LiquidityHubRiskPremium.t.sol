// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

struct TestDrawAmountInput {
  uint256 spoke1;
  uint256 spoke2;
  uint256 spoke3;
}

struct TestRiskPremiumInput {
  uint32 spoke1;
  uint32 spoke2;
  uint32 spoke3;
}

struct TestDrawAmountAndRiskPremiumInput {
  TestDrawAmountInput drawAmount;
  TestRiskPremiumInput riskPremium;
}

contract LiquidityHubRiskPremiumTest_Base is Base {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 daiAmount = 2000e18;
  uint256 wethAmount = 1e18;

  uint32 spoke1RiskPremium = 50_00;
  uint32 spoke2RiskPremium = 20_00;
  uint32 spoke3RiskPremium = 30_00;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function bound(
    TestDrawAmountAndRiskPremiumInput memory input,
    uint256 minDrawAmount,
    uint256 maxDrawAmount
  ) internal pure returns (TestDrawAmountAndRiskPremiumInput memory) {
    input.drawAmount.spoke1 = bound(input.drawAmount.spoke1, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke2 = bound(input.drawAmount.spoke2, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke3 = bound(input.drawAmount.spoke3, minDrawAmount, maxDrawAmount);

    input.riskPremium.spoke1 %= MAX_RISK_PREMIUM_BPS;
    input.riskPremium.spoke2 %= MAX_RISK_PREMIUM_BPS;
    input.riskPremium.spoke3 %= MAX_RISK_PREMIUM_BPS;

    vm.assume(input.drawAmount.spoke1 + input.drawAmount.spoke2 + input.drawAmount.spoke3 != 0);

    return input;
  }
}

contract LiquidityHubRiskPremium_ConstantTimeAndRiskPremium is LiquidityHubRiskPremiumTest_Base {
  using WadRayMath for uint256;

  function test_riskPremiumOnNoDraw() public {
    vm.skip(true, 'pending refactor');

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium, 0); // since no drawn liquidity
  }

  function test_singleDrawSameAmount() public {
    vm.skip(true, 'pending refactor');

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);

    //     uint256 usdxDrawnAmount = daiAmount / 2;
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, usdxDrawnAmount, spoke2RiskPremium, alice);

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), spoke2RiskPremium);
  }

  function test_multipleDrawSameAmount() public {
    vm.skip(true, 'pending refactor');

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);

    //     uint256 usdxDrawnAmount = daiAmount / 3;
    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, usdxDrawnAmount, spoke2RiskPremium, alice);

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), spoke2RiskPremium);

    //     // spoke 3 draws
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, usdxDrawnAmount, spoke3RiskPremium, alice);

    //     uint256 totalBaseDebt = usdxDrawnAmount * 2;
    //     uint256 expectedRiskPremium = (usdxDrawnAmount *
    //       spoke2RiskPremium +
    //       usdxDrawnAmount *
    //       spoke3RiskPremium) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);

    //     // spoke 1 draws remaining liquidity
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, usdxDrawnAmount, spoke1RiskPremium, alice);

    //     totalBaseDebt = usdxDrawnAmount * 3;
    //     expectedRiskPremium =
    //       (usdxDrawnAmount *
    //         spoke1RiskPremium +
    //         usdxDrawnAmount *
    //         spoke2RiskPremium +
    //         usdxDrawnAmount *
    //         spoke3RiskPremium) /
    //       totalBaseDebt;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);
  }

  function test_multipleDrawMultipleAmount() public {
    vm.skip(true, 'pending refactor');

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);

    //     uint256 spoke1DrawAmount = daiAmount / 4;
    //     uint256 spoke2DrawAmount = daiAmount / 2;
    //     uint256 spoke3DrawAmount = daiAmount / 8;

    //     // spoke 1 draws
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremium, alice);

    //     uint256 totalBaseDebt = spoke1DrawAmount;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), spoke1RiskPremium);

    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremium, alice);

    //     totalBaseDebt += spoke2DrawAmount;
    //     uint256 expectedRiskPremium = (spoke1DrawAmount *
    //       spoke1RiskPremium +
    //       spoke2DrawAmount *
    //       spoke2RiskPremium) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);

    //     // spoke 3 draws remaining liquidity
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremium, alice);

    //     totalBaseDebt += spoke3DrawAmount;
    //     expectedRiskPremium =
    //       (spoke1DrawAmount *
    //         spoke1RiskPremium +
    //         spoke2DrawAmount *
    //         spoke2RiskPremium +
    //         spoke3DrawAmount *
    //         spoke3RiskPremium) /
    //       totalBaseDebt;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);
  }

  function test_fuzzDrawAndPremium(TestDrawAmountAndRiskPremiumInput memory p) public {
    vm.skip(true, 'pending refactor');

    //     p = bound({input: p, minDrawAmount: 1, maxDrawAmount: daiAmount});
    //     uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, totalToDraw, spoke1RiskPremium, alice);

    //     // spoke 1 draws
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, p.drawAmount.spoke1, p.riskPremium.spoke1, alice);

    //     uint256 totalBaseDebt = p.drawAmount.spoke1;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), p.riskPremium.spoke1);

    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, p.drawAmount.spoke2, p.riskPremium.spoke2, alice);

    //     totalBaseDebt += p.drawAmount.spoke2;
    //     uint256 expectedRiskPremium = (p.drawAmount.spoke1 *
    //       p.riskPremium.spoke1 +
    //       p.drawAmount.spoke2 *
    //       p.riskPremium.spoke2) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);

    //     // spoke 3 draws remaining liquidity
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, p.drawAmount.spoke3, p.riskPremium.spoke3, alice);

    //     totalBaseDebt += p.drawAmount.spoke3;
    //     expectedRiskPremium =
    //       (p.drawAmount.spoke1 *
    //         p.riskPremium.spoke1 +
    //         p.drawAmount.spoke2 *
    //         p.riskPremium.spoke2 +
    //         p.drawAmount.spoke3 *
    //         p.riskPremium.spoke3) /
    //       totalBaseDebt;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);
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
    vm.skip(true, 'pending refactor');

    //     timeToSkip = bound(timeToSkip, 1 days, 10_000 days);
    //     baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    //     uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(baseBorrowRate)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);

    //     uint256 spoke1DrawAmount = daiAmount / 4;
    //     uint256 spoke2DrawAmount = daiAmount / 2;
    //     uint256 spoke3DrawAmount = daiAmount / 8;

    //     // spoke 1 draws
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremium, alice);

    //     uint256 totalBaseDebt = spoke1DrawAmount;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), spoke1RiskPremium);

    //     skip(timeToSkip);
    //     uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremium, alice); // trigger base debt update

    //     // debt has been not been accrued for spoke 1 individually yet
    //     assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    //     totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    //     uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
    //       spoke1RiskPremium +
    //       spoke2DrawAmount *
    //       spoke2RiskPremium) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);

    //     lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    //     skip(timeToSkip);

    //     spoke1DrawAmount += spoke1AccruedDebt;
    //     spoke1AccruedDebt = spoke1DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );
    //     uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // spoke 3 draws remaining liquidity
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremium, alice);

    //     totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    //     expectedRiskPremium =
    //       ((spoke1DrawAmount + spoke1AccruedDebt) *
    //         spoke1RiskPremium +
    //         (spoke2DrawAmount + spoke2AccruedDebt) *
    //         spoke2RiskPremium +
    //         spoke3DrawAmount *
    //         spoke3RiskPremium) /
    //       totalBaseDebt;
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 1);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);
  }

  function test_multipleDrawWhileAccruingInterest() public {
    vm.skip(true, 'pending refactor');

    //     test_fuzzMultipleDrawWhileAccruingInterest({
    //       timeToSkip: 365 days,
    //       baseBorrowRate: uint256(15_00).bpsToRay()
    //     });
  }

  function test_multipleDrawWhileAccruingInterestWithChangingRate() public {
    vm.skip(true, 'pending refactor');

    //     uint256 timeToSkip = 365 days;
    //     uint256 rate = uint256(15_00).bpsToRay();
    //     uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, daiAmount, spoke1RiskPremium, alice);

    //     uint256 spoke1DrawAmount = daiAmount / 4;
    //     uint256 spoke2DrawAmount = daiAmount / 2;
    //     uint256 spoke3DrawAmount = daiAmount / 8;

    //     // spoke 1 draws
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, spoke1DrawAmount, spoke1RiskPremium, alice);

    //     uint256 totalBaseDebt = spoke1DrawAmount;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), spoke1RiskPremium);

    //     skip(timeToSkip);
    //     uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // borrow rate changes with this action
    //     rate *= 2;
    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(rate)
    //     );

    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, spoke2DrawAmount, spoke2RiskPremium, alice); // trigger base debt update

    //     // debt has been not been accrued for spoke 1 individually yet
    //     assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    //     totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    //     uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
    //       spoke1RiskPremium +
    //       spoke2DrawAmount *
    //       spoke2RiskPremium) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium);

    //     lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    //     skip(timeToSkip);

    //     spoke1DrawAmount += spoke1AccruedDebt;
    //     spoke1AccruedDebt = spoke1DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );
    //     uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
    //       MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // spoke 3 draws remaining liquidity
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, spoke3DrawAmount, spoke3RiskPremium, alice);

    //     totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    //     expectedRiskPremium =
    //       ((spoke1DrawAmount + spoke1AccruedDebt) *
    //         spoke1RiskPremium +
    //         (spoke2DrawAmount + spoke2AccruedDebt) *
    //         spoke2RiskPremium +
    //         spoke3DrawAmount *
    //         spoke3RiskPremium) /
    //       totalBaseDebt;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);
  }

  function test_fuzzMultipleDrawWhileAccruingInterest(
    TestDrawAmountAndRiskPremiumInput memory p,
    uint256 timeToSkip,
    uint256 baseBorrowRate
  ) public {
    vm.skip(true, 'pending refactor');

    //     p = bound({input: p, minDrawAmount: daiAmount, maxDrawAmount: daiAmount});
    //     timeToSkip = bound(timeToSkip, 1 days, 100_000 days);
    //     baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    //     uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    //     uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(baseBorrowRate)
    //     );

    //     vm.prank(address(spoke1));
    //     hub.supply(daiAssetId, totalToDraw, p.riskPremium.spoke1, alice);

    //     // spoke 1 draws
    //     vm.prank(address(spoke1));
    //     hub.draw(daiAssetId, p.drawAmount.spoke1, p.riskPremium.spoke1, alice);

    //     uint256 totalBaseDebt = p.drawAmount.spoke1;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    //     assertEq(hub.getAsset(daiAssetId).riskPremium.derayify(), p.riskPremium.spoke1);

    //     skip(timeToSkip);
    //     uint256 spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // borrow baseBorrowRate changes with this action
    //     baseBorrowRate *= 2;
    //     vm.mockCall(
    //       address(irStrategy),
    //       IBasicInterestRateStrategy.calculateInterestRates.selector,
    //       abi.encode(baseBorrowRate)
    //     );

    //     // spoke 2 draws
    //     vm.prank(address(spoke2));
    //     hub.draw(daiAssetId, p.drawAmount.spoke2, p.riskPremium.spoke2, alice); // trigger base debt update

    //     // debt has been not been accrued for spoke 1 individually yet
    //     assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, p.drawAmount.spoke1);

    //     totalBaseDebt += spoke1AccruedDebt + p.drawAmount.spoke2;
    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    //     uint256 expectedRiskPremium = ((p.drawAmount.spoke1 + spoke1AccruedDebt) * // correctly account for spoke1 debt
    //       p.riskPremium.spoke1 +
    //       p.drawAmount.spoke2 *
    //       p.riskPremium.spoke2) / totalBaseDebt;

    //     assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);

    //     lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    //     skip(timeToSkip);

    //     p.drawAmount.spoke1 += spoke1AccruedDebt;
    //     spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );
    //     uint256 spoke2AccruedDebt = p.drawAmount.spoke2.rayMul(
    //       MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    //     );

    //     // spoke 3 draws remaining liquidity
    //     vm.prank(address(spoke3));
    //     hub.draw(daiAssetId, p.drawAmount.spoke3, p.riskPremium.spoke3, alice);

    //     totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + p.drawAmount.spoke3;
    //     expectedRiskPremium =
    //       ((p.drawAmount.spoke1 + spoke1AccruedDebt) *
    //         p.riskPremium.spoke1 +
    //         (p.drawAmount.spoke2 + spoke2AccruedDebt) *
    //         p.riskPremium.spoke2 +
    //         p.drawAmount.spoke3 *
    //         p.riskPremium.spoke3) /
    //       totalBaseDebt;
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 1);
    //     assertApproxEqAbs(hub.getAsset(daiAssetId).riskPremium.derayify(), expectedRiskPremium, 1);
  }
}
