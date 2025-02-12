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

  function test_supply() public {
    uint256 amount = 100e18;

    deal(address(tokenList.dai), bob, amount);

    Spoke.UserConfig memory userData = spoke1.getUser(spokeInfo[spoke1].dai.reserveId, bob);
    Spoke.Reserve memory reserveData = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);

    assertEq(tokenList.dai.balanceOf(bob), amount, 'user token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(hub)), 0, 'hub token balance pre-supply');
    assertEq(tokenList.dai.balanceOf(address(spoke1)), 0, 'spoke token balance pre-supply');
    assertEq(userData.suppliedShares, 0, 'user supply shares pre-supply');
    assertEq(reserveData.suppliedShares, 0, 'reserve total shares pre-supply');
    assertEq(userData.baseDebt, 0, 'user base debt pre-supply');

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
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

    vm.prank(bob);
    vm.expectEmit(address(spoke1));
    emit Supplied(spokeInfo[spoke1].dai.reserveId, amount, bob);
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

  // TODO: test supply reverts with 0 amount
  // TODO: test supply with increased index and no premium (where sharesAmount < amount)
  // TODO: test supply with increased increased index and premium
}
