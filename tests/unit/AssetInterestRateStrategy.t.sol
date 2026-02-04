// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

contract AssetInterestRateStrategyTest is Base {
  using WadRayMath for *;
  using SafeCast for uint256;

  uint256 mockAssetId = uint256(keccak256('mockAssetId'));

  IAssetInterestRateStrategy public rateStrategy;
  IAssetInterestRateStrategy.InterestRateData public rateData;
  bytes public encodedRateData;

  function setUp() public override {
    deployFixtures();
    rateStrategy = new AssetInterestRateStrategy(address(hub1));

    rateData = IAssetInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00, // 80.00%
      baseVariableBorrowRate: 2_00, // 2_00%
      variableRateSlope1: 4_00, // 4.00%
      variableRateSlope2: 75_00 // 75.00%
    });
    encodedRateData = abi.encode(rateData);

    vm.prank(address(hub1));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_deploy_revertsWith_InvalidAddress() public {
    vm.expectRevert(IAssetInterestRateStrategy.InvalidAddress.selector);
    new AssetInterestRateStrategy(address(0));
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
    assertEq(rateStrategy.getInterestRateData(mockAssetId), rateData);
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

  function test_setInterestRateData_revertsWith_OnlyHub() public {
    vm.expectRevert(IAssetInterestRateStrategy.OnlyHub.selector);
    vm.prank(makeAddr('randomCaller'));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidOptimalUsageRatio() public {
    uint16[] memory invalidOptimalUsageRatios = new uint16[](2);
    invalidOptimalUsageRatios[0] = rateStrategy.MIN_OPTIMAL_RATIO().toUint16() - 1;
    invalidOptimalUsageRatios[1] = rateStrategy.MAX_OPTIMAL_RATIO().toUint16() + 1;

    for (uint256 i; i < invalidOptimalUsageRatios.length; i++) {
      rateData.optimalUsageRatio = invalidOptimalUsageRatios[i];
      encodedRateData = abi.encode(rateData);
      vm.expectRevert(IAssetInterestRateStrategy.InvalidOptimalUsageRatio.selector);
      vm.prank(address(hub1));
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
    vm.prank(address(hub1));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidMaxRate() public {
    rateData.baseVariableBorrowRate = rateData.variableRateSlope1 = rateData.variableRateSlope2 =
      rateStrategy.MAX_BORROW_RATE().toUint32() /
      3 +
      1;
    encodedRateData = abi.encode(rateData);
    vm.expectRevert(IAssetInterestRateStrategy.InvalidMaxRate.selector);
    vm.prank(address(hub1));
    rateStrategy.setInterestRateData(mockAssetId, encodedRateData);
  }

  function test_setInterestRateData_revertsWith_InvalidRateData() public {
    encodedRateData = abi.encode('invalid');
    vm.expectRevert();
    vm.prank(address(hub1));
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
    emit IAssetInterestRateStrategy.UpdateRateData(
      address(hub1),
      mockAssetId,
      rateData.optimalUsageRatio,
      rateData.baseVariableBorrowRate,
      rateData.variableRateSlope1,
      rateData.variableRateSlope2
    );

    vm.prank(address(hub1));
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
        IBasicInterestRateStrategy.InterestRateDataNotSet.selector,
        mockAssetId2
      )
    );
    rateStrategy.calculateInterestRate({
      assetId: mockAssetId2,
      liquidity: 0,
      drawn: 0,
      deficit: 0,
      swept: 0
    });
  }

  function test_calculateInterestRate_fuzz_ZeroDebt(uint256 liquidity) public view {
    liquidity = bound(liquidity, 0, type(uint120).max);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      liquidity: liquidity,
      drawn: 0,
      deficit: 0,
      swept: 0
    });

    assertEq(variableBorrowRate, rateData.baseVariableBorrowRate.bpsToRay());
  }

  function test_calculateInterestRate_ZeroDebtZeroLiquidity() public view {
    test_calculateInterestRate_fuzz_ZeroDebt(0);
  }

  function test_calculateInterestRate_LeftToKinkPoint(uint256 utilizationRatio) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, 1, rateData.optimalUsageRatio).bpsToRay();

    (
      uint256 liquidity,
      uint256 drawn,
      uint256 deficit,
      uint256 swept
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      liquidity: liquidity,
      drawn: drawn,
      deficit: deficit,
      swept: swept
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay().rayMulUp(utilizationRatioRay).rayDivUp(
        rateData.optimalUsageRatio.bpsToRay()
      );

    if (drawn >= WadRayMath.RAY) {
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
      uint256 liquidity,
      uint256 drawn,
      uint256 deficit,
      uint256 swept
    ) = _generateCalculateInterestRateParams(utilizationRatioRay);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      liquidity: liquidity,
      drawn: drawn,
      deficit: deficit,
      swept: swept
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay() +
      rateData
        .variableRateSlope2
        .bpsToRay()
        .rayMulUp(utilizationRatioRay - rateData.optimalUsageRatio.bpsToRay())
        .rayDivUp(WadRayMath.RAY - rateData.optimalUsageRatio.bpsToRay());

    if (drawn >= WadRayMath.RAY) {
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
  ) internal returns (uint256 liquidity, uint256 drawn, uint256 deficit, uint256 swept) {
    drawn = bound(vm.randomUint(), 1, MAX_SUPPLY_AMOUNT);

    // utilizationRatio = drawn / (drawn + liquidity)
    // utilizationRatio * drawn + utilizationRatio * liquidity = drawn
    // liquidity = drawn * (1 - utilizationRatio) / utilizationRatio
    liquidity = drawn.rayMulUp(WadRayMath.RAY - targetUtilizationRatioRay).rayDivUp(
      targetUtilizationRatioRay
    );
    // Take a random portion of liquidity as swept
    swept = vm.randomUint(0, liquidity);
    liquidity -= swept;

    // deficit unused in the current IR strategy
    deficit = vm.randomUint();
  }
}
