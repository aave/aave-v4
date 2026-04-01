// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeSupplyTest is Base {
  using PercentageMath for *;
  using ReserveFlagsMap for ReserveFlags;

  function test_supply_revertsWith_ReserveNotListed() public {
    uint256 reserveId = spoke1.getReserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    spoke1.supply(reserveId, amount, bob);
  }

  function test_supply_revertsWith_ReservePaused() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReservePausedFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.paused());

    vm.expectRevert(ISpoke.ReservePaused.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount, bob);
  }

  function test_supply_revertsWith_ReserveFrozen() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    _updateReserveFrozenFlag(spoke1, daiReserveId, true);
    assertTrue(spoke1.getReserve(daiReserveId).flags.frozen());

    vm.expectRevert(ISpoke.ReserveFrozen.selector);
    vm.prank(bob);
    spoke1.supply(daiReserveId, amount, bob);
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;
    uint256 approvalAmount = amount - 1;

    vm.startPrank(bob);
    tokenList.dai.approve(address(spoke1), approvalAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(spoke1),
        approvalAmount,
        amount
      )
    );
    spoke1.supply(_daiReserveId(spoke1), amount, bob);
    vm.stopPrank();
  }

  function test_supply_fuzz_revertsWith_ERC20InsufficientBalance(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    address randomUser = makeAddr('randomUser');

    vm.startPrank(randomUser);
    tokenList.dai.approve(address(spoke1), amount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(randomUser),
        0,
        amount
      )
    );
    spoke1.supply(_daiReserveId(spoke1), amount, randomUser);
    vm.stopPrank();
  }

  function test_supply_revertsWith_InvalidSupplyAmount() public {
    uint256 amount = 0;

    vm.expectRevert(IHub.InvalidAmount.selector);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount, bob);
  }

  function test_supply_revertsWith_ReentrancyGuardReentrantCall() public {
    uint256 amount = 100e18;

    MockReentrantCaller reentrantCaller = new MockReentrantCaller(
      address(spoke1),
      ISpoke.supply.selector
    );

    vm.mockFunction(
      address(_hub(spoke1, _daiReserveId(spoke1))),
      address(reentrantCaller),
      abi.encodeWithSelector(IHubBase.add.selector)
    );
    vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount, bob);
  }

  function test_supply() public {
    uint256 amount = 100e18;

    // pre-supply token assertions
    assertEq(tokenList.dai.balanceOf(bob), MAX_SUPPLY_AMOUNT_DAI);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);

    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      user: bob,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: amount,
        onBehalfOf: bob
      })
    );

    // pre-supply state via snapshots
    // reserve
    assertEq(r.reserveBefore.totalSuppliedShares, 0);
    // user
    assertEq(r.ownerBefore.position.drawnShares, 0);
    assertEq(r.ownerBefore.position.premiumShares, 0);
    assertEq(r.ownerBefore.position.premiumOffsetRay, 0);
    assertEq(r.ownerBefore.position.suppliedShares, 0);

    // return values
    assertEq(r.shares, expectedShares);
    assertEq(r.amount, amount);

    // post-supply token assertions
    assertEq(
      tokenList.dai.balanceOf(bob),
      MAX_SUPPLY_AMOUNT_DAI - amount,
      'user token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // post-supply reserve assertions
    IHub.SpokeData memory spokeData = hub1.getSpoke(daiAssetId, address(spoke1));
    assertEq(spokeData.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(spokeData.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(spokeData.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      expectedShares,
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // post-supply user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'bob drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'bob premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'bob premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
      expectedShares,
      'bob suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    // pre-supply token assertions
    assertEq(tokenList.dai.balanceOf(bob), amount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), 0);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0);

    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      user: bob,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: bob,
        amount: amount,
        onBehalfOf: bob
      })
    );

    // pre-supply state via snapshots
    // reserve
    assertEq(r.reserveBefore.totalSuppliedShares, 0);
    // user
    assertEq(r.ownerBefore.position.drawnShares, 0);
    assertEq(r.ownerBefore.position.premiumShares, 0);
    assertEq(r.ownerBefore.position.premiumOffsetRay, 0);
    assertEq(r.ownerBefore.position.suppliedShares, 0);

    // return values
    assertEq(r.shares, expectedShares);
    assertEq(r.amount, amount);

    // post-supply token assertions
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(hub1)), amount, 'hub token balance after-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // post-supply reserve assertions
    IHub.SpokeData memory spokeData = hub1.getSpoke(daiAssetId, address(spoke1));
    assertEq(spokeData.drawnShares, 0, 'reserve drawnShares after-supply');
    assertEq(spokeData.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(spokeData.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      expectedShares,
      'reserve suppliedShares after-supply'
    );
    assertEq(
      amount,
      hub1.getSpokeAddedAssets(daiAssetId, address(spoke1)),
      'spoke supplied amount after-supply'
    );
    assertEq(amount, hub1.getAddedAssets(daiAssetId), 'asset supplied amount after-supply');
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // post-supply user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
    assertEq(
      amount,
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), bob),
      'user supplied amount after-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    // increase index on reserveId (uses weth as collateral)
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1), _wethReserveId(spoke1), alice, bob);

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    IHub.SpokeData memory spokeDataBefore = hub1.getSpoke(daiAssetId, address(spoke1));

    deal(address(tokenList.dai), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: _daiReserveId(spoke1),
      caller: carol,
      user: carol,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    _assertRefreshPremiumNotCalled(hub1);
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: carol,
        amount: amount,
        onBehalfOf: carol
      })
    );

    // return values
    assertEq(r.shares, expectedShares);
    assertEq(r.amount, amount);

    // token assertions
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      hubBalanceBefore + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve assertions
    IHub.SpokeData memory spokeDataAfter = hub1.getSpoke(daiAssetId, address(spoke1));
    assertEq(
      spokeDataAfter.drawnShares,
      spokeDataBefore.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(spokeDataAfter.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(spokeDataAfter.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      r.reserveBefore.totalSuppliedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
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

  struct SupplyFuzzLocal {
    uint256 assetId;
    IERC20 underlying;
    uint256 expectedShares;
  }

  function test_supply_fuzz_index_increase_no_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_ALLOWED_DRAWN_RATE);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    vm.assume(reserveId != _wethReserveId(spoke1)); // weth is used as collateral
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 maxSupply = _calculateMaxSupplyAmount(spoke1, reserveId);
    uint256 wethMaxSupply = _calculateMaxSupplyAmount(spoke1, _wethReserveId(spoke1));
    // skip reserves where weth collateral cannot support the borrow
    vm.assume(
      _calcMinimumCollAmount(spoke1, _wethReserveId(spoke1), reserveId, maxSupply / 10) <=
        wethMaxSupply
    );

    // set weth collateral risk to 0 for no premium contribution
    _updateCollateralRisk({spoke: spoke1, reserveId: _wethReserveId(spoke1), newCollateralRisk: 0});

    // increase index on reserveId
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: ReserveSetupParams({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        borrower: address(0),
        supplyAmount: wethMaxSupply,
        borrowAmount: 0
      }),
      borrow: ReserveSetupParams({
        reserveId: reserveId,
        borrowAmount: maxSupply / 10,
        supplyAmount: maxSupply / 5,
        supplier: bob,
        borrower: alice
      }),
      rate: rate,
      isMockRate: true,
      skipTime: skipTime,
      irStrategy: address(irStrategy)
    });

    SupplyFuzzLocal memory state;
    (state.assetId, state.underlying) = _getAssetByReserveId(spoke1, reserveId);
    state.expectedShares = hub1.previewAddByAssets(state.assetId, amount);

    vm.assume(state.expectedShares > 0);
    assertGt(amount, state.expectedShares, 'exchange rate should be > 1');

    uint256 hubBalanceBefore = state.underlying.balanceOf(address(hub1));
    IHub.SpokeData memory spokeDataBefore = hub1.getSpoke(state.assetId, address(spoke1));

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: reserveId,
      caller: carol,
      user: carol,
      suppliedShares: state.expectedShares,
      suppliedAmount: amount
    });
    _assertRefreshPremiumNotCalled(hub1);
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: reserveId,
        user: carol,
        amount: amount,
        onBehalfOf: carol
      })
    );

    // return values
    assertEq(r.shares, state.expectedShares);
    assertEq(r.amount, amount);

    // token balance
    assertEq(
      state.underlying.balanceOf(carol),
      MAX_SUPPLY_AMOUNT - amount,
      'user token balance after-supply'
    );
    assertEq(
      state.underlying.balanceOf(address(hub1)),
      hubBalanceBefore + amount,
      'hub token balance after-supply'
    );
    assertEq(state.underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve assertions
    IHub.SpokeData memory spokeDataAfter = hub1.getSpoke(state.assetId, address(spoke1));
    assertEq(
      spokeDataAfter.drawnShares,
      spokeDataBefore.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(spokeDataAfter.premiumShares, 0, 'reserve premiumShares after-supply');
    assertEq(spokeDataAfter.premiumOffsetRay, 0, 'reserve premiumOffsetRay after-supply');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      r.reserveBefore.totalSuppliedShares + state.expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
      state.expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    _increaseReserveIndex(spoke1, _daiReserveId(spoke1), _wethReserveId(spoke1), alice, bob);

    uint256 amount = 1e18;
    uint256 expectedShares = hub1.previewAddByAssets(daiAssetId, amount);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    IHub.SpokeData memory spokeDataBefore = hub1.getSpoke(daiAssetId, address(spoke1));

    assertGt(spokeDataBefore.premiumShares, 0, 'reserve premiumShares after-supply');

    deal(address(tokenList.dai), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: _daiReserveId(spoke1),
      caller: carol,
      user: carol,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    _assertRefreshPremiumNotCalled(hub1);
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        user: carol,
        amount: amount,
        onBehalfOf: carol
      })
    );

    // return values
    assertEq(r.shares, expectedShares);
    assertEq(r.amount, amount);

    // token assertions
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub1)),
      hubBalanceBefore + amount,
      'hub token balance after-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve assertions
    IHub.SpokeData memory spokeDataAfter = hub1.getSpoke(daiAssetId, address(spoke1));
    assertEq(
      spokeDataAfter.drawnShares,
      spokeDataBefore.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      r.reserveBefore.totalSuppliedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
  }

  function test_supply_fuzz_index_increase_with_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_ALLOWED_DRAWN_RATE);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    vm.assume(reserveId != _wethReserveId(spoke1)); // weth is used as collateral
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 maxSupply = _calculateMaxSupplyAmount(spoke1, reserveId);
    uint256 wethMaxSupply = _calculateMaxSupplyAmount(spoke1, _wethReserveId(spoke1));
    // skip reserves where weth collateral cannot support the borrow
    vm.assume(
      _calcMinimumCollAmount(spoke1, _wethReserveId(spoke1), reserveId, maxSupply / 10) <=
        wethMaxSupply
    );

    (, IERC20 underlying) = _getAssetByReserveId(spoke1, reserveId);

    // alice supplies WETH as collateral, borrows from reserveId
    _executeSpokeSupplyAndBorrow({
      spoke: spoke1,
      collateral: ReserveSetupParams({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        supplyAmount: wethMaxSupply,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: ReserveSetupParams({
        reserveId: reserveId,
        borrowAmount: maxSupply / 10,
        supplyAmount: maxSupply / 5,
        borrower: alice,
        supplier: bob
      }),
      rate: rate,
      isMockRate: true,
      skipTime: skipTime,
      irStrategy: address(irStrategy)
    });

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    uint256 expectedShares = hub1.previewAddByAssets(assetId, amount);
    vm.assume(expectedShares > 0);
    assertGt(amount, expectedShares, 'exchange rate should be > 1');

    uint256 hubBalanceBefore = underlying.balanceOf(address(hub1));
    IHub.SpokeData memory spokeDataBefore = hub1.getSpoke(assetId, address(spoke1));

    assertGt(spokeDataBefore.premiumShares, 0);

    deal(address(underlying), carol, amount);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply({
      reserveId: reserveId,
      caller: carol,
      user: carol,
      suppliedShares: expectedShares,
      suppliedAmount: amount
    });
    _assertRefreshPremiumNotCalled(hub1);
    CheckedSupplyResult memory r = _checkedSupply(
      CheckedSupplyParams({
        spoke: spoke1,
        reserveId: reserveId,
        user: carol,
        amount: amount,
        onBehalfOf: carol
      })
    );

    // return values
    assertEq(r.shares, expectedShares);
    assertEq(r.amount, amount);

    // token balance
    assertEq(underlying.balanceOf(carol), 0, 'user token balance after-supply');
    assertEq(
      underlying.balanceOf(address(hub1)),
      hubBalanceBefore + amount,
      'hub token balance after-supply'
    );
    assertEq(underlying.balanceOf(address(spoke1)), 0, 'spoke token balance after-supply');

    // reserve assertions
    IHub.SpokeData memory spokeDataAfter = hub1.getSpoke(assetId, address(spoke1));
    assertEq(
      spokeDataAfter.drawnShares,
      spokeDataBefore.drawnShares,
      'reserve drawnShares after-supply'
    );
    assertTrue(spokeDataAfter.premiumShares > 0, 'reserve premiumShares after-supply');
    assertEq(
      r.reserveAfter.totalSuppliedShares,
      r.reserveBefore.totalSuppliedShares + expectedShares,
      'reserve addedShares after-supply'
    );
    _assertHubLiquidity(hub1, daiAssetId, 'spoke1.supply');

    // user assertions
    assertEq(r.ownerAfter.position.drawnShares, 0, 'user drawnShares after-supply');
    assertEq(r.ownerAfter.position.premiumShares, 0, 'user premiumShares after-supply');
    assertEq(r.ownerAfter.position.premiumOffsetRay, 0, 'user premiumOffsetRay after-supply');
    assertEq(
      r.ownerAfter.position.suppliedShares,
      expectedShares,
      'user suppliedShares after-supply'
    );
  }

  /// supply an asset with existing debt, with no interest accrual the two ex rates
  /// can increase due to rounding, with interest accrual should strictly increase
  function test_fuzz_supply_effect_on_ex_rates(uint256 amount, uint256 delay) public {
    delay = bound(delay, 1, MAX_SKIP_TIME);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT / 2);
    uint256 wethSupplyAmount = _calcMinimumCollAmount(
      spoke1,
      _wethReserveId(spoke1),
      _daiReserveId(spoke1),
      amount
    );
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: wethSupplyAmount,
      onBehalfOf: bob
    }); // bob collateral
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    }); // introduce debt

    uint256 supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
    uint256 debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    skip(delay); // with interest accrual, both ex rates should strictly

    assertGt(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
    assertGt(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);

    if (hub1.previewAddByAssets(daiAssetId, amount) > 0) {
      supplyExchangeRatio = hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT);
      debtExchangeRatio = hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT);

      SpokeActions.supply({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: alice,
        amount: amount,
        onBehalfOf: alice
      });

      assertGe(hub1.previewRemoveByShares(daiAssetId, MAX_SUPPLY_AMOUNT), supplyExchangeRatio);
      assertGe(hub1.previewRestoreByShares(daiAssetId, MAX_SUPPLY_AMOUNT), debtExchangeRatio);
    }
  }

  /// test that during a supply action with existing debt assets, risk premium is not refreshed
  function test_supply_does_not_update_risk_premium() public {
    _openSupplyPosition(spoke1, _usdxReserveId(spoke1), MAX_SUPPLY_AMOUNT);
    _openSupplyPosition(spoke1, _daiReserveId(spoke1), MAX_SUPPLY_AMOUNT);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 50_000e18,
      onBehalfOf: bob
    }); // bob dai collateral, $50k
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    }); // bob weth collateral, $2k

    // bob borrows 2 assets
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _usdxReserveId(spoke1),
      caller: bob,
      amount: 10_000e6,
      onBehalfOf: bob
    }); // bob borrows usdx, $5k
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: 10_000e18,
      onBehalfOf: bob
    }); // bob borrows dai, $10k

    uint256 initialRP = _getUserRiskPremium(spoke1, bob);
    assertEq(initialRP, _calculateExpectedUserRP(spoke1, bob));

    assertGt(
      _getCollateralRisk(spoke1, _daiReserveId(spoke1)),
      _getCollateralRisk(spoke1, _wethReserveId(spoke1))
    );
    // bob does another supply action of the lower collateral risk reserve
    // risk premium should not be refreshed
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 10_000e18,
      onBehalfOf: bob
    });

    // on-the-fly RP calc does not match initial value
    assertNotEq(_getUserRiskPremium(spoke1, bob), initialRP);
    // debt assets retain the same RP as initial
    assertEq(_calcStoredUserRP(spoke1, _usdxReserveId(spoke1), bob), initialRP);
    assertEq(_calcStoredUserRP(spoke1, _daiReserveId(spoke1), bob), initialRP);
  }

  /// calculate user RP based on stored premium shares / drawn shares
  function _calcStoredUserRP(
    ISpoke spoke,
    uint256 reserveId,
    address user
  ) internal view returns (uint256) {
    ISpoke.UserPosition memory pos = spoke.getUserPosition(reserveId, user);
    return pos.premiumShares.percentDivDown(pos.drawnShares);
  }
}
