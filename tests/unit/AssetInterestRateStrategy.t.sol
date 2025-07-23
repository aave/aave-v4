// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import 'tests/Base.t.sol';

contract AssetInterestRateStrategyTest is Base {
  using WadRayMathExtended for uint16;
  using WadRayMathExtended for uint32;
  using WadRayMathExtended for uint256;

  uint256 mockAssetId = uint256(keccak256('mockAssetId'));

  AssetInterestRateStrategy public rateStrategy;
  IAssetInterestRateStrategy.InterestRateData public rateData;
  bytes public encodedRateData;

  function setUp() public override {
    rateStrategy = new AssetInterestRateStrategy(address(hub));

    rateData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00, // 80.00%
      baseVariableBorrowRate: 2_00, // 2_00%
      variableRateSlope1: 4_00, // 4.00%
      variableRateSlope2: 75_00 // 75.00%
    });
    encodedRateData = abi.encode(rateData);

    vm.prank(address(hub));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_maxBorrowRate() public view {
    assertEq(rateStrategy.MAX_BORROW_RATE(), 1000_00);
  }

  function test_minOptimalRatio() public view {
    assertEq(rateStrategy.MIN_OPTIMAL_RATIO(), 1_00);
  }

  function test_maxOptimalRatio() public view {
    assertEq(rateStrategy.MAX_OPTIMAL_RATIO(), 99_00);
  }

  function test_getInterestRateData() public view {
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

  function test_getOptimalUsageRatio() public view {
    assertEq(rateStrategy.getOptimalUsageRatio(mockAssetId), rateData.optimalUsageRatio);
  }

  function test_getBaseVariableBorrowRate() public view {
    assertEq(rateStrategy.getBaseVariableBorrowRate(mockAssetId), rateData.baseVariableBorrowRate);
  }

  function test_getVariableRateSlope1() public view {
    assertEq(rateStrategy.getVariableRateSlope1(mockAssetId), rateData.variableRateSlope1);
  }

  function test_getVariableRateSlope2() public view {
    assertEq(rateStrategy.getVariableRateSlope2(mockAssetId), rateData.variableRateSlope2);
  }

  function test_getMaxVariableBorrowRate() public view {
    assertEq(
      rateStrategy.getMaxVariableBorrowRate(mockAssetId),
      rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2
    );
  }

  function test_setInterestRateData_revertsWith_OnlyLiquidityHub() public {
    vm.expectRevert(IAssetInterestRateStrategy.OnlyLiquidityHub.selector);
    vm.prank(makeAddr('randomCaller'));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidOptimalUsageRatio() public {
    uint16[] memory invalidOptimalUsageRatios = new uint16[](2);
    invalidOptimalUsageRatios[0] = uint16(rateStrategy.MIN_OPTIMAL_RATIO()) - 1;
    invalidOptimalUsageRatios[1] = uint16(rateStrategy.MAX_OPTIMAL_RATIO()) + 1;

    for (uint256 i; i < invalidOptimalUsageRatios.length; i++) {
      rateData.optimalUsageRatio = invalidOptimalUsageRatios[i];
      encodedRateData = abi.encode(rateData);
      vm.expectRevert(IAssetInterestRateStrategy.InvalidOptimalUsageRatio.selector);
      vm.prank(address(hub));
      rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
    }
  }

  function test_setInterestRateData_revertsWith_Slope2MustBeGteSlope1() public {
    (rateData.variableRateSlope1, rateData.variableRateSlope2) = (
      rateData.variableRateSlope2,
      rateData.variableRateSlope1
    );
    encodedRateData = abi.encode(rateData);
    vm.expectRevert(IAssetInterestRateStrategy.Slope2MustBeGteSlope1.selector);
    vm.prank(address(hub));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidMaxRate() public {
    rateData.baseVariableBorrowRate = rateData.variableRateSlope1 = rateData.variableRateSlope2 =
      uint32(rateStrategy.MAX_BORROW_RATE()) /
      3 +
      1;
    encodedRateData = abi.encode(rateData);
    vm.expectRevert(IAssetInterestRateStrategy.InvalidMaxRate.selector);
    vm.prank(address(hub));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidRateData() public {
    encodedRateData = abi.encode('invalid');
    vm.expectRevert();
    vm.prank(address(hub));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData() public {
    rateData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 60_00, // 60.00%
      baseVariableBorrowRate: 4_00, // 4_00%
      variableRateSlope1: 2_00, // 2.00%
      variableRateSlope2: 30_00 // 30.00%
    });
    encodedRateData = abi.encode(rateData);

    vm.expectEmit(address(rateStrategy));
    emit IAssetInterestRateStrategy.RateDataUpdate(
      mockAssetId,
      uint256(rateData.optimalUsageRatio),
      uint256(rateData.baseVariableBorrowRate),
      uint256(rateData.variableRateSlope1),
      uint256(rateData.variableRateSlope2)
    );

    vm.prank(address(hub));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);

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
      baseDebt: 0,
      premiumDebt: 0
    });
  }

  function test_calculateInterestRate_fuzz_ZeroDebt(uint256 availableLiquidity) public view {
    availableLiquidity = bound(availableLiquidity, 0, type(uint128).max);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      baseDebt: 0,
      premiumDebt: 0
    });

    assertEq(variableBorrowRate, rateData.baseVariableBorrowRate.bpsToRay());
  }

  function test_calculateInterestRate_ZeroDebtZeroLiquidity() public {
    test_calculateInterestRate_fuzz_ZeroDebt(0);
  }

  function test_calculateInterestRate_LeftToKinkPoint(uint256 utilizationRatio) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, 1, rateData.optimalUsageRatio).bpsToRay();

    (
      uint256 availableLiquidity,
      uint256 baseDebt,
      uint256 premiumDebt
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      baseDebt: baseDebt,
      premiumDebt: premiumDebt
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay().rayMulUp(utilizationRatioRay).rayDivUp(
        rateData.optimalUsageRatio.bpsToRay()
      );

    if (baseDebt >= 1e27) {
      assertEq(variableBorrowRate, expectedVariableRate);
    } else {
      assertApproxEqAbs(variableBorrowRate, expectedVariableRate, 0.0001e27);
    }
  }

  function test_calculateInterestRate_AtKinkPoint() public {
    test_calculateInterestRate_LeftToKinkPoint(100_00);
  }

  function test_calculateInterestRate_RightToKinkPoint(uint256 utilizationRatio) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, rateData.optimalUsageRatio + 1, 100_00)
      .bpsToRay();

    (
      uint256 availableLiquidity,
      uint256 baseDebt,
      uint256 premiumDebt
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      availableLiquidity: availableLiquidity,
      baseDebt: baseDebt,
      premiumDebt: premiumDebt
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay() +
      rateData
        .variableRateSlope2
        .bpsToRay()
        .rayMulUp(utilizationRatioRay - rateData.optimalUsageRatio.bpsToRay())
        .rayDivUp(WadRayMathExtended.RAY - rateData.optimalUsageRatio.bpsToRay());

    if (baseDebt >= 1e27) {
      assertEq(variableBorrowRate, expectedVariableRate);
    } else {
      assertApproxEqAbs(variableBorrowRate, expectedVariableRate, 0.0001e27);
    }
  }

  function test_calculateInterestRate_AtMaxUtilization() public {
    test_calculateInterestRate_RightToKinkPoint(100_00);
  }

  function _generateCalculateInterestRateParams(
    uint256 targetUtilizationRatioRay
  ) internal returns (uint256 availableLiquidity, uint256 baseDebt, uint256 premiumDebt) {
    baseDebt = bound(vm.randomUint(), 1, MAX_SUPPLY_AMOUNT);

    // utilizationRatio = baseDebt / (baseDebt + availableLiquidity)
    // utilizationRatio * baseDebt + utilizationRatio * availableLiquidity = baseDebt
    // availableLiquidity = baseDebt * (1 - utilizationRatio) / utilizationRatio
    availableLiquidity = baseDebt
      .rayMulUp(WadRayMathExtended.RAY - targetUtilizationRatioRay)
      .rayDivUp(targetUtilizationRatioRay);

    // unused in the current IR strategy
    premiumDebt = vm.randomUint();
  }
}
