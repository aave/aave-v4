// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/flashloan-spoke/FlashLoanSpoke.Base.t.sol';

contract FlashLoanSpokeTest is FlashLoanSpokeBaseTest {
  using PercentageMath for uint256;

  function test_flashLoanSimple() public {
    uint256 amount = 1_000e18;
    uint256 fee = amount.percentMulUp(PREMIUM);
    uint256 premium = _expectedPremium(daiAssetId, amount, fee);
    assertEq(premium, fee);
    uint256 liquidityBefore = hub1.getAssetLiquidity(daiAssetId);
    uint256 addedAssetsBefore = hub1.getAddedAssets(daiAssetId);
    uint256 treasuryBefore = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.expectCall(
      address(receiver),
      abi.encodeCall(
        IFlashLoanSimpleReceiver.executeOperation,
        (dai, amount, premium, alice, PARAMS)
      )
    );
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(address(receiver), alice, dai, amount, premium);

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(hub1.getAssetLiquidity(daiAssetId), liquidityBefore + premium);
    assertApproxEqAbs(hub1.getAddedAssets(daiAssetId), addedAssetsBefore + premium, 1);
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      treasuryBefore + _expectedFee(daiAssetId, amount, fee),
      1
    );
    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore - premium);
  }

  function test_flashLoanSimple_fuzz(uint256 amount, uint16 premiumBps) public {
    amount = bound(amount, 1, hub1.getAssetLiquidity(daiAssetId));
    premiumBps = uint16(bound(premiumBps, 0, PercentageMath.PERCENTAGE_FACTOR));
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, premiumBps, true);
    deal(dai, address(receiver), amount + 10);

    uint256 premium = _expectedPremium(daiAssetId, amount, amount.percentMulUp(premiumBps));
    uint256 hubBalanceBefore = IERC20(dai).balanceOf(address(hub1));
    uint256 liquidityBefore = hub1.getAssetLiquidity(daiAssetId);
    uint256 pendingFeeBefore = flashLoanSpoke.getFlashLoanAsset(dai).pendingFee;
    uint256 addedAssetsBefore = hub1.getAddedAssets(daiAssetId);

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(IERC20(dai).balanceOf(address(hub1)), hubBalanceBefore + premium);
    assertEq(
      hub1.getAssetLiquidity(daiAssetId) + flashLoanSpoke.getFlashLoanAsset(dai).pendingFee,
      liquidityBefore + pendingFeeBefore + premium
    );
    assertGe(hub1.getAddedAssets(daiAssetId), addedAssetsBefore);
  }

  function test_flashLoanSimple_feeTooSmallForShares_isPending() public {
    uint256 amount = _amountWithFee(1);
    uint256 treasuryShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 0);
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.payFeeShares.selector), 0);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 1);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), treasuryShares);
  }

  function test_flashLoanSimple_pendingFee_paidWithNextFee() public {
    uint256 smallAmount = _amountWithFee(1);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, smallAmount, PARAMS);

    uint256 amount = 1_000e18;
    uint256 fee = _expectedFee(daiAssetId, amount, amount.percentMulUp(PREMIUM));
    uint256 treasuryBefore = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));

    vm.expectCall(address(hub1), abi.encodeCall(IHubBase.add, (daiAssetId, fee + 1)), 1);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      treasuryBefore + fee + 1,
      1
    );
  }

  function test_flashLoanSimple_pendingFee_accumulates() public {
    uint256 amount = _amountWithFee(1);
    vm.startPrank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
    vm.stopPrank();

    // 2 wei mint a share when the share price is below 2
    assertGt(hub1.previewAddByAssets(daiAssetId, 2), 0);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
  }

  function test_flashLoanSimple_authorizedFlashBorrower() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    uint256 amount = 1_000e18;
    uint256 dustShares = _dustShares(daiAssetId, amount);
    assertEq(dustShares, 1);
    uint256 treasuryShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));
    uint256 liquidityBefore = hub1.getAssetLiquidity(daiAssetId);
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.expectCall(
      address(receiver),
      abi.encodeCall(IFlashLoanSimpleReceiver.executeOperation, (dai, amount, 0, alice, PARAMS))
    );
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 0);
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(address(receiver), alice, dai, amount, 0);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore);
    assertEq(hub1.getAssetLiquidity(daiAssetId), liquidityBefore);
    assertEq(hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke)), dustShares);
    assertTrue(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), treasuryShares);
  }

  function test_flashLoanSimple_authorizedFlashBorrower_fuzz(
    uint256 amount,
    uint256 elapsed
  ) public {
    skip(bound(elapsed, 0, 10 * 365 days));
    amount = bound(amount, 1, hub1.getAssetLiquidity(daiAssetId));
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    uint256 dustShares = _dustShares(daiAssetId, amount);
    uint256 liquidityBefore = hub1.getAssetLiquidity(daiAssetId);
    uint256 addedAssetsBefore = hub1.getAddedAssets(daiAssetId);
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore);
    assertEq(hub1.getAssetLiquidity(daiAssetId), liquidityBefore);
    assertLe(dustShares, 1);
    assertEq(hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke)), dustShares);
    assertGe(hub1.getAddedAssets(daiAssetId), addedAssetsBefore);

    uint256 roundingDebt = hub1.previewRestoreByShares(daiAssetId, dustShares);
    uint256 fee = _expectedFee(daiAssetId, 1_000e18, uint256(1_000e18).percentMulUp(PREMIUM));

    vm.expectCall(address(hub1), abi.encodeCall(IHubBase.add, (daiAssetId, fee - roundingDebt)), 1);
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);

    _assertNoPosition(daiAssetId);
    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
  }

  function test_flashLoanSimple_roundingDebt_restoredWithNextFee() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.startPrank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 3_000e18, PARAMS);
    vm.stopPrank();

    uint256 dustShares = hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke));
    assertEq(dustShares, 2);
    uint256 roundingDebt = hub1.previewRestoreByShares(daiAssetId, dustShares);
    uint256 amount = 2_000e18;
    uint256 fee = _expectedFee(daiAssetId, amount, amount.percentMulUp(PREMIUM));

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.restore, (daiAssetId, roundingDebt, IHubBase.PremiumDelta(0, 0, 0))),
      1
    );
    vm.expectCall(address(hub1), abi.encodeCall(IHubBase.add, (daiAssetId, fee - roundingDebt)), 1);
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
  }

  function test_flashLoanSimple_roundingDebt_feeNotCoveringIsPending() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    uint256 roundingDebt = hub1.previewRestoreByShares(
      daiAssetId,
      hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke))
    );
    assertEq(roundingDebt, 2);

    uint256 amount = _amountWithFee(1);
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 0);
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    assertTrue(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 1);

    uint256 treasuryShares = hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke));
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(treasurySpoke)), treasuryShares);
    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
  }

  function test_flashLoanSimple_waiverIsKeyedOnInitiator() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(address(receiver), true);
    uint256 amount = 1_000e18;
    uint256 premium = _expectedPremium(daiAssetId, amount, amount.percentMulUp(PREMIUM));

    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(address(receiver), alice, dai, amount, premium);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
  }

  function test_flashLoan_duplicateAssets_paysFeesOncePerAsset() public {
    address[] memory assets = new address[](3);
    (assets[0], assets[1], assets[2]) = (dai, usdx, dai);
    uint256[] memory amounts = new uint256[](3);
    (amounts[0], amounts[1], amounts[2]) = (1_000e18, 2_000e6, 3_000e18);
    uint256[] memory premiums = new uint256[](3);
    premiums[0] = _expectedPremium(daiAssetId, amounts[0], amounts[0].percentMulUp(PREMIUM));
    premiums[1] = _expectedPremium(usdxAssetId, amounts[1], amounts[1].percentMulUp(PREMIUM));
    premiums[2] = _expectedPremium(daiAssetId, amounts[2], amounts[2].percentMulUp(PREMIUM));
    uint256 daiFee = _expectedFee(daiAssetId, amounts[0], amounts[0].percentMulUp(PREMIUM)) +
      _expectedFee(daiAssetId, amounts[2], amounts[2].percentMulUp(PREMIUM));
    uint256 usdxFee = _expectedFee(usdxAssetId, amounts[1], amounts[1].percentMulUp(PREMIUM));
    uint256 daiTreasuryBefore = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));
    uint256 usdxTreasuryBefore = hub1.getSpokeAddedAssets(usdxAssetId, address(treasurySpoke));

    vm.expectCall(
      address(receiver),
      abi.encodeCall(
        IFlashLoanReceiver.executeOperation,
        (assets, amounts, premiums, alice, PARAMS)
      )
    );
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 2);
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.payFeeShares.selector), 2);
    vm.prank(alice);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);

    _assertNoPosition(daiAssetId);
    _assertNoPosition(usdxAssetId);
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      daiTreasuryBefore + daiFee,
      1
    );
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(usdxAssetId, address(treasurySpoke)),
      usdxTreasuryBefore + usdxFee,
      1
    );
  }

  function test_flashLoanSimple_nested_paysFeesOnOutermostExit() public {
    uint256 outerAmount = 1_000e18;
    uint256 innerAmount = 2_000e18;
    uint256 fees = _expectedFee(daiAssetId, outerAmount, outerAmount.percentMulUp(PREMIUM)) +
      _expectedFee(daiAssetId, innerAmount, innerAmount.percentMulUp(PREMIUM));
    uint256 treasuryBefore = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));
    receiver.setNestedCall(
      abi.encodeCall(IFlashLoanSpoke.flashLoanSimple, (address(receiver), dai, innerAmount, PARAMS))
    );

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.draw.selector), 2);
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 1);
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.payFeeShares.selector), 1);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, outerAmount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      treasuryBefore + fees,
      1
    );
  }

  function test_flashLoanSimple_consecutiveCalls_payFeesSeparately() public {
    uint256 amount = 1_000e18;
    uint256 fee = _expectedFee(daiAssetId, amount, amount.percentMulUp(PREMIUM));
    uint256 treasuryBefore = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));

    vm.startPrank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
    uint256 treasuryAfterFirst = hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke));
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
    vm.stopPrank();

    assertApproxEqAbs(treasuryAfterFirst, treasuryBefore + fee, 1);
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(daiAssetId, address(treasurySpoke)),
      treasuryBefore + 2 * fee,
      2
    );
    _assertNoPosition(daiAssetId);
  }

  function test_flashLoan_authorizedFlashBorrower() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    address[] memory assets = new address[](2);
    (assets[0], assets[1]) = (dai, usdx);
    uint256[] memory amounts = new uint256[](2);
    (amounts[0], amounts[1]) = (1_000e18, 2_000e6);
    uint256 daiDustShares = _dustShares(daiAssetId, amounts[0]);
    uint256 usdxDustShares = _dustShares(usdxAssetId, amounts[1]);
    uint256 daiReceiverBefore = IERC20(dai).balanceOf(address(receiver));
    uint256 usdxReceiverBefore = IERC20(usdx).balanceOf(address(receiver));

    vm.expectCall(
      address(receiver),
      abi.encodeCall(
        IFlashLoanReceiver.executeOperation,
        (assets, amounts, new uint256[](2), alice, PARAMS)
      )
    );
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 0);
    vm.prank(alice);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);

    assertEq(IERC20(dai).balanceOf(address(receiver)), daiReceiverBefore);
    assertEq(IERC20(usdx).balanceOf(address(receiver)), usdxReceiverBefore);
    assertEq(hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke)), daiDustShares);
    assertEq(hub1.getSpokeDrawnShares(usdxAssetId, address(flashLoanSpoke)), usdxDustShares);
    assertTrue(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertTrue(flashLoanSpoke.getFlashLoanAsset(usdx).hasRoundingDebt);
  }

  function test_flashLoanSimple_nested_roundingDebtRestoredOnOutermostExit() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    uint256 outerAmount = 1_000e18;
    uint256 innerAmount = 2_000e18;
    uint256 dustShares = _dustShares(daiAssetId, outerAmount);
    assertEq(dustShares, 1);
    uint256 roundingDebt = hub1.previewRestoreByShares(daiAssetId, dustShares);
    uint256 fee = _expectedFee(daiAssetId, innerAmount, innerAmount.percentMulUp(PREMIUM));
    // the nested flashloan is initiated by the receiver, which pays the premium
    receiver.setNestedCall(
      abi.encodeCall(IFlashLoanSpoke.flashLoanSimple, (address(receiver), dai, innerAmount, PARAMS))
    );

    vm.expectCall(
      address(hub1),
      abi.encodeCall(IHubBase.restore, (daiAssetId, roundingDebt, IHubBase.PremiumDelta(0, 0, 0))),
      1
    );
    vm.expectCall(address(hub1), abi.encodeCall(IHubBase.add, (daiAssetId, fee - roundingDebt)), 1);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, outerAmount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
  }

  function test_flashLoanSimple_nested_otherAsset_paysFeeOnItsOwnExit() public {
    uint256 outerAmount = 1_000e18;
    uint256 innerAmount = 2_000e6;
    receiver.setNestedCall(
      abi.encodeCall(
        IFlashLoanSpoke.flashLoanSimple,
        (address(receiver), usdx, innerAmount, PARAMS)
      )
    );

    // the usdx fee is paid when the nested flashloan returns, before the dai flashloan is repaid
    vm.expectEmit(true, true, true, false, address(hub1));
    emit IHubBase.TransferShares(usdxAssetId, address(flashLoanSpoke), address(treasurySpoke), 0);
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(
      address(receiver),
      address(receiver),
      usdx,
      innerAmount,
      _expectedPremium(usdxAssetId, innerAmount, innerAmount.percentMulUp(PREMIUM))
    );
    vm.expectEmit(true, true, true, false, address(hub1));
    emit IHubBase.TransferShares(daiAssetId, address(flashLoanSpoke), address(treasurySpoke), 0);
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(
      address(receiver),
      alice,
      dai,
      outerAmount,
      _expectedPremium(daiAssetId, outerAmount, outerAmount.percentMulUp(PREMIUM))
    );
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, outerAmount, PARAMS);

    _assertNoPosition(daiAssetId);
    _assertNoPosition(usdxAssetId);
  }

  function test_flashLoanSimple_revertsWith_FlashLoanDisabled() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, PREMIUM, false);

    vm.expectRevert(IFlashLoanSpoke.FlashLoanDisabled.selector);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1e18, PARAMS);
  }

  function test_flashLoanSimple_revertsWith_FlashLoanDisabled_unconfiguredAsset() public {
    vm.expectRevert(IFlashLoanSpoke.FlashLoanDisabled.selector);
    flashLoanSpoke.flashLoanSimple(address(receiver), address(tokenList.weth), 1e18, PARAMS);
  }

  function test_flashLoanSimple_revertsWith_InvalidFlashLoanExecutorReturn() public {
    receiver.setReturnValue(false);

    vm.expectRevert(IFlashLoanSpoke.InvalidFlashLoanExecutorReturn.selector);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1e18, PARAMS);
  }

  function test_flashLoanSimple_revertsWhen_repaymentShort() public {
    uint256 amount = 1e18;
    uint256 owed = amount + _expectedPremium(daiAssetId, amount, amount.percentMulUp(PREMIUM));
    receiver.setShortfall(1);

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(flashLoanSpoke),
        owed - 1,
        owed
      )
    );
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
  }

  function test_flashLoanSimple_revertsWith_DrawCapExceeded() public {
    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(flashLoanSpoke));
    config.drawCap = 1_000;
    vm.prank(ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(flashLoanSpoke), config);

    vm.expectRevert(abi.encodeWithSelector(IHub.DrawCapExceeded.selector, 1_000));
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_001e18, PARAMS);
  }

  function test_flashLoanSimple_revertsWith_SpokeHalted() public {
    IHub.SpokeConfig memory config = hub1.getSpokeConfig(daiAssetId, address(flashLoanSpoke));
    config.halted = true;
    vm.prank(ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(flashLoanSpoke), config);

    vm.expectRevert(IHub.SpokeHalted.selector);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1e18, PARAMS);
  }

  function test_flashLoan_revertsWith_InvalidFlashLoanExecutorReturn() public {
    receiver.setReturnValue(false);
    address[] memory assets = new address[](1);
    assets[0] = dai;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = 1e18;

    vm.expectRevert(IFlashLoanSpoke.InvalidFlashLoanExecutorReturn.selector);
    flashLoanSpoke.flashLoan(address(receiver), assets, amounts, PARAMS);
  }

  function test_flashLoan_revertsWith_InconsistentFlashLoanParams() public {
    vm.expectRevert(IFlashLoanSpoke.InconsistentFlashLoanParams.selector);
    flashLoanSpoke.flashLoan(address(receiver), new address[](1), new uint256[](2), PARAMS);
  }

  function test_updateAssetConfig() public {
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.UpdateAssetConfig(usdx, usdxAssetId, 100_00, false);
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(usdx, 100_00, false);

    IFlashLoanSpoke.FlashLoanAsset memory asset = flashLoanSpoke.getFlashLoanAsset(usdx);
    assertEq(asset.assetId, usdxAssetId);
    assertEq(asset.premium, 100_00);
    assertFalse(asset.enabled);
    assertFalse(asset.hasRoundingDebt);
    assertEq(asset.pendingFee, 0);
  }

  function test_updateAssetConfig_keepsPendingFee() public {
    uint256 amount = _amountWithFee(1);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, 0, false);

    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 1);
  }

  function test_flashLoanSimple_defaultPremium() public view {
    assertEq(flashLoanSpoke.DEFAULT_PREMIUM(), PREMIUM);
    assertEq(flashLoanSpoke.USE_DEFAULT_PREMIUM(), type(uint16).max);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).premium, flashLoanSpoke.USE_DEFAULT_PREMIUM());
  }

  function test_flashLoanSimple_customPremium() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, 30, true);
    uint256 amount = 1_000e18;
    uint256 premium = amount.percentMulUp(30);
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(address(receiver), alice, dai, amount, premium);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore - premium);
  }

  function test_flashLoanSimple_zeroPremium() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, 0, true);
    uint256 amount = 1_000e18;
    uint256 rounding = _rounding(daiAssetId, amount);
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.add.selector), 0);
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.FlashLoan(address(receiver), alice, dai, amount, rounding);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore - rounding);
  }

  function test_updateAssetConfig_revertsWith_InvalidPremium(uint16 premium) public {
    premium = uint16(bound(premium, PercentageMath.PERCENTAGE_FACTOR + 1, type(uint16).max - 1));
    vm.expectRevert(IFlashLoanSpoke.InvalidPremium.selector);
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, premium, true);
  }

  function test_updateAssetConfig_revertsWith_AssetNotListed() public {
    vm.expectRevert(IHub.AssetNotListed.selector);
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(makeAddr('unlisted'), PREMIUM, true);
  }

  function test_updateAssetConfig_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    flashLoanSpoke.updateAssetConfig(dai, PREMIUM, true);
  }

  function test_updateFlashBorrower() public {
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.UpdateFlashBorrower(bob, true);
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(bob, true);

    assertTrue(flashLoanSpoke.isFlashBorrower(bob));
  }

  function test_updateFlashBorrower_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    flashLoanSpoke.updateFlashBorrower(bob, true);
  }

  function test_repayRoundingDebt_zeroPremium() public {
    vm.startPrank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, 0, true);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.stopPrank();
    vm.startPrank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 3_000e18, PARAMS);
    vm.stopPrank();
    // no fee on the asset, so fee-paying flashloans do not restore the rounding debt
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 2_000e18, PARAMS);

    uint256 dustShares = hub1.getSpokeDrawnShares(daiAssetId, address(flashLoanSpoke));
    assertEq(dustShares, 2);
    uint256 roundingDebt = hub1.previewRestoreByShares(daiAssetId, dustShares);
    uint256 liquidityBefore = hub1.getAssetLiquidity(daiAssetId);
    deal(dai, ADMIN, roundingDebt);

    vm.startPrank(ADMIN);
    IERC20(dai).approve(address(flashLoanSpoke), roundingDebt);
    vm.expectEmit(address(flashLoanSpoke));
    emit IFlashLoanSpoke.RepayRoundingDebt(dai, ADMIN, roundingDebt);
    assertEq(flashLoanSpoke.repayRoundingDebt(dai), roundingDebt);
    vm.stopPrank();

    _assertNoPosition(daiAssetId);
    assertEq(hub1.getAssetLiquidity(daiAssetId), liquidityBefore + roundingDebt);
    assertEq(IERC20(dai).balanceOf(ADMIN), 0);
    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
  }

  function test_repayRoundingDebt_keepsPendingFee() public {
    vm.prank(ADMIN);
    flashLoanSpoke.updateFlashBorrower(alice, true);
    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, 1_000e18, PARAMS);
    uint256 amount = _amountWithFee(1);
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 1);

    deal(dai, ADMIN, 1e18);
    vm.startPrank(ADMIN);
    IERC20(dai).approve(address(flashLoanSpoke), 1e18);
    flashLoanSpoke.repayRoundingDebt(dai);
    vm.stopPrank();

    assertFalse(flashLoanSpoke.getFlashLoanAsset(dai).hasRoundingDebt);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 1);

    uint256 nextAmount = 2_000e18;
    uint256 fee = _expectedFee(daiAssetId, nextAmount, nextAmount.percentMulUp(PREMIUM));
    vm.expectCall(address(hub1), abi.encodeCall(IHubBase.add, (daiAssetId, fee + 1)), 1);
    vm.prank(bob);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, nextAmount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(flashLoanSpoke.getFlashLoanAsset(dai).pendingFee, 0);
  }

  function test_repayRoundingDebt_revertsWith_InvalidAmount() public {
    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(ADMIN);
    flashLoanSpoke.repayRoundingDebt(dai);
  }

  function test_repayRoundingDebt_revertsWith_AssetNotListed() public {
    vm.expectRevert(IHub.AssetNotListed.selector);
    vm.prank(ADMIN);
    flashLoanSpoke.repayRoundingDebt(makeAddr('unlisted'));
  }

  function test_repayRoundingDebt_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    flashLoanSpoke.repayRoundingDebt(dai);
  }

  function test_initialize() public {
    address impl = address(new FlashLoanSpokeInstance());
    vm.expectEmit();
    emit IFlashLoanSpoke.UpdateHub(address(hub1));
    IFlashLoanSpoke spoke = IFlashLoanSpoke(
      AaveV4TestOrchestration.proxify(
        impl,
        ADMIN,
        abi.encodeCall(FlashLoanSpokeInstance.initialize, (address(accessManager), address(hub1)))
      )
    );

    assertEq(address(spoke.getHub()), address(hub1));
    assertEq(IAccessManaged(address(spoke)).authority(), address(accessManager));
  }

  function test_initialize_revertsWith_InvalidAddress_hub() public {
    address impl = address(new FlashLoanSpokeInstance());
    vm.expectRevert(IFlashLoanSpoke.InvalidAddress.selector);
    AaveV4TestOrchestration.proxify(
      impl,
      ADMIN,
      abi.encodeCall(FlashLoanSpokeInstance.initialize, (address(accessManager), address(0)))
    );
  }

  function test_initialize_revertsWith_InvalidAddress_authority() public {
    address impl = address(new FlashLoanSpokeInstance());
    vm.expectRevert(IFlashLoanSpoke.InvalidAddress.selector);
    AaveV4TestOrchestration.proxify(
      impl,
      ADMIN,
      abi.encodeCall(FlashLoanSpokeInstance.initialize, (address(0), address(hub1)))
    );
  }

  function test_initialize_revertsWith_InvalidInitialization() public {
    FlashLoanSpokeInstance impl = new FlashLoanSpokeInstance();
    vm.expectRevert(Initializable.InvalidInitialization.selector);
    impl.initialize(address(accessManager), address(hub1));

    vm.expectRevert(Initializable.InvalidInitialization.selector);
    FlashLoanSpokeInstance(address(flashLoanSpoke)).initialize(
      address(accessManager),
      address(hub1)
    );
  }

  /// @dev Returns a dai amount whose flashloan pays exactly `fee` to the Hub fee receiver, too small to mint a share.
  function _amountWithFee(uint256 fee) internal view returns (uint256) {
    assertEq(hub1.previewAddByAssets(daiAssetId, fee), 0);
    for (uint256 amount = 1; amount < 1e6; ++amount) {
      if (_expectedFee(daiAssetId, amount, amount.percentMulUp(PREMIUM)) == fee) {
        return amount;
      }
    }
    revert('no amount found');
  }
}
