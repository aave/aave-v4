// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeSupplyTest is BaseTest {
  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

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

  // TODO: change all assertions to be from getters instead of internal storage

  struct TestData {
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 lastUpdateTimestamp;
  }

  function _getReserveData(uint256 reserveId) internal returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.Reserve memory reserveStorageData = spoke1.getReserve(reserveId);
    TestData memory reserveData;
    (reserveData.baseDebt, reserveData.outstandingPremium) = spoke1.getReserveDebt(reserveId);
    reserveData.suppliedShares = spoke1.getReserveSuppliedShares(reserveId);
    reserveData.lastUpdateTimestamp = reserveStorageData.lastUpdateTimestamp;
    return reserveData;
  }

  function _getUserData(uint256 reserveId, address user) internal returns (TestData memory) {
    // only to check lastUpdateTimestamp
    Spoke.UserConfig memory userStorageData = spoke1.getUser(reserveId, user);
    TestData memory userData;
    (userData.baseDebt, userData.outstandingPremium) = spoke1.getUserDebt(reserveId, user);
    userData.suppliedShares = spoke1.getUserSuppliedShares(reserveId, user);
    userData.lastUpdateTimestamp = userStorageData.lastUpdateTimestamp;
    return userData;
  }

  function test_supply() public {
    uint256 amount = 100e18;

    deal(address(tokenList.dai), bob, amount);

    TestData[2] memory userData;
    TestData[2] memory reserveData;
    uint256 t = 0;

    userData[t] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[t] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    // reserve
    assertEq(reserveData[t].baseDebt, 0, 'reserve baseDebt pre-supply');
    assertEq(reserveData[t].outstandingPremium, 0, 'reserve outstandingPremium pre-supply');
    assertEq(reserveData[t].suppliedShares, 0, 'reserve suppliedShares pre-supply');
    // user
    assertEq(userData[t].baseDebt, 0, 'user baseDebt pre-supply');
    assertEq(userData[t].outstandingPremium, 0, 'user outstandingPremium pre-supply');
    assertEq(userData[t].suppliedShares, 0, 'user suppliedShares pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);

    t = 1;
    userData[t] = _getUserData(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData[t] = _getReserveData(spokeInfo[spoke1].dai.reserveId);

    // dai balance
    assertEq(tokenList.dai.balanceOf(bob), 0);
    assertEq(tokenList.dai.balanceOf(address(hub)), amount);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    // reserve
    assertEq(reserveData[t].baseDebt, 0, 'reserve baseDebt post-supply');
    assertEq(reserveData[t].outstandingPremium, 0, 'reserve outstandingPremium post-supply');
    assertEq(
      reserveData[t].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'reserve suppliedShares post-supply'
    );
    // user
    assertEq(userData[t].baseDebt, 0, 'user baseDebt post-supply');
    assertEq(userData[t].outstandingPremium, 0, 'user outstandingPremium post-supply');
    assertEq(
      userData[t].suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user suppliedShares post-supply'
    );
  }

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
    Spoke.Reserve memory reserveData = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);

    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    assertEq(userData.suppliedShares, 0, 'user supply shares pre-supply');
    assertEq(reserveData.suppliedShares, 0, 'reserve supply shares pre-supply');
    assertEq(userData.baseDebt, 0, 'user base debt pre-supply');

    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
    vm.prank(bob);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);

    userData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
    reserveData = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);

    assertEq(tokenList.dai.balanceOf(bob), 0);
    assertEq(tokenList.dai.balanceOf(address(hub)), amount);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance post-supply');
    assertEq(
      userData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'user supply shares post-supply'
    );
    assertEq(
      reserveData.suppliedShares,
      hub.convertToSharesDown(daiAssetId, amount),
      'reserve supplied shares post-supply'
    );
    assertEq(userData.baseDebt, 0, 'user base debt post-supply');
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_SUPPLY_AMOUNT);
    spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
  }

  // function test_supply_index_increase_no_premium() public {
  //   // Alice supply/draw to start index
  //   // asset with LP = 0
  //   // time skip to increase index

  //   vm.expectEmit(address(spoke1));
  //   emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);

  //   vm.prank(bob);
  //   spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
  // }

  // function test_supply_fuzz_index_increase_no_premium() public {
  //   // fuzz supply/draw amount for alice
  //   // fuzz supply amount for bob

  //   // Alice supply/draw to start index
  //   // asset with LP = 0
  //   // time skip to increase index

  //   vm.expectEmit(address(spoke1));
  //   emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);

  //   vm.prank(bob);
  //   spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
  // }

  // function test_supply_fuzz_index_increase_with_premium() public {
  //   // fuzz supply/draw amount for Alice
  //   // fuzz supply amount for bob

  //   // Alice supply/draw to start index
  //   // asset with LP > 0
  //   // time skip to increase index

  //   vm.expectEmit(address(spoke1));
  //   emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);

  //   vm.prank(bob);
  //   spoke1.supply(spokeInfo[spoke1].dai.reserveId, amount);
  // }
}
