// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeWithdrawTest is BaseTest {
  using WadRayMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_withdraw_revertsWith_supplied_amount_exceeded_zero_supplied() public {
    uint256 assetId = 0;
    uint256 amount = 1;

    vm.prank(address(spoke1));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    hub.withdraw({assetId: assetId, amount: amount, riskPremium: 0, to: address(spoke1)});
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

    // advance time
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

    // advance time
    skip(365 days);

    vm.prank(address(alice));
    vm.expectRevert(TestErrors.SUPPLIED_AMOUNT_EXCEEDED);
    spoke1.withdraw({reserveId: reserveId, amount: amount - borrowAmount + 1, to: alice});
  }
}
