// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

/// TODO: Access Control; Check that only authorized address can set interest rate data
contract AssetInterestRateStrategyTest is Base {
  using WadRayMathExtended for uint16;
  using WadRayMathExtended for uint32;
  using WadRayMathExtended for uint256;

  uint256 mockAssetId = uint256(keccak256('mockAssetId'));

  AssetInterestRateStrategy public rateStrategy;
  IAssetInterestRateStrategy.InterestRateData public rateData;

  function setUp() public override {
    rateStrategy = new AssetInterestRateStrategy();

    rateData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00, // 80.00%
      baseVariableBorrowRate: 2_00, // 2_00%
      variableRateSlope1: 4_00, // 4.00%
      variableRateSlope2: 75_00 // 75.00%
    });

    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_maxBorrowRate() public {
    assertEq(rateStrategy.MAX_BORROW_RATE(), 1000_00);
  }

  function test_minOptimalRatio() public {
    assertEq(rateStrategy.MIN_OPTIMAL_RATIO(), 1_00);
  }

  function test_maxOptimalRatio() public {
    assertEq(rateStrategy.MAX_OPTIMAL_RATIO(), 99_00);
  }

  function test_getInterestRateData() public {
    assertEq(
      rateStrategy.getInterestRateData(mockAssetId).optimalUsageRatio,
      rateData.optimalUsageRatio
    );
    assertEq(
      rateStrategy.getInterestRateData(mockAssetId).baseVariableBorrowRate,
      rateData.baseVariableBorrowRate
    );
    assertEq(
      rateStrategy.getInterestRateData(mockAssetId).variableRateSlope1,
      rateData.variableRateSlope1
    );
    assertEq(
      rateStrategy.getInterestRateData(mockAssetId).variableRateSlope2,
      rateData.variableRateSlope2
    );
  }

  function test_getOptimalUsageRatio() public {
    assertEq(rateStrategy.getOptimalUsageRatio(mockAssetId), rateData.optimalUsageRatio);
  }

  function test_getBaseVariableBorrowRate() public {
    assertEq(rateStrategy.getBaseVariableBorrowRate(mockAssetId), rateData.baseVariableBorrowRate);
  }

  function test_getVariableRateSlope1() public {
    assertEq(rateStrategy.getVariableRateSlope1(mockAssetId), rateData.variableRateSlope1);
  }

  function test_getVariableRateSlope2() public {
    assertEq(rateStrategy.getVariableRateSlope2(mockAssetId), rateData.variableRateSlope2);
  }

  function test_getMaxVariableBorrowRate() public {
    assertEq(
      rateStrategy.getMaxVariableBorrowRate(mockAssetId),
      rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2
    );
  }

  function test_setInterestRateData_revertsWith_InvalidOptimalUsageRatio() public {
    uint16[] memory invalidOptimalUsageRatios = new uint16[](2);
    invalidOptimalUsageRatios[0] = uint16(rateStrategy.MIN_OPTIMAL_RATIO()) - 1;
    invalidOptimalUsageRatios[1] = uint16(rateStrategy.MAX_OPTIMAL_RATIO()) + 1;

    for (uint256 i; i < invalidOptimalUsageRatios.length; i++) {
      rateData.optimalUsageRatio = invalidOptimalUsageRatios[i];
      vm.expectRevert(IAssetInterestRateStrategy.InvalidOptimalUsageRatio.selector);
      rateStrategy.setInterestRateData(mockAssetId, rateData);
    }
  }

  function test_setInterestRateData_revertsWith_Slope2MustBeGteSlope1() public {
    (rateData.variableRateSlope1, rateData.variableRateSlope2) = (
      rateData.variableRateSlope2,
      rateData.variableRateSlope1
    );
    vm.expectRevert(IAssetInterestRateStrategy.Slope2MustBeGteSlope1.selector);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_setInterestRateData_revertsWith_InvalidMaxRate() public {
    rateData.baseVariableBorrowRate = rateData.variableRateSlope1 = rateData.variableRateSlope2 =
      uint32(rateStrategy.MAX_BORROW_RATE()) /
      3 +
      1;
    vm.expectRevert(IAssetInterestRateStrategy.InvalidMaxRate.selector);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_setInterestRateData() public {
    rateData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 60_00, // 60.00%
      baseVariableBorrowRate: 4_00, // 4_00%
      variableRateSlope1: 2_00, // 2.00%
      variableRateSlope2: 30_00 // 30.00%
    });

    vm.expectEmit(address(rateStrategy));
    emit IAssetInterestRateStrategy.RateDataUpdate(
      mockAssetId,
      uint256(rateData.optimalUsageRatio),
      uint256(rateData.baseVariableBorrowRate),
      uint256(rateData.variableRateSlope1),
      uint256(rateData.variableRateSlope2)
    );

    rateStrategy.setInterestRateData(mockAssetId, rateData);

    test_getInterestRateData();
    test_getOptimalUsageRatio();
    test_getBaseVariableBorrowRate();
    test_getVariableRateSlope1();
    test_getVariableRateSlope2();
    test_getMaxVariableBorrowRate();
  }

  function test_calculateInterestRate_revertsWith_InterestRateDataNotSet() public {
    uint256 mockAssetId2 = uint256(keccak256('mockAssetId2'));
    vm.expectRevert(
      abi.encodeWithSelector(
        IAssetInterestRateStrategy.InterestRateDataNotSet.selector,
        mockAssetId2
      )
    );
    rateStrategy.calculateInterestRate({
      assetId: mockAssetId2,
      availableLiquidity: 0,
      totalDebt: 0,
      liquidityAdded: 0,
      liquidityTaken: 0
    });
  }

  function test_calculateInterestRate_fuzz_revertsWith_ArithmeticUnderflow(
    uint256 totalDebt,
    uint256 availableLiquidity,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) public {
    availableLiquidity = bound(availableLiquidity, 0, type(uint64).max);
    totalDebt = bound(totalDebt, 1, type(uint64).max);
    liquidityAdded = bound(liquidityAdded, 0, type(uint64).max);
    liquidityTaken = bound(
      liquidityTaken,
      availableLiquidity + liquidityAdded + 1,
      type(uint128).max
    );

    vm.expectRevert(stdError.arithmeticError);
    rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      totalDebt: totalDebt,
      liquidityAdded: liquidityAdded,
      liquidityTaken: liquidityTaken
    });
  }

  function test_calculateInterestRate_revertsWith_ArithmeticUnderflow() public {
    test_calculateInterestRate_fuzz_revertsWith_ArithmeticUnderflow({
      availableLiquidity: 100e6,
      totalDebt: 100e6,
      liquidityAdded: 10e6,
      liquidityTaken: 120e6
    });
  }

  function test_calculateInterestRate_fuzz_ZeroDebt(
    uint256 availableLiquidity,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) public {
    availableLiquidity = bound(availableLiquidity, 0, type(uint128).max);
    liquidityAdded = bound(liquidityAdded, 0, type(uint128).max);
    liquidityTaken = bound(liquidityTaken, 0, availableLiquidity + liquidityAdded);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      totalDebt: 0,
      liquidityAdded: liquidityAdded,
      liquidityTaken: liquidityTaken
    });

    assertEq(variableBorrowRate, rateData.baseVariableBorrowRate.bpsToRay());
  }

  function test_calculateInterestRate_ZeroDebtZeroLiquidity() public {
    test_calculateInterestRate_fuzz_ZeroDebt(0, 0, 0);
  }

  function test_calculateInterestRate_LeftToKinkPoint(uint256 utilizationRatio, uint256) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, 1, rateData.optimalUsageRatio).bpsToRay();

    (
      uint256 availableLiquidity,
      uint256 totalDebt,
      uint256 liquidityAdded,
      uint256 liquidityTaken
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      totalDebt: totalDebt,
      liquidityAdded: liquidityAdded,
      liquidityTaken: liquidityTaken
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay().rayMulUp(utilizationRatioRay).rayDivUp(
        rateData.optimalUsageRatio.bpsToRay()
      );

    if (totalDebt >= 1e27) {
      assertEq(variableBorrowRate, expectedVariableRate);
    } else {
      assertApproxEqAbs(variableBorrowRate, expectedVariableRate, 0.0001e27);
    }
  }

  function test_calculateInterestRate_AtKinkPoint() public {
    test_calculateInterestRate_LeftToKinkPoint(100_00, 100e18);
  }

  function test_calculateInterestRate_RightToKinkPoint(uint256 utilizationRatio, uint256) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, rateData.optimalUsageRatio + 1, 100_00)
      .bpsToRay();

    (
      uint256 availableLiquidity,
      uint256 totalDebt,
      uint256 liquidityAdded,
      uint256 liquidityTaken
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      totalDebt: totalDebt,
      liquidityAdded: liquidityAdded,
      liquidityTaken: liquidityTaken
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay() +
      rateData
        .variableRateSlope2
        .bpsToRay()
        .rayMulUp(utilizationRatioRay - rateData.optimalUsageRatio.bpsToRay())
        .rayDivUp(WadRayMathExtended.RAY - rateData.optimalUsageRatio.bpsToRay());

    if (totalDebt >= 1e27) {
      assertEq(variableBorrowRate, expectedVariableRate);
    } else {
      assertApproxEqAbs(variableBorrowRate, expectedVariableRate, 0.0001e27);
    }
  }

  function test_calculateInterestRate_AtMaxUtilization() public {
    test_calculateInterestRate_RightToKinkPoint(100_00, 100e18);
  }

  function _generateCalculateInterestRateParams(
    uint256 targetUtilizationRatioRay
  )
    internal
    returns (
      uint256 availableLiquidity,
      uint256 totalDebt,
      uint256 liquidityAdded,
      uint256 liquidityTaken
    )
  {
    totalDebt = bound(vm.randomUint(), 1, MAX_SUPPLY_AMOUNT);

    // utilizationRatio = totalDebt / (totalDebt + updatedAvailableLiquidity)
    // utilizationRatio * totalDebt + utilizationRatio * updatedAvailableLiquidity = totalDebt
    // updatedAvailableLiquidity = totalDebt * (1 - utilizationRatio) / utilizationRatio
    uint256 updatedAvailableLiquidity = totalDebt
      .rayMulUp(WadRayMathExtended.RAY - targetUtilizationRatioRay)
      .rayDivUp(targetUtilizationRatioRay);

    availableLiquidity = bound(vm.randomUint(), 0, updatedAvailableLiquidity);
    liquidityAdded = bound(
      vm.randomUint(),
      updatedAvailableLiquidity - availableLiquidity,
      updatedAvailableLiquidity
    );
    liquidityTaken = availableLiquidity + liquidityAdded - updatedAvailableLiquidity;
  }
}
