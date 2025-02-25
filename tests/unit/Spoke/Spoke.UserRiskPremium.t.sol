// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeUserRiskPremiumTest is BaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 rate;
  function setUp() public override {
    super.setUp();
    initEnvironment();

    rate = uint256(10_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );
  }

  struct RPBasicTestData {
    uint256 daiReserveId;
    uint256 usdxReserveId;
    uint256 suppliedAmount;
    uint40 lastUpdateTimestamp;
    uint256 existingBaseDebt;
    uint256 cumulatedBaseInterest;
    uint256 cumulatedBaseDebt;
    uint256 cumulatedOutstandingPremium;
    uint256 userRiskPremiumStorage;
    uint256 userRiskPremiumFly;
    uint256 expectedUserRiskPremium;
    uint256 expectedOutstandingPremium;
  }

  function test_user_rp_single_asset() public {
    RPBasicTestData memory state;

    state.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    state.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    state.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    // bob supplies dai
    vm.prank(bob);
    spoke1.supply({reserveId: state.daiReserveId, amount: 100e18});

    // alice supplies usdx
    vm.startPrank(alice);
    spoke1.supply({reserveId: state.usdxReserveId, amount: 100e18});
    spoke1.setUsingAsCollateral(state.usdxReserveId, true);

    // alice borrows dai
    spoke1.borrow({reserveId: state.daiReserveId, amount: 10e18, to: alice});

    state.userRiskPremiumStorage = spoke1.getUserData(alice).riskPremium;
    state.userRiskPremiumFly = spoke1.getUserRiskPremium(alice);

    assertEq(
      state.userRiskPremiumFly,
      spoke1.getReserve(state.usdxReserveId).config.liquidityPremium,
      'user RP on the fly should match reserve LP'
    );
    assertEq(
      state.userRiskPremiumStorage.derayify(),
      spoke1.getReserve(state.usdxReserveId).config.liquidityPremium,
      'user RP in storage should match reserve LP'
    );

    state.existingBaseDebt = spoke1.getUser(state.daiReserveId, alice).baseDebt;

    // alice accrues debt and premium
    skip(365 days);

    (state.cumulatedBaseDebt, state.cumulatedOutstandingPremium) = spoke1.getUserDebt(
      spokeInfo[spoke1].dai.reserveId,
      alice
    );
    state.cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      state.lastUpdateTimestamp
    );
    state.expectedOutstandingPremium = (state.existingBaseDebt.rayMul(state.cumulatedBaseInterest) -
      state.existingBaseDebt).percentMul(state.userRiskPremiumFly);

    assertEq(
      state.expectedOutstandingPremium,
      state.cumulatedOutstandingPremium,
      'outstanding premium after accrual'
    );
  }

  function test_fuzz_user_rp_single_asset(uint256 skipTime, uint256 borrowedAmount) public {
    skipTime = bound(skipTime, 1, 10_000 days);

    RPBasicTestData memory state;
    state.suppliedAmount = 100e18;
    borrowedAmount = bound(borrowedAmount, 1e10, state.suppliedAmount);

    state.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    state.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    state.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    // bob supplies dai
    vm.prank(bob);
    spoke1.supply({reserveId: state.daiReserveId, amount: 100e18});

    // alice supplies usdx
    vm.startPrank(alice);
    spoke1.supply({reserveId: state.usdxReserveId, amount: 100e18});
    spoke1.setUsingAsCollateral(state.usdxReserveId, true);

    // alice borrows dai
    spoke1.borrow({reserveId: state.daiReserveId, amount: borrowedAmount, to: alice});

    state.userRiskPremiumStorage = spoke1.getUserData(alice).riskPremium;
    state.userRiskPremiumFly = spoke1.getUserRiskPremium(alice);

    assertEq(
      state.userRiskPremiumFly,
      spoke1.getReserve(state.usdxReserveId).config.liquidityPremium,
      'user RP on the fly should match reserve LP'
    );
    assertEq(
      state.userRiskPremiumStorage.derayify(),
      spoke1.getReserve(state.usdxReserveId).config.liquidityPremium,
      'user RP in storage should match reserve LP'
    );

    state.existingBaseDebt = spoke1.getUser(state.daiReserveId, alice).baseDebt;

    // alice accrues debt and premium
    skip(skipTime);

    (state.cumulatedBaseDebt, state.cumulatedOutstandingPremium) = spoke1.getUserDebt(
      spokeInfo[spoke1].dai.reserveId,
      alice
    );
    state.cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      state.lastUpdateTimestamp
    );
    state.expectedOutstandingPremium = (state.existingBaseDebt.rayMul(state.cumulatedBaseInterest) -
      state.existingBaseDebt).percentMul(state.userRiskPremiumFly);

    assertEq(
      state.expectedOutstandingPremium,
      state.cumulatedOutstandingPremium,
      'outstanding premium after accrual'
    );
  }

  // TODO: test on repay
  // TODO: test on multiple assets
}
