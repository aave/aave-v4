// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import 'src/contracts/DefaultReserveInterestRateStrategy.sol';

contract DefaultReserveInterestRateStrategyTest is Test {
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  event RateDataUpdate(
    address indexed reserve,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  address mockAddressesProvider = makeAddr('mockAddressesProvider');
  address mockReserveAddress = makeAddr('mockReserveAddress');

  uint256 testNumber;
  DefaultReserveInterestRateStrategy public rateStrategy;

  function setUp() public {
    testNumber = 42;
    rateStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
  }

  function test_NumberIs42() public {
    assertEq(testNumber, 42);
  }

  function test_new_SetReserveInterestRateParams() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = IDefaultInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: 8000, // 80.00%
        baseVariableBorrowRate: 0, // 0%
        variableRateSlope1: 400, // 4.00%
        variableRateSlope2: 7500 // 75.00%
      });

    vm.prank(mockAddressesProvider);
    vm.expectEmit(true, false, false, true);
    emit RateDataUpdate(
      mockReserveAddress,
      uint256(rateData.optimalUsageRatio),
      uint256(rateData.baseVariableBorrowRate),
      uint256(rateData.variableRateSlope1),
      uint256(rateData.variableRateSlope2)
    );

    rateStrategy.setInterestRateParams(mockReserveAddress, abi.encode(rateData));

    assertEq(address(rateStrategy.ADDRESSES_PROVIDER()), mockAddressesProvider);

    assertEq(
      rateStrategy.getOptimalUsageRatio(mockReserveAddress),
      uint256(rateData.optimalUsageRatio) * 1e23
    );
    assertEq(
      rateStrategy.getVariableRateSlope1(mockReserveAddress),
      uint256(rateData.variableRateSlope1) * 1e23
    );
    assertEq(
      rateStrategy.getVariableRateSlope2(mockReserveAddress),
      uint256(rateData.variableRateSlope2) * 1e23
    );
    assertEq(
      rateStrategy.getBaseVariableBorrowRate(mockReserveAddress),
      uint256(rateData.baseVariableBorrowRate) * 1e23
    );
    assertEq(
      rateStrategy.getMaxVariableBorrowRate(mockReserveAddress),
      uint256(
        rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2
      ) * 1e23
    );
  }
}
