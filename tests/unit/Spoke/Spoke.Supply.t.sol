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
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_SUPPLY_AMOUNT);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
  }

  function test_supply() public {
    uint256 amount = 100e18;

    deal(address(tokenList.dai), bob, amount);

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(reserveData[stage].baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(reserveData[stage].suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(reserveData[stage].lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(userData[stage].suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(userData[stage].lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);

    stage = 1;
    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(reserveData[stage].baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(reserveData[stage].baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(reserveData[stage].suppliedShares, 0, 'reserve suppliedShares pre-supply');
    assertEq(reserveData[stage].lastUpdateTimestamp, 0, 'reserve lastUpdateTimestamp pre-supply');
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(userData[stage].suppliedShares, 0, 'user suppliedShares pre-supply');
    assertEq(userData[stage].lastUpdateTimestamp, 0, 'user lastUpdateTimestamp pre-supply');

    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);

    stage = 1;
    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0, 'user token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), amount, 'hub token balance post-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(reserveData[stage].baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_no_premium() public {
    _increaseShareConversionIndex({
      collateral: CollateralReserve({reserveId: spokeInfo[spoke1].weth.reserveId, amount: 100e18}),
      borrow: BorrowReserve({
        reserveId: spokeInfo[spoke1].dai.reserveId,
        amount: 10e18,
        supplier: bob
      }),
      borrower: alice,
      rate: uint256(10_00).bpsToRay()
    });

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    uint256 amount = 1e18;
    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, carol);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
    stage = 1;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
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
      reserveData[stage].baseDebt,
      reserveData[stage - 1].baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      reserveData[stage - 1].suppliedShares + hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_index_increase_no_premium(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    _increaseShareConversionIndex({
      collateral: CollateralReserve({reserveId: spokeInfo[spoke1].weth.reserveId, amount: 100e18}),
      borrow: BorrowReserve({
        reserveId: spokeInfo[spoke1].dai.reserveId,
        amount: 10e18,
        supplier: bob
      }),
      borrower: alice,
      rate: uint256(10_00).bpsToRay()
    });

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    vm.assume(hub.convertToShares(daiAssetId, amount) > 0);

    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, carol);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
    stage = 1;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
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
      reserveData[stage].baseDebt,
      reserveData[stage - 1].baseDebt,
      'reserve baseDebt post-supply'
    );
    assertEq(reserveData[stage].outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      reserveData[stage - 1].suppliedShares + hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_index_increase_with_premium() public {
    // alice supplies usdx as collateral, borrows dai
    _increaseShareConversionIndex({
      collateral: CollateralReserve({reserveId: spokeInfo[spoke1].usdx.reserveId, amount: 100e18}),
      borrow: BorrowReserve({
        reserveId: spokeInfo[spoke1].dai.reserveId,
        amount: 10e18,
        supplier: bob
      }),
      borrower: alice,
      rate: uint256(10_00).bpsToRay()
    });

    // action on the borrowed reserve to trigger risk premium
    // TODO: shouldnt be needed after RP accrual is fixed
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: spokeInfo[spoke1].dai.reserveId,
      user: alice,
      amount: 1e18,
      to: alice
    });
    skip(365 days);

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    assertTrue(reserveData[stage].outstandingPremium > 0, 'reserve outstandingPremium pre-supply');

    uint256 amount = 1e18;
    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, carol);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
    stage = 1;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
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
      reserveData[stage].baseDebt,
      reserveData[stage - 1].baseDebt,
      'reserve baseDebt post-supply'
    );
    assertTrue(reserveData[stage].outstandingPremium > 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      reserveData[stage - 1].suppliedShares + hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }

  function test_supply_fuzz_index_increase_with_premium(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    // alice supplies usdx as collateral, borrows dai
    _increaseShareConversionIndex({
      collateral: CollateralReserve({reserveId: spokeInfo[spoke1].usdx.reserveId, amount: 100e18}),
      borrow: BorrowReserve({
        reserveId: spokeInfo[spoke1].dai.reserveId,
        amount: 10e18,
        supplier: bob
      }),
      borrower: alice,
      rate: uint256(10_00).bpsToRay()
    });

    // action on the borrowed reserve to trigger risk premium
    // TODO: shouldnt be needed after RP accrual is fixed
    Utils.spokeSupply({
      hub: hub,
      spoke: spoke1,
      reserveId: spokeInfo[spoke1].dai.reserveId,
      user: alice,
      amount: 1e18,
      to: alice
    });
    skip(365 days);

    vm.assume(hub.convertToShares(daiAssetId, amount) > 0);

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    TokenData[2] memory tokenData;
    uint256 stage = 0;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
    tokenData[stage] = _getTokenBalances(address(tokenList.dai), address(spoke1));

    assertTrue(reserveData[stage].outstandingPremium > 0, 'reserve outstandingPremium pre-supply');

    uint256 amount = 1e18;
    deal(address(tokenList.dai), carol, amount);

    vm.prank(carol);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, carol);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
    stage = 1;

    userData[stage] = _getUserData(spokeInfo[spoke1].dai.reserveId, carol);
    reserveData[stage] = _getReserveData(spokeInfo[spoke1].dai.reserveId);
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
      reserveData[stage].baseDebt,
      reserveData[stage - 1].baseDebt,
      'reserve baseDebt post-supply'
    );
    assertTrue(reserveData[stage].outstandingPremium > 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[stage].suppliedShares,
      reserveData[stage - 1].suppliedShares + hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    assertEq(
      reserveData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'reserve lastUpdateTimestamp post-supply'
    );
    // user
    assertEq(userData[stage].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[stage].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[stage].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
    assertEq(
      userData[stage].lastUpdateTimestamp,
      vm.getBlockTimestamp(),
      'user lastUpdateTimestamp post-supply'
    );
  }
}
