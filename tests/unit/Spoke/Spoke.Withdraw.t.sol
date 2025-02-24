// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBaseTest.t.sol';

contract SpokeWithdrawTest is SpokeBaseTest {
  using WadRayMath for uint256;

  function test_withdraw_revertsWith_supplied_amount_exceeded_zero_supplied() public {
    uint256 reserveId = 0;
    uint256 amount = 1;

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded_zero_supplied(
    uint256 amount,
    uint256 reserveId
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded() public {
    uint256 reserveId = spokeInfo[spoke1].weth.reserveId;
    uint256 amount = 100e18;

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});
  }

  function test_withdraw_fuzz_revertsWith_supplied_amount_exceeded(
    uint256 amount,
    uint256 reserveId
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount + 1, to: alice});
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded_with_debt() public {
    uint256 reserveId = spokeInfo[spoke1].weth.reserveId;
    uint256 amount = 100e18;
    uint256 borrowAmount = 50e18;

    // mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );

    // User spoke supply
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });

    // User spoke borrow
    Utils.borrow({
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: borrowAmount,
      onBehalfOf: alice
    });

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount - borrowAmount + 1, to: alice});

    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount - borrowAmount + 1, to: alice});
  }

  function test_withdraw_fuzz_multi_user(
    uint256 amount,
    uint256 amount2,
    uint256 reserveId
  ) public {
    reserveId = bound(amount, 0, spokeInfo[spoke1].MAX_RESERVE_ID);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT - 1);
    amount2 = bound(amount2, 1, MAX_SUPPLY_AMOUNT - amount);

    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: alice,
      amount: amount,
      to: alice
    });
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: reserveId,
      user: bob,
      amount: amount2,
      to: bob
    });

    vm.prank(alice);
    spoke1.withdraw({reserveId: reserveId, amount: amount, to: alice});

    vm.prank(bob);
    spoke1.withdraw({reserveId: reserveId, amount: amount2, to: bob});
  }

  // function test_withdraw_all_liquidity_with_interest() public {
  //   uint256 daiAmount = 100e18;
  //   uint256 wethAmount = 10e18;
  //   uint256 drawAmount = daiAmount / 2;
  //   uint32 riskPremium = 20_00;
  //   uint256 lastUpdateTimestamp = vm.getBlockTimestamp();

  //   _supplyAndDrawLiquidity({
  //     daiAmount: daiAmount,
  //     wethAmount: wethAmount,
  //     daiDrawAmount: drawAmount,
  //     riskPremium: riskPremium,
  //     rate: rate
  //   });

  //   skip(365 days);

  //   HubData memory hubData;
  //   hubData.daiData = hub.getAsset(daiAssetId);

  //   uint256 initialAvailableLiquidity = hubData.daiData.availableLiquidity;
  //   uint256 supply2Amount = 10e18;

  //   // bob supplies more DAI to trigger accrual
  //   Utils.supply({
  //     hub: hub,
  //     assetId: daiAssetId,
  //     spoke: address(spoke2),
  //     amount: supply2Amount,
  //     riskPremium: 0,
  //     user: bob,
  //     to: address(spoke2)
  //   });

  //   hubData.daiData1 = hub.getAsset(daiAssetId);

  //   uint256 restoreAmount = hubData.daiData1.baseDebt + hubData.daiData1.outstandingPremium;
  //   uint256 newBaseBorrowIndex = WadRayMath.RAY +
  //     WadRayMath.RAY.rayMul(
  //       MathUtils.calculateLinearInterest(
  //         hubData.daiData1.baseBorrowRate,
  //         uint40(lastUpdateTimestamp)
  //       ) - WadRayMath.RAY
  //     );

  //   // alice restores all debt including accrual
  //   vm.prank(address(spoke1));
  //   hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremium: 0, repayer: alice});

  //   hubData.daiData2 = hub.getAsset(daiAssetId);
  //   assertEq(
  //     hubData.daiData2.availableLiquidity,
  //     initialAvailableLiquidity + restoreAmount + supply2Amount,
  //     'dai availableLiquidity'
  //   );

  //   // bob withdraws all liquidity with interest
  //   vm.prank(address(spoke2));
  //   hub.withdraw({
  //     assetId: daiAssetId,
  //     amount: hubData.daiData2.availableLiquidity,
  //     riskPremium: 0,
  //     to: bob
  //   });

  //   assertEq(
  //     tokenList.dai.balanceOf(bob),
  //     MAX_SUPPLY_AMOUNT + hubData.daiData2.availableLiquidity - supply2Amount - daiAmount,
  //     'bob dai balance'
  //   );

  //   hubData.daiData3 = hub.getAsset(daiAssetId);
  //   hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
  //   hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

  //   // hub
  //   assertEq(hub.getTotalAssets(daiAssetId), 0, 'hub totalAssets');
  //   assertEq(hubData.daiData3.suppliedShares, 0, 'dai suppliedShares');
  //   assertEq(hubData.daiData3.availableLiquidity, 0, 'dai availableLiquidity');
  //   assertEq(hubData.daiData3.baseDebt, 0, 'dai baseDebt');
  //   assertEq(hubData.daiData3.outstandingPremium, 0, 'dai outstandingPremium');
  //   assertEq(hubData.daiData3.baseBorrowIndex, newBaseBorrowIndex, 'dai baseBorrowIndex');
  //   assertEq(hubData.daiData3.baseBorrowRate, rate, 'dai baseBorrowRate');
  //   assertEq(hubData.daiData3.riskPremium, 0, 'dai riskPremium');
  //   assertEq(
  //     hubData.daiData3.lastUpdateTimestamp,
  //     vm.getBlockTimestamp(),
  //     'dai lastUpdateTimestamp'
  //   );
  //   // spoke1
  //   assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 suppliedShares');
  //   assertEq(hubData.spoke1DaiData.baseDebt, 0, 'spoke1 baseDebt');
  //   assertEq(hubData.spoke1DaiData.outstandingPremium, 0, 'spoke1 outstandingPremium');
  //   assertEq(hubData.spoke1DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke1 baseBorrowIndex');
  //   assertEq(hubData.spoke1DaiData.riskPremium, 0, 'spoke1 riskPremium');
  //   assertEq(
  //     hubData.spoke1DaiData.lastUpdateTimestamp,
  //     vm.getBlockTimestamp(),
  //     'spoke1 lastUpdateTimestamp'
  //   );
  //   // spoke2
  //   assertEq(hubData.spoke2DaiData.suppliedShares, 0, 'spoke2 suppliedShares');
  //   assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 baseDebt');
  //   assertEq(hubData.spoke2DaiData.outstandingPremium, 0, 'spoke2 outstandingPremium');
  //   assertEq(hubData.spoke2DaiData.baseBorrowIndex, newBaseBorrowIndex, 'spoke2 baseBorrowIndex');
  //   assertEq(hubData.spoke2DaiData.riskPremium, 0, 'spoke2 riskPremium');
  //   assertEq(
  //     hubData.spoke2DaiData.lastUpdateTimestamp,
  //     vm.getBlockTimestamp(),
  //     'spoke2 lastUpdateTimestamp'
  //   );
  //   // dai - all to alice
  //   assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai balance');
  //   assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai balance');
  //   assertEq(
  //     tokenList.dai.balanceOf(alice),
  //     MAX_SUPPLY_AMOUNT + drawAmount - restoreAmount,
  //     'alice dai balance'
  //   );
  // }
}
