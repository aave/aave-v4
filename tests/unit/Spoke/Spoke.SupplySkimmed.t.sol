// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSupplySkimmedTest is SpokeBase {
  using PercentageMath for *;
  using ReserveFlagsMap for ReserveFlags;

  function test_supplySkimmed_revertsWith_Unauthorized() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), amount);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(carol);
    spoke1.supplySkimmed(reserveId, amount, bob);
  }

  function test_supplySkimmed_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1;
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supplySkimmed(reserveId, amount, bob);
  }

  function test_supplySkimmed_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.paused());

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.supplySkimmed(daiReserveId, amount, bob);
  }

  function test_supplySkimmed_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.frozen());

    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.supplySkimmed(daiReserveId, amount, bob);
  }

  function test_supplySkimmed_revertsWith_InsufficientTransferred() public {
    uint256 amount = 100e18;

    vm.expectRevert(abi.encodeWithSelector(IHub.InsufficientTransferred.selector, amount));
    vm.prank(bob);
    spoke1.supplySkimmed(_daiReserveId(spoke1), amount, bob);
  }

  function test_supplySkimmed_revertsWith_InvalidSupplyAmount() public {
    uint256 amount = 0;

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(bob);
    spoke1.supplySkimmed(_daiReserveId(spoke1), amount, bob);
  }

  function test_supplySkimmed_revertsWith_ReentrancyGuardReentrantCall() public {
    uint256 amount = 100e18;

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpokeBase.supplySkimmed.selector
    );

    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.add.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.supplySkimmed(_daiReserveId(spoke1), amount, bob);
  }

  function test_supplySkimmed() public {
    uint256 amount = 100e18;
    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    assertEq(tokenList.dai.balanceOf(bob), mintAmount_DAI);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);

    assertEq(daiData[stage].data.drawnShares, 0);
    assertEq(daiData[stage].data.premiumShares, 0);
    assertEq(daiData[stage].data.premiumOffsetRay, 0);
    assertEq(daiData[stage].data.addedShares, 0);

    assertEq(bobData[stage].data.drawnShares, 0);
    assertEq(bobData[stage].data.premiumShares, 0);
    assertEq(bobData[stage].data.premiumOffsetRay, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), amount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.supplySkimmed(
      _daiReserveId(spoke1),
      amount,
      bob
    );
    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));
    assertEq(returnValues.amount, amount);

    assertEq(
      tokenList.dai.balanceOf(bob),
      mintAmount_DAI - amount,
      'user token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    assertEq(daiData[stage].data.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supplySkimmed');

    assertEq(bobData[stage].data.drawnShares, 0, 'bob drawnShares after-supply');
    assertEq(bobData[stage].data.premiumShares, 0, 'bob premiumShares after-supply');
    assertEq(bobData[stage].data.premiumOffsetRay, 0, 'bob premiumOffsetRay after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supplySkimmed_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    TestUserData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    assertEq(tokenList.dai.balanceOf(bob), amount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);

    assertEq(daiData[stage].data.drawnShares, 0);
    assertEq(daiData[stage].data.premiumShares, 0);
    assertEq(daiData[stage].data.premiumOffsetRay, 0);
    assertEq(daiData[stage].data.addedShares, 0);

    assertEq(bobData[stage].data.drawnShares, 0);
    assertEq(bobData[stage].data.premiumShares, 0);
    assertEq(bobData[stage].data.premiumOffsetRay, 0);
    assertEq(bobData[stage].data.suppliedShares, 0);

    vm.prank(bob);
    tokenList.dai.transfer(address(hub1), amount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke1),
      bob,
      bob,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = spoke1.supplySkimmed(
      _daiReserveId(spoke1),
      amount,
      bob
    );

    stage = 1;
    bobData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), bob);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));

    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));
    assertEq(returnValues.amount, amount);

    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    assertEq(daiData[stage].data.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supplySkimmed');

    assertEq(bobData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(bobData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(bobData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub1.previewAddByAssets(daiAssetId, amount),
      'user suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supplySkimmed_index_increase_no_premium() public {
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    deal(address(tokenList.dai), carol, amount);
    vm.prank(carol);
    tokenList.dai.transfer(address(hub1), amount);

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(_daiReserveId(spoke1), carol, carol, expectedShares, amount);
    _assertRefreshPremiumNotCalled();
    vm.prank(carol);
    (returnValues.shares, returnValues.amount) = spoke1.supplySkimmed(
      _daiReserveId(spoke1),
      amount,
      carol
    );
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, amount);

    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    assertEq(
      daiData[stage].data.drawnShares,
      daiData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(daiData[stage].data.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      daiData[stage].data.addedShares,
      daiData[stage - 1].data.addedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supplySkimmed');

    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
    assertApproxEqAbs(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), carol),
      1,
      'user supplied amount after-supply'
    );
  }

  function test_supplySkimmed_index_increase_with_premium() public {
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1));

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    TestUserData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertGt(daiData[stage].data.premiumShares, 0, 'reserve premiumShares after-supply');

    deal(address(tokenList.dai), carol, amount);
    vm.prank(carol);
    tokenList.dai.transfer(address(hub1), amount);

    TestReturnValues memory returnValues;
    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(_daiReserveId(spoke1), carol, carol, expectedShares, amount);
    _assertRefreshPremiumNotCalled();
    (returnValues.shares, returnValues.amount) = spoke1.supplySkimmed(
      _daiReserveId(spoke1),
      amount,
      carol
    );
    stage = 1;

    carolData[stage] = loadUserInfo(spoke1, _daiReserveId(spoke1), carol);
    daiData[stage] = loadReserveInfo(spoke1, _daiReserveId(spoke1));
    tokenData[stage] = getTokenBalances(tokenList.dai, address(spoke1));

    assertEq(returnValues.shares, expectedShares);
    assertEq(returnValues.amount, amount);

    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    assertEq(
      daiData[stage].data.drawnShares,
      daiData[stage - 1].data.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(
      daiData[stage].data.addedShares,
      daiData[stage - 1].data.addedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supplySkimmed');

    assertEq(carolData[stage].data.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(carolData[stage].data.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(carolData[stage].data.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supplySkimmed_does_not_update_risk_premium() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 50_000e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);

    Utils.borrow(spoke1, _usdxReserveId(spoke1), bob, 10_000e6, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), bob, 10_000e18, bob);

    uint256 initialRP = _getUserRiskPremium(spoke1, bob);
    assertEq(initialRP, _calculateExpectedUserRP(spoke1, bob));

    assertGt(
      _getCollateralRisk(spoke1, _daiReserveId(spoke1)),
      _getCollateralRisk(spoke1, _wethReserveId(spoke1))
    );

    deal(address(tokenList.weth), bob, 10_000e18);
    vm.prank(bob);
    tokenList.weth.transfer(address(hub1), 10_000e18);
    vm.prank(bob);
    spoke1.supplySkimmed(_wethReserveId(spoke1), 10_000e18, bob);
    vm.prank(bob);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true, bob);

    assertNotEq(_getUserRiskPremium(spoke1, bob), initialRP);
    assertEq(_calcStoredUserRP(spoke1, _usdxReserveId(spoke1), bob), initialRP);
    assertEq(_calcStoredUserRP(spoke1, _daiReserveId(spoke1), bob), initialRP);
  }

  function _calcStoredUserRP(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    ISpoke.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return pos.premiumShares.percentDivDown(pos.drawnShares);
  }
}
