// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {DefaultAssetInterestRateStrategy, IDefaultInterestRateStrategy} from 'src/contracts/DefaultAssetInterestRateStrategy.sol';

import {Test} from 'forge-std/Test.sol';

/// TODO: Access Control; Check that only authorized address can set interest rate data
contract DefaultAssetInterestRateStrategyTest is Test {
  using WadRayMath for uint16;
  using WadRayMath for uint32;
  using WadRayMath for uint256;

  uint256 mockAssetId = uint256(keccak256('mockAssetId'));

  DefaultAssetInterestRateStrategy public rateStrategy;
  IDefaultInterestRateStrategy.InterestRateData public rateData;

  function setUp() public {
    rateStrategy = new DefaultAssetInterestRateStrategy();

    rateData = IDefaultInterestRateStrategy.InterestRateData({
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
      vm.expectRevert(IDefaultInterestRateStrategy.InvalidOptimalUsageRatio.selector);
      rateStrategy.setInterestRateData(mockAssetId, rateData);
    }
  }

  function test_setInterestRateData_revertsWith_Slope2MustBeGteSlope1() public {
    (rateData.variableRateSlope1, rateData.variableRateSlope2) = (
      rateData.variableRateSlope2,
      rateData.variableRateSlope1
    );
    vm.expectRevert(IDefaultInterestRateStrategy.Slope2MustBeGteSlope2.selector);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_setInterestRateData_revertsWith_InvalidMaxRate() public {
    rateData.baseVariableBorrowRate = rateData.variableRateSlope1 = rateData.variableRateSlope2 =
      uint32(rateStrategy.MAX_BORROW_RATE()) /
      3 +
      1;
    vm.expectRevert(IDefaultInterestRateStrategy.InvalidMaxRate.selector);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_setInterestRateData() public {
    rateData = IDefaultInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 60_00, // 60.00%
      baseVariableBorrowRate: 4_00, // 4_00%
      variableRateSlope1: 2_00, // 2.00%
      variableRateSlope2: 30_00 // 30.00%
    });

    vm.expectEmit(address(rateStrategy));
    emit IDefaultInterestRateStrategy.RateDataUpdate(
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
        IDefaultInterestRateStrategy.InterestRateDataNotSet.selector,
        mockAssetId2
      )
    );
    rateStrategy.calculateInterestRate({
      assetId: mockAssetId2,
      totalDebt: 0,
      availableLiquidity: 0
    });
  }

  function test_calculateInterestRate_fuzz_ZeroDebt(uint256 availableLiquidity) public {
    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      totalDebt: 0,
      availableLiquidity: availableLiquidity
    });

    assertEq(variableBorrowRate, rateData.baseVariableBorrowRate.bpsToRay());
  }

  function test_calculateInterestRate_ZeroDebtZeroLiquidity() public {
    test_calculateInterestRate_fuzz_ZeroDebt(0);
  }

  function test_calculateInterestRate_LeftToKinkPoint(
    uint256 percentageToKinkPointBps,
    uint256 totalDebt
  ) public {
    uint256 percentageToKinkPointRay = bound(percentageToKinkPointBps, 1, 100_00).bpsToRay();

    uint256 availableLiquidity;
    (totalDebt, availableLiquidity) = _computeDebtAndAvailableLiquidity(
      percentageToKinkPointRay.rayMul(rateData.optimalUsageRatio.bpsToRay()),
      totalDebt
    );

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      totalDebt: totalDebt,
      availableLiquidity: availableLiquidity
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay().rayMul(percentageToKinkPointRay);
    assertEq(variableBorrowRate, expectedVariableRate);
  }

  function test_calculateInterestRate_AtKinkPoint() public {
    test_calculateInterestRate_LeftToKinkPoint(100_00, 100e18);
  }

  function test_calculateInterestRate_RightToKinkPoint(
    uint256 utilizationRatio,
    uint256 totalDebt
  ) public {
    uint256 utilizationRatioRay = bound(utilizationRatio, rateData.optimalUsageRatio + 1, 100_00)
      .bpsToRay();

    uint256 availableLiquidity;
    (totalDebt, availableLiquidity) = _computeDebtAndAvailableLiquidity(
      utilizationRatioRay,
      totalDebt
    );

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      totalDebt: totalDebt,
      availableLiquidity: availableLiquidity
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay() +
      rateData
        .variableRateSlope2
        .bpsToRay()
        .rayMul(utilizationRatioRay - rateData.optimalUsageRatio.bpsToRay())
        .rayDiv(WadRayMath.RAY - rateData.optimalUsageRatio.bpsToRay());
    assertEq(variableBorrowRate, expectedVariableRate);
  }

  function test_calculateInterestRate_AtMaxUtilization() public {
    test_calculateInterestRate_RightToKinkPoint(100_00, 100e18);
  }

  function _computeDebtAndAvailableLiquidity(
    uint256 targetUtilizationRatioRay,
    uint256 totalDebtUnbounded
  ) internal pure returns (uint256 totalDebt, uint256 availableLiquidity) {
    /// @dev using high value to avoid precision loss
    totalDebt = bound(totalDebtUnbounded, 10e27, 1e30);

    // utilizationRatio = totalDebt / (totalDebt + availableLiquidity)
    // utilizationRatio * totalDebt + utilizationRatio * availableLiquidity = totalDebt
    // availableLiquidity = totalDebt * (1 - utilizationRatio) / utilizationRatio
    availableLiquidity = totalDebt.rayMul(WadRayMath.RAY - targetUtilizationRatioRay).rayDiv(
      targetUtilizationRatioRay
    );
  }
}
