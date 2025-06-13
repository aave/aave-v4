// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {DefaultAssetInterestRateStrategy, IDefaultInterestRateStrategy} from 'src/contracts/DefaultAssetInterestRateStrategy.sol';

import {Test} from 'forge-std/Test.sol';

contract DefaultAssetInterestRateStrategyTest is Test {
  using WadRayMath for uint16;
  using WadRayMath for uint32;
  using WadRayMath for uint256;

  event RateDataUpdate(
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  address mockAddressesProvider = makeAddr('mockAddressesProvider');
  uint256 mockAssetId = uint256(keccak256('mockAssetId'));

  DefaultAssetInterestRateStrategy public rateStrategy;
  IDefaultInterestRateStrategy.InterestRateData public rateData;

  function setUp() public {
    rateStrategy = new DefaultAssetInterestRateStrategy(mockAddressesProvider);

    rateData = IDefaultInterestRateStrategy.InterestRateData({
      optimalUsageRatio: 80_00, // 80.00%
      baseVariableBorrowRate: 2_00, // 2_00%
      variableRateSlope1: 4_00, // 4.00%
      variableRateSlope2: 75_00 // 75.00%
    });

    vm.prank(mockAddressesProvider);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_addressProvider() public {
    assertEq(address(rateStrategy.ADDRESSES_PROVIDER()), mockAddressesProvider);
  }

  function test_maxBorrowRate() public {
    assertEq(rateStrategy.MAX_BORROW_RATE(), 1000_00);
  }

  function test_minOptimalPoint() public {
    assertEq(rateStrategy.MIN_OPTIMAL_POINT(), 1_00);
  }

  function test_maxOptimalPoint() public {
    assertEq(rateStrategy.MAX_OPTIMAL_POINT(), 99_00);
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
    invalidOptimalUsageRatios[0] = rateStrategy.MIN_OPTIMAL_POINT() - 1;
    invalidOptimalUsageRatios[1] = rateStrategy.MAX_OPTIMAL_POINT() + 1;

    for (uint256 i; i < invalidOptimalUsageRatios.length; i++) {
      rateData.optimalUsageRatio = invalidOptimalUsageRatios[i];
      vm.expectRevert(IDefaultInterestRateStrategy.INVALID_OPTIMAL_USAGE_RATIO.selector);
      rateStrategy.setInterestRateData(mockAssetId, rateData);
    }
  }

  function test_setInterestRateData_revertsWith_Slope2MustBeGteSlope1() public {
    (rateData.variableRateSlope1, rateData.variableRateSlope2) = (
      rateData.variableRateSlope2,
      rateData.variableRateSlope1
    );
    vm.expectRevert(IDefaultInterestRateStrategy.SLOPE_2_MUST_BE_GTE_SLOPE_1.selector);
    rateStrategy.setInterestRateData(mockAssetId, rateData);
  }

  function test_setInterestRateData_revertsWith_InvalidMaxRate() public {
    rateData.baseVariableBorrowRate = rateData.variableRateSlope1 = rateData.variableRateSlope2 =
      rateStrategy.MAX_BORROW_RATE() /
      3 +
      1;
    vm.expectRevert(IDefaultInterestRateStrategy.INVALID_MAX_RATE.selector);
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
    emit RateDataUpdate(
      mockAssetId,
      uint256(rateData.optimalUsageRatio),
      uint256(rateData.baseVariableBorrowRate),
      uint256(rateData.variableRateSlope1),
      uint256(rateData.variableRateSlope2)
    );

    vm.prank(mockAddressesProvider);
    rateStrategy.setInterestRateData(mockAssetId, rateData);

    test_addressProvider();
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
        IDefaultInterestRateStrategy.INTEREST_RATE_DATA_NOT_SET.selector,
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

  function test_calculateInterestRate_LeftToKinkPoint(uint256 percentageToKinkPointBps) public {
    uint256 percentageToKinkPointRay = bound(percentageToKinkPointBps, 1, 100_00).bpsToRay();

    (uint256 totalDebt, uint256 availableLiquidity) = _computeDebtAndAvailableLiquidity(
      percentageToKinkPointRay.rayMul(rateData.optimalUsageRatio.bpsToRay())
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
    test_calculateInterestRate_LeftToKinkPoint(100_00);
  }

  function test_calculateInterestRate_RightToKinkPoint(uint256 percentageFromKinkPointBps) public {
    uint256 percentageFromKinkPointRay = bound(percentageFromKinkPointBps, 1, 100_00).bpsToRay();

    (uint256 totalDebt, uint256 availableLiquidity) = _computeDebtAndAvailableLiquidity(
      rateData.optimalUsageRatio.bpsToRay() +
        percentageFromKinkPointRay.rayMul(WadRayMath.RAY - rateData.optimalUsageRatio.bpsToRay())
    );

    uint256 variableBorrowRate = rateStrategy.calculateInterestRate({
      assetId: mockAssetId,
      totalDebt: totalDebt,
      availableLiquidity: availableLiquidity
    });

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate.bpsToRay() +
      rateData.variableRateSlope1.bpsToRay() +
      rateData.variableRateSlope2.bpsToRay().rayMul(percentageFromKinkPointRay);
    assertEq(variableBorrowRate, expectedVariableRate);
  }

  function test_calculateInterestRate_AtMaxUtilization() public {
    test_calculateInterestRate_RightToKinkPoint(100_00);
  }

  function _computeDebtAndAvailableLiquidity(
    uint256 targetUtilizationRatioRay
  ) internal pure returns (uint256 totalDebt, uint256 availableLiquidity) {
    /// @dev using 27 decimals to avoid precision loss, even though assets in the hub can have up to 18 decimals
    totalDebt = 100e27;

    // utilizationRatio = totalDebt / (totalDebt + availableLiquidity)
    // utilizationRatio * totalDebt + utilizationRatio * availableLiquidity = totalDebt
    // availableLiquidity = totalDebt * (1 - utilizationRatio) / utilizationRatio
    availableLiquidity = totalDebt.rayMul(WadRayMath.RAY - targetUtilizationRatioRay).rayDiv(
      targetUtilizationRatioRay
    );
  }
}
