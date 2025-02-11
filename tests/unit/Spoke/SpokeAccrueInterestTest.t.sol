// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeAccrueInterestTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 public constant MAX_BPS = 999_99;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function test_accrueInterest_NoActionTaken() public {
    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);
    assertEq(daiInfo.lastUpdateTimestamp, 0);
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.outstandingPremium, 0);
    assertEq(daiInfo.riskPremiumRad, 0);
  }

  function test_accrueInterest_OnlySupply(uint40 elapsed) public {
    uint256 amount = 1000e18;

    // Bob supplies through spoke 1
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, bob, amount, bob);

    // Time passes
    skip(elapsed);

    // Alice does a supply through same spoke to accrue interest
    Utils.spokeSupply(hub, spoke1, spokeInfo[spoke1].dai.reserveId, alice, amount, alice);

    Spoke.Reserve memory daiInfo = spoke1.getReserve(spokeInfo[spoke1].dai.reserveId);

    // Timestamp doesn't update when no interest accrued
    assertEq(daiInfo.lastUpdateTimestamp, 0);
    assertEq(daiInfo.baseDebt, 0);
    assertEq(daiInfo.riskPremiumRad, 0);
    assertEq(daiInfo.outstandingPremium, 0);
  }
}
