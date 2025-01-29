// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './LiquidityHubBaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubRestoreTest is LiquidityHubBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  function test_restore_revertsWith_asset_not_active() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    _updateActive(daiAssetId, false);

    // spoke1 restore all of drawn dai liquidity
    vm.expectRevert(TestErrors.ASSET_NOT_ACTIVE);

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: drawAmount, riskPremiumRad: 0, repayer: alice});
  }

  function test_restore_revertsWith_invalid_restore_amount() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    // alice restore invalid amount > drawn amount AND premium
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: drawAmount + 1, riskPremiumRad: 0, repayer: alice});
  }

  function test_restore_revertsWith_invalid_restore_amount_zero() public {
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: 0, riskPremiumRad: 0, repayer: alice});
  }

  function test_restore_revertsWith_invalid_restore_amount_with_interest() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;
    uint256 rate = uint256(15_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    skip(skipTime);

    // spoke2 supply more dai to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount / 5,
      riskPremiumRad: uint256(5_00).bpsToRad(),
      user: bob,
      to: address(spoke2)
    });

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(spoke1DaiData.lastUpdateTimestamp)
    );
    uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    assert(cumulatedBaseDebt > 0);

    // alice restore invalid amount > drawn amount AND premium
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      amount: cumulatedBaseDebt + 1,
      riskPremiumRad: 0,
      repayer: alice
    });
  }

  function test_restore_fuzz_revertsWith_invalid_restore_amount_with_interest(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    skip(skipTime);

    // spoke2 supply more dai to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount / 5,
      riskPremiumRad: uint256(5_00).bpsToRad(),
      user: bob,
      to: address(spoke2)
    });

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(spoke1DaiData.lastUpdateTimestamp)
    );
    uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    vm.assume(cumulatedBaseDebt > 0);

    // alice restore invalid amount > drawn amount AND premium
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      amount: cumulatedBaseDebt + 1,
      riskPremiumRad: 0,
      repayer: alice
    });
  }

  function test_restore_revertsWith_invalid_restore_amount_with_interest_and_premium() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 skipTime = 365 days / 2;
    uint256 rate = uint256(15_00).bpsToRay();
    uint256 riskPremiumRad = uint256(30_00).bpsToRad();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      onBehalfOf: address(spoke1)
    });

    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    skip(skipTime);

    // spoke2 supply more dai to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount / 5,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(spoke1DaiData.lastUpdateTimestamp)
    );
    uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).radMul(riskPremiumRad);
    assert(accruedPremium > 0);

    // alice restore invalid amount > drawn amount AND premium
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      amount: cumulatedBaseDebt + accruedPremium + 1,
      riskPremiumRad: 0,
      repayer: alice
    });
  }

  function test_restore_fuzz_revertsWith_invalid_restore_amount_with_interest_and_premium(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint256 riskPremiumRad
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    riskPremiumRad = bound(riskPremiumRad, 1, maxRiskPremiumRad);

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      onBehalfOf: address(spoke1)
    });

    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    skip(skipTime);

    // spoke2 supply more dai to trigger accrual
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount / 5,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(spoke1DaiData.lastUpdateTimestamp)
    );
    uint256 cumulatedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest);
    uint256 accruedPremium = (cumulatedBaseDebt - drawAmount).radMul(riskPremiumRad);
    vm.assume(accruedPremium > 0); // accrued premium can round to 0 in edge case - ex. (cumulatedBaseDebt - drawAmount) = 1, riskPremiumRad = 1

    // alice restore invalid amount > drawn amount AND premium
    vm.expectRevert(TestErrors.INVALID_RESTORE_AMOUNT);

    vm.prank(address(spoke1));
    hub.restore({
      assetId: daiAssetId,
      amount: cumulatedBaseDebt + accruedPremium + 1,
      riskPremiumRad: 0,
      repayer: alice
    });
  }

  /// @dev Restore some amount less than premium
  function test_restore_partial_premium() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 rate = uint256(15_00).bpsToRay();
    uint256 riskPremiumRad = uint256(30_00).bpsToRad();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });
    Asset memory daiData = hub.getAsset(daiAssetId);

    skip(365 days);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(daiData.lastUpdateTimestamp)
    );
    uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    uint256 accruedPremium = accruedBaseDebt.radMul(riskPremiumRad);

    assert(accruedPremium > 0);

    uint256 restoreAmount = accruedPremium / 2;

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(
      hub.getTotalAssets(daiAssetId),
      daiAmount + accruedPremium + accruedBaseDebt,
      'hub dai total assets'
    );
    assertEq(
      daiData.outstandingPremium,
      accruedPremium - restoreAmount,
      'hub dai outstandingPremium'
    );
    assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount, 'hub dai baseDebt');
    assertEq(
      daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity'
    );
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    // spoke1
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium'
    );
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp'
    );
  }

  /// @dev Restore some amount less than premium
  function test_restore_fuzz_partial_premium(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint256 riskPremiumRad,
    uint256 restoreAmount
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    riskPremiumRad = bound(riskPremiumRad, 1, maxRiskPremiumRad);

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });
    Asset memory daiData = hub.getAsset(daiAssetId);

    skip(skipTime);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(daiData.lastUpdateTimestamp)
    );
    uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    uint256 accruedPremium = accruedBaseDebt.radMul(riskPremiumRad);

    vm.assume(accruedPremium > 0);

    restoreAmount = bound(restoreAmount, 1, accruedPremium); // within accrued premium
    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(
      hub.getTotalAssets(daiAssetId),
      daiAmount + accruedPremium + accruedBaseDebt,
      'hub dai total assets'
    );
    assertEq(
      daiData.outstandingPremium,
      accruedPremium - restoreAmount,
      'hub dai outstandingPremium'
    );
    assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount, 'hub dai baseDebt');
    assertEq(
      daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity'
    );
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    // spoke1
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium'
    );
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp'
    );
  }

  /// @dev Restore more than premium but partial amount to eat into base debt
  function test_restore_partial_premium_and_base() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;
    uint256 drawAmount = daiAmount / 2;
    uint256 rate = uint256(15_00).bpsToRay();
    uint256 riskPremiumRad = uint256(30_00).bpsToRad();

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });
    Asset memory daiData = hub.getAsset(daiAssetId);

    skip(365 days);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(daiData.lastUpdateTimestamp)
    );
    uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    uint256 accruedPremium = accruedBaseDebt.radMul(riskPremiumRad);
    assert(accruedPremium > 0);
    uint256 restoreAmount = accruedPremium + 1; // restore amount partially contributes to base debt

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(
      hub.getTotalAssets(daiAssetId),
      daiAmount + accruedPremium + accruedBaseDebt,
      'hub dai total assets'
    );
    assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    assertEq(daiData.baseDebt, accruedBaseDebt + drawAmount - 1, 'hub dai baseDebt');
    assertEq(
      daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity'
    );
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    // spoke1
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium'
    );
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp'
    );
  }

  /// @dev Restore more than premium but partial amount to eat into base debt
  function test_restore_fuzz_partial_premium_and_base(
    uint256 drawAmount,
    uint256 skipTime,
    uint256 rate,
    uint256 riskPremiumRad,
    uint256 restoreAmount
  ) public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    drawAmount = bound(drawAmount, 1, daiAmount); // within supplied dai amount
    skipTime = bound(skipTime, 1, 365 * 10 * 1 days); // 1 sec to 10 years
    rate = bound(rate, 1, 1000_00).bpsToRay(); // 0.01% to 1000%
    riskPremiumRad = bound(riskPremiumRad, 1, maxRiskPremiumRad);

    _supplyAndDrawLiquidity({
      daiAmount: daiAmount,
      wethAmount: wethAmount,
      daiDrawAmount: drawAmount,
      riskPremiumRad: riskPremiumRad,
      rate: rate
    });
    Asset memory daiData = hub.getAsset(daiAssetId);

    skip(skipTime);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      uint40(daiData.lastUpdateTimestamp)
    );
    uint256 accruedBaseDebt = drawAmount.rayMul(cumulatedBaseInterest) - drawAmount;
    uint256 accruedPremium = accruedBaseDebt.radMul(riskPremiumRad);
    vm.assume(accruedPremium > 0);

    restoreAmount = bound(
      restoreAmount,
      accruedPremium + 1,
      accruedPremium + accruedBaseDebt + drawAmount
    ); // more than accrued premium, less than total debt

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    daiData = hub.getAsset(daiAssetId);
    SpokeData memory spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));

    // hub
    assertEq(
      hub.getTotalAssets(daiAssetId),
      daiAmount + accruedPremium + accruedBaseDebt,
      'hub dai total assets'
    );
    assertEq(daiData.outstandingPremium, 0, 'hub dai outstandingPremium');
    assertEq(
      daiData.baseDebt,
      accruedBaseDebt + drawAmount - (restoreAmount - accruedPremium), // eat into base debt after premium is consumed
      'hub dai baseDebt'
    );
    assertEq(
      daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity'
    );
    assertEq(daiData.lastUpdateTimestamp, vm.getBlockTimestamp(), 'hub dai lastUpdateTimestamp');
    // spoke1
    assertEq(
      spoke1DaiData.outstandingPremium,
      daiData.outstandingPremium,
      'hub spoke1 outstandingPremium'
    );
    assertEq(spoke1DaiData.baseDebt, daiData.baseDebt, 'hub spoke1 baseDebt');
    assertEq(
      spoke1DaiData.lastUpdateTimestamp,
      daiData.lastUpdateTimestamp,
      'hub spoke1 lastUpdateTimestamp'
    );
  }

  function test_restore_same_block() public {
    uint256 daiAmount = 100e18;
    uint256 wethAmount = 10e18;

    uint256 drawAmount = daiAmount / 2;
    uint256 restoreAmount = daiAmount / 4;

    uint256 rate = uint256(15_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke1 supply weth
    Utils.supply({
      hub: hub,
      assetId: wethAssetId,
      spoke: address(spoke1),
      amount: wethAmount,
      riskPremiumRad: 0,
      user: alice,
      to: address(spoke1)
    });

    // spoke2 supply dai
    Utils.supply({
      hub: hub,
      assetId: daiAssetId,
      spoke: address(spoke2),
      amount: daiAmount,
      riskPremiumRad: 0,
      user: bob,
      to: address(spoke2)
    });

    // spoke1 draw half of dai reserve liquidity on behalf of user
    Utils.draw({
      hub: hub,
      assetId: daiAssetId,
      to: alice,
      spoke: address(spoke1),
      amount: drawAmount,
      riskPremiumRad: 0,
      onBehalfOf: address(spoke1)
    });

    vm.expectEmit(address(hub));
    emit Restore(daiAssetId, address(spoke1), restoreAmount);

    vm.prank(address(spoke1));
    hub.restore({assetId: daiAssetId, amount: restoreAmount, riskPremiumRad: 0, repayer: alice});

    HubData memory hubData;
    hubData.daiData = hub.getAsset(daiAssetId);
    hubData.wethData = hub.getAsset(wethAssetId);
    hubData.spoke1WethData = hub.getSpoke(wethAssetId, address(spoke1));
    hubData.spoke1DaiData = hub.getSpoke(daiAssetId, address(spoke1));
    hubData.spoke2DaiData = hub.getSpoke(daiAssetId, address(spoke2));

    hubData.timestamp = vm.getBlockTimestamp();

    // hub
    assertEq(hub.getTotalAssets(wethAssetId), wethAmount, 'hub weth total assets post-restore');
    assertEq(hub.getTotalAssets(daiAssetId), daiAmount, 'hub dai total assets post-restore');
    // dai
    assertEq(
      hubData.daiData.suppliedShares,
      hub.convertToSharesUp(daiAssetId, daiAmount),
      'hub dai total shares post-restore'
    );
    assertEq(
      hubData.daiData.availableLiquidity,
      daiAmount - drawAmount + restoreAmount,
      'hub dai availableLiquidity post-restore'
    );
    assertEq(hubData.daiData.baseDebt, drawAmount - restoreAmount, 'hub dai baseDebt post-restore');
    assertEq(hubData.daiData.outstandingPremium, 0, 'hub dai outstandingPremium post-restore');
    assertEq(
      hubData.daiData.baseBorrowIndex,
      WadRayMath.RAY,
      'hub dai baseBorrowIndex post-restore'
    );
    assertEq(hubData.daiData.baseBorrowRate, rate, 'hub dai baseBorrowRate post-restore');
    assertEq(hubData.daiData.riskPremiumRad, 0, 'hub dai riskPremiumRad post-restore');
    assertEq(
      hubData.daiData.lastUpdateTimestamp,
      hubData.timestamp,
      'hub dai lastUpdateTimestamp post-restore'
    );
    // weth
    assertEq(
      hubData.wethData.suppliedShares,
      hub.convertToSharesUp(wethAssetId, wethAmount),
      'hub weth total shares post-restore'
    );
    assertEq(
      hubData.wethData.availableLiquidity,
      wethAmount,
      'hub weth availableLiquidity post-restore'
    );
    assertEq(hubData.wethData.baseDebt, 0, 'hub weth baseDebt post-restore');
    assertEq(hubData.wethData.outstandingPremium, 0, 'hub weth outstandingPremium post-restore');
    assertEq(
      hubData.wethData.baseBorrowIndex,
      WadRayMath.RAY,
      'hub weth baseBorrowIndex post-restore'
    );
    assertEq(hubData.wethData.baseBorrowRate, rate, 'hub weth baseBorrowRate post-restore');
    assertEq(hubData.wethData.riskPremiumRad, 0, 'hub weth riskPremiumRad post-restore');
    assertEq(
      hubData.wethData.lastUpdateTimestamp,
      hubData.timestamp,
      'hub weth lastUpdateTimestamp post-restore'
    );
    // spoke1 weth
    assertEq(
      hubData.spoke1WethData.suppliedShares,
      hubData.wethData.suppliedShares,
      'spoke1 total weth shares post-restore'
    );
    assertEq(hubData.spoke1WethData.baseDebt, hubData.wethData.baseDebt, 'spoke1 base weth debt');
    assertEq(
      hubData.spoke1WethData.outstandingPremium,
      hubData.wethData.outstandingPremium,
      'spoke1 weth outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke1WethData.baseBorrowIndex,
      hubData.wethData.baseBorrowIndex,
      'spoke1 weth baseBorrowIndex post-restore'
    );
    assertEq(hubData.spoke1WethData.riskPremiumRad, 0, 'spoke1 weth riskPremiumRad post-restore');
    assertEq(
      hubData.spoke1WethData.lastUpdateTimestamp,
      hubData.wethData.lastUpdateTimestamp,
      'spoke1 weth lastUpdateTimestamp post-restore'
    );
    // spoke1 dai
    assertEq(hubData.spoke1DaiData.suppliedShares, 0, 'spoke1 total dai shares post-restore');
    assertEq(
      hubData.spoke1DaiData.baseDebt,
      hubData.daiData.baseDebt,
      'spoke1 base dai debt post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.outstandingPremium,
      hubData.daiData.outstandingPremium,
      'spoke1 dai outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke1DaiData.baseBorrowIndex,
      hubData.daiData.baseBorrowIndex,
      'spoke1 dai baseBorrowIndex post-restore'
    );
    assertEq(hubData.spoke1DaiData.riskPremiumRad, 0, 'spoke1 dai riskPremiumRad post-restore');
    assertEq(
      hubData.spoke1DaiData.lastUpdateTimestamp,
      hubData.daiData.lastUpdateTimestamp,
      'spoke1 dai lastUpdateTimestamp post-restore'
    );
    // spoke2 dai
    assertEq(
      hubData.spoke2DaiData.suppliedShares,
      hubData.daiData.suppliedShares,
      'spoke2 total dai shares post-restore'
    );
    assertEq(hubData.spoke2DaiData.baseDebt, 0, 'spoke2 base dai debt post-restore');
    assertEq(
      hubData.spoke2DaiData.outstandingPremium,
      hubData.daiData.outstandingPremium,
      'spoke2 dai outstandingPremium post-restore'
    );
    assertEq(
      hubData.spoke2DaiData.baseBorrowIndex,
      hubData.daiData.baseBorrowIndex,
      'spoke2 dai baseBorrowIndex post-restore'
    );
    assertEq(hubData.spoke2DaiData.riskPremiumRad, 0, 'spoke2 dai riskPremiumRad post-restore');
    assertEq(
      hubData.spoke2DaiData.lastUpdateTimestamp,
      hubData.daiData.lastUpdateTimestamp,
      'spoke2 dai lastUpdateTimestamp post-restore'
    );

    // token balance
    // dai
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      daiAmount - restoreAmount,
      'hub dai final balance'
    );
    assertEq(
      tokenList.dai.balanceOf(alice),
      drawAmount - restoreAmount + MAX_SUPPLY_AMOUNT,
      'alice dai final balance'
    );
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT - daiAmount, 'bob dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke1 dai final balance');
    assertEq(tokenList.dai.balanceOf(address(spoke2)), 0, 'spoke2 dai final balance');
    // weth
    assertEq(tokenList.weth.balanceOf(address(hub)), wethAmount, 'hub weth final balance');
    assertEq(
      tokenList.weth.balanceOf(alice),
      MAX_SUPPLY_AMOUNT - wethAmount,
      'alice weth final balance'
    );
    assertEq(tokenList.weth.balanceOf(bob), MAX_SUPPLY_AMOUNT, 'bob weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke1)), 0, 'spoke1 weth final balance');
    assertEq(tokenList.weth.balanceOf(address(spoke2)), 0, 'spoke2 weth final balance');
  }
}
