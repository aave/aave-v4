// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBaseTest.t.sol';

contract SpokeSupplyTest is SpokeBaseTest {
  using WadRayMath for uint256;

  function test_supply_revertsWith_reserve_not_listed() public {
    uint256 reserveId = spoke1.reserveCount() + 1; // invalid reserveId
    uint256 amount = 100e18;

    vm.prank(bob);
    vm.expectRevert(TestErrors.RESERVE_NOT_LISTED);
    spoke1.supply(reserveId, amount);
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;
    uint256 approvalAmount = amount - 1;

    vm.startPrank(bob);
    tokenList.dai.approve(address(hub), approvalAmount);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        approvalAmount,
        amount
      )
    );
    spoke1.supply(_daiReserveId(spoke1), amount);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_SUPPLY_AMOUNT);
    spoke1.supply(_daiReserveId(spoke1), amount);
  }

  function test_supply() public {
    uint256 amount = 100e18;

    TestData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), mintAmount_DAI, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(daiData[stage].data.suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(daiData[stage].data.lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(bobData[stage].data.suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(bobData[stage].data.lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(_daiReserveId(spoke1), amount, bob);
    spoke1.supply(_daiReserveId(spoke1), amount);

    stage = 1;
    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));

    // dai balance
    assertEq(
      tokenList.dai.balanceOf(bob),
      mintAmount_DAI - amount,
      'user token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    TestData[2] memory bobData;
    TestData[2] memory daiData;
    uint256 stage = 0;

    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(daiData[stage].data.suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(daiData[stage].data.lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(bobData[stage].data.suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(bobData[stage].data.lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.expectEmit(address(spoke1));
    emit Supplied(_daiReserveId(spoke1), amount, bob);
    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), amount);

    stage = 1;
    bobData[stage] = _getUserData(_daiReserveId(spoke1), bob);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(daiData[stage].data.baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(bobData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(bobData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      bobData[stage].data.suppliedShares,
      hub.convertToShares(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      bobData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    // set weth LP to 0 for no premium contribution
    Utils.updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    _increaseShareConversionIndex({
      collateral: TestReserve({
        reserveId: spokeInfo[spoke1].weth.reserveId,
        supplier: alice,
        borrower: address(0),
        borrowAmount: 0,
        supplyAmount: 100e18
      }),
      borrow: TestReserve({
        reserveId: _daiReserveId(spoke1),
        borrowAmount: 10e18,
        supplyAmount: 20e18,
        supplier: bob,
        borrower: alice
      }),
      rate: uint256(10_00).bpsToRay()
    });

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToShares(daiAssetId, amount);
    assertTrue(expectedShares < amount, 'exchange rate should be > 1');

    TestData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = _getUserData(_daiReserveId(spoke1), carol);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(_daiReserveId(spoke1), amount, carol);
    spoke1.supply(_daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = _getUserData(_daiReserveId(spoke1), carol);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      daiData[stage].data.baseDebt,
      daiData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(daiData[stage].data.outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_index_increase_no_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);

    // set weth LP to 0 for no premium contribution
    Utils.updateLiquidityPremium({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      newLiquidityPremium: 0
    });

    _increaseShareConversionIndex({
      collateral: TestReserve({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        borrower: address(0),
        supplyAmount: 100e18,
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: reserveId,
        borrowAmount: 10e18,
        supplyAmount: 20e18,
        supplier: bob,
        borrower: alice
      }),
      rate: rate
    });

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    address asset = spoke1.getReserve(reserveId).asset;

    uint256 expectedShares = hub.convertToShares(assetId, amount);
    vm.assume(expectedShares > 0);
    assertTrue(expectedShares < amount, 'exchange rate should be > 1');

    TestData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = _getUserData(reserveId, carol);
    reserveData[stage] = _getReserveData(reserveId);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    vm.assume(hub.convertToShares(daiAssetId, amount) > 0);

    deal(asset, carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(reserveId, amount, carol);
    spoke1.supply(reserveId, amount);
    stage = 1;

    carolData[stage] = _getUserData(reserveId, carol);
    reserveData[stage] = _getReserveData(reserveId);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    // token balance
    assertEq(IERC20(asset).balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      IERC20(asset).balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(IERC20(asset).balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      reserveData[stage].data.baseDebt,
      reserveData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(
      reserveData[stage].data.outstandingPremium,
      0,
      'reserve outstandingPremium post-supply'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    // alice supplies weth as collateral, borrows dai
    // increase dai share exchange rate
    _increaseShareConversionIndex({
      collateral: TestReserve({
        reserveId: _wethReserveId(spoke1),
        supplyAmount: 100e18,
        supplier: alice,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: _daiReserveId(spoke1),
        borrowAmount: 10e18,
        supplier: bob,
        borrower: alice,
        supplyAmount: 20e18
      }),
      rate: uint256(10_00).bpsToRay()
    });

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToShares(daiAssetId, amount);
    assertTrue(expectedShares < amount, 'exchange rate should be > 1');

    TestData[2] memory carolData;
    TestData[2] memory daiData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = _getUserData(_daiReserveId(spoke1), carol);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    assertTrue(
      daiData[stage].data.outstandingPremium > 0,
      'reserve outstandingPremium post-supply'
    );

    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(_daiReserveId(spoke1), amount, carol);
    spoke1.supply(_daiReserveId(spoke1), amount);
    stage = 1;

    carolData[stage] = _getUserData(_daiReserveId(spoke1), carol);
    daiData[stage] = _getReserveData(_daiReserveId(spoke1));
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    // dai balance
    assertEq(tokenList.dai.balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      tokenList.dai.balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      daiData[stage].data.baseDebt,
      daiData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(
      daiData[stage].data.suppliedShares,
      daiData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      daiData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_index_increase_with_premium(
    uint256 amount,
    uint256 rate,
    uint256 reserveId
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    rate = bound(rate, 1, MAX_BORROW_RATE).bpsToRay();
    reserveId = bound(reserveId, 0, spokeInfo[spoke1].MAX_RESERVE_ID);

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    address asset = spoke1.getReserve(reserveId).asset;

    // alice supplies usdx as collateral, borrows dai
    _increaseShareConversionIndex({
      collateral: TestReserve({
        reserveId: _wethReserveId(spoke1),
        supplier: alice,
        supplyAmount: 100e18,
        borrower: address(0),
        borrowAmount: 0
      }),
      borrow: TestReserve({
        reserveId: reserveId,
        borrowAmount: 10e18,
        supplyAmount: 20e18,
        borrower: alice,
        supplier: bob
      }),
      rate: rate
    });

    uint256 amount = 1e18;
    uint256 expectedShares = hub.convertToShares(assetId, amount);
    vm.assume(expectedShares > 0);
    assertTrue(expectedShares < amount, 'exchange rate should be > 1');

    TestData[2] memory carolData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    carolData[stage] = _getUserData(reserveId, carol);
    reserveData[stage] = _getReserveData(reserveId);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    assertTrue(
      reserveData[stage].data.outstandingPremium > 0,
      'reserve outstandingPremium pre-supply'
    );

    deal(asset, carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(reserveId, amount, carol);
    spoke1.supply(reserveId, amount);

    stage = 1;

    carolData[stage] = _getUserData(reserveId, carol);
    reserveData[stage] = _getReserveData(reserveId);
    tokenData[stage] = _getTokenBalances(asset, address(spoke1));

    // token balance
    assertEq(IERC20(asset).balanceOf(carol), 0, 'user token balance post-supply');
    assertEq(
      IERC20(asset).balanceOf(address(hub)),
      tokenData[stage - 1].hubBalance + amount,
      'hub token balance post-supply'
    );
    assertEq(IERC20(asset).balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(
      reserveData[stage].data.baseDebt,
      reserveData[stage - 1].data.baseDebt,
      'reserve baseDebt post-supply'
    );
    assertTrue(
      reserveData[stage].data.outstandingPremium > 0,
      'reserve outstandingPremium post-supply'
    );
    assertEq(
      reserveData[stage].data.suppliedShares,
      reserveData[stage - 1].data.suppliedShares + expectedShares,
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(carolData[stage].data.baseDebt, 0, 'user baseDebt post-supply');
    assertEq(carolData[stage].data.outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      carolData[stage].data.suppliedShares,
      expectedShares,
      'user suppliedShares post-supply'
    );
    assertEq(
      carolData[stage].data.lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }
}
