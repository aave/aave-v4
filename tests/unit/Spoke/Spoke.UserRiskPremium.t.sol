// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

import 'tests/BaseTest.t.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeUserRiskPremiumTest is BaseTest {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  struct RPBasicTestData {
    uint256 daiReserveId;
    uint256 usdxReserveId;
    uint256 suppliedAmount;
    uint40 lastUpdateTimestamp;
    uint256 existingBaseDebt;
    uint256 existingOutstandingPremium;
    uint256 cumulatedBaseInterest;
    uint256 cumulatedBaseDebt;
    uint256 cumulatedOutstandingPremium;
    uint256 userRiskPremiumStorage;
    uint256 userRiskPremiumFly;
    uint256 expectedUserRiskPremium;
    uint256 expectedOutstandingPremium;
    uint256[5] borrowedAmount;
  }

  function test_user_rp_single_asset() public {
    RPBasicTestData memory state;

    uint256 rate = uint256(10_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

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

  function test_user_rp_single_asset_multi_borrow() public {
    RPBasicTestData memory state;

    uint256 rate = uint256(10_00).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    state.daiReserveId = spokeInfo[spoke1].dai.reserveId;
    state.usdxReserveId = spokeInfo[spoke1].usdx.reserveId;
    state.borrowedAmount[0] = 10e18;
    state.borrowedAmount[1] = 20e18;

    // bob supplies dai
    vm.prank(bob);
    spoke1.supply({reserveId: state.daiReserveId, amount: 100e18});

    // alice supplies usdx
    vm.startPrank(alice);
    spoke1.supply({reserveId: state.usdxReserveId, amount: 100e18});
    spoke1.setUsingAsCollateral(state.usdxReserveId, true);

    // alice borrows dai
    spoke1.borrow({reserveId: state.daiReserveId, amount: state.borrowedAmount[0], to: alice});

    // alice accrues debt and premium
    skip(365 days);
    // alice borrows more dai
    spoke1.borrow({reserveId: state.daiReserveId, amount: state.borrowedAmount[1], to: alice});
    (state.existingBaseDebt, state.existingOutstandingPremium) = spoke1.getUserDebt(
      spokeInfo[spoke1].dai.reserveId,
      alice
    );
    state.userRiskPremiumFly = spoke1.getUserRiskPremium(alice);
    state.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    // alice accrues debt and premium
    skip(365 days);

    state.cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      rate,
      state.lastUpdateTimestamp
    );

    (state.cumulatedBaseDebt, state.cumulatedOutstandingPremium) = spoke1.getUserDebt(
      spokeInfo[spoke1].dai.reserveId,
      alice
    );

    state.expectedOutstandingPremium =
      (state.existingBaseDebt.rayMul(state.cumulatedBaseInterest) - state.existingBaseDebt)
        .percentMul(spoke1.getReserve(state.usdxReserveId).config.liquidityPremium) +
      state.existingOutstandingPremium;

    assertEq(
      state.expectedOutstandingPremium,
      state.cumulatedOutstandingPremium,
      'outstanding premium after accrual'
    );
  }

  function test_fuzz_user_rp_single_asset(
    uint256 rate,
    uint256 skipTime,
    uint256 borrowedAmount
  ) public {
    skipTime = bound(skipTime, 1, 10_000 days);
    rate = uint256(bound(rate, 1, MAX_BORROW_RATE)).bpsToRay();

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

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
