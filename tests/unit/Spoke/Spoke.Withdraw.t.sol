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
}
