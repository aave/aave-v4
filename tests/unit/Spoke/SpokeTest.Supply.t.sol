// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

contract SpokeSupplyTest is BaseTest {
  function setUp() public override {
    super.setUp();
    super.initEnvironment();
  }

  function test_supply_revertsWith_reserve_not_listed() public {
    uint256 assetId = 5; // invalid assetId
    uint256 amount = 100e18;

    vm.prank(USER1);
    vm.expectRevert(TestErrors.RESERVE_NOT_LISTED);
    spoke1.supply(assetId, amount);
  }

  function test_supply_revertsWith_ERC20InsufficientAllowance() public {
    uint256 amount = 100e18;

    vm.startPrank(bob);
    tokenList.dai.approve(address(hub), amount - 1);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(hub),
        amount - 1,
        amount
      )
    );
    spoke1.supply(daiAssetId, amount);
    vm.stopPrank();
  }

  function test_supply_revertsWith_invalid_supply_amount() public {
    uint256 amount = 0;

    vm.prank(bob);
    vm.expectRevert(TestErrors.INVALID_SUPPLY_AMOUNT);
    spoke1.supply(daiAssetId, amount);
  }

  function test_supply() public {
    uint256 amount = 100e18;

    deal(address(tokenList.dai), bob, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(daiAssetId, USER1);
    Spoke.Reserve memory reserveData = spoke1.getReserve(daiAssetId);

    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    assertEq(userData.suppliedShares, 0, 'user supply shares pre-supply');
    assertEq(reserveData.suppliedShares, 0, 'reserve total shares pre-supply');
    assertEq(userData.baseDebt, 0, 'user base debt pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(daiAssetId, bob, amount);
    spoke1.supply(daiAssetId, amount);

    userData = spoke1.getUser(daiAssetId, bob);
    reserveData = spoke1.getReserve(daiAssetId);

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

  function test_supply_fuzz_amounts(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), bob, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(daiAssetId, bob);
    Spoke.Reserve memory reserveData = spoke1.getReserve(daiAssetId);

    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    assertEq(userData.suppliedShares, 0, 'user supply shares pre-supply');
    assertEq(reserveData.suppliedShares, 0, 'reserve supply shares pre-supply');
    assertEq(userData.baseDebt, 0, 'user base debt pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(daiAssetId, bob, amount);
    spoke1.supply(daiAssetId, amount);

    userData = spoke1.getUser(daiAssetId, bob);
    reserveData = spoke1.getReserve(daiAssetId);

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
}
