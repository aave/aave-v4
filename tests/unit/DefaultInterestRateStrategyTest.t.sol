// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import 'src/contracts/DefaultReserveInterestRateStrategy.sol';

contract DefaultReserveInterestRateStrategyTest is Test {
  event RateDataUpdate(
    uint256 indexed assetId,
    uint256 optimalUsageRatio,
    uint256 baseVariableBorrowRate,
    uint256 variableRateSlope1,
    uint256 variableRateSlope2
  );

  address mockAddressesProvider = makeAddr('mockAddressesProvider');
  uint256 mockReserveAddress = uint256(keccak256('mockReserveAddress'));

  uint256 testNumber;
  DefaultReserveInterestRateStrategy public rateStrategy;

  function setUp() public {
    rateStrategy = new DefaultReserveInterestRateStrategy(mockAddressesProvider);
  }

  function _getMockInterestRateData()
    private
    pure
    returns (IDefaultInterestRateStrategy.InterestRateData memory)
  {
    return
      IDefaultInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 8000, // 80.00%
        baseVariableBorrowRate: 0, // 0%
        variableRateSlope1: 400, // 4.00%
        variableRateSlope2: 7500 // 75.00%
      });
  }

  function getUtilizationRatio(
    uint256 totalDebt,
    uint256 availableLiquidity
  ) private pure returns (uint256) {
    if (totalDebt == 0 && availableLiquidity == 0) {
      return 0;
    }
    return (totalDebt * 10000) / (availableLiquidity + totalDebt);
  }

  function test_SetReserveInterestRateParams() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();

    vm.prank(mockAddressesProvider);
    vm.expectEmit(true, false, false, true);
    emit RateDataUpdate(
      mockReserveAddress,
      uint256(rateData.optimalUsageRatio),
      uint256(rateData.baseVariableBorrowRate),
      uint256(rateData.variableRateSlope1),
      uint256(rateData.variableRateSlope2)
    );

    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);

    assertEq(address(rateStrategy.ADDRESSES_PROVIDER()), mockAddressesProvider);
    assertEq(rateStrategy.getOptimalUsageRatio(mockReserveAddress), rateData.optimalUsageRatio);
    assertEq(rateStrategy.getVariableRateSlope1(mockReserveAddress), rateData.variableRateSlope1);
    assertEq(rateStrategy.getVariableRateSlope2(mockReserveAddress), rateData.variableRateSlope2);
    assertEq(
      rateStrategy.getBaseVariableBorrowRate(mockReserveAddress),
      rateData.baseVariableBorrowRate
    );
    assertEq(
      rateStrategy.getMaxVariableBorrowRate(mockReserveAddress),
      rateData.baseVariableBorrowRate + rateData.variableRateSlope1 + rateData.variableRateSlope2
    );
  }

  function test_calculate_interestRates_reserve_empty() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();

    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: 0,
        reserveFactor: 0,
        assetId: mockReserveAddress,
        virtualUnderlyingBalance: 0,
        usingVirtualBalance: true
      })
    );

    assertEq(variableBorrowRate, 0);
  }

  function test_calculate_interestRates_reserve_debt_80() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();

    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);

    uint256 availableLiquidity = 2e18;
    uint256 totalDebt = 8e18;

    uint256 variableBorrowRate = rateStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: totalDebt,
        reserveFactor: 0,
        assetId: mockReserveAddress,
        virtualUnderlyingBalance: availableLiquidity,
        usingVirtualBalance: true
      })
    );

    uint256 expectedVariableRate = rateStrategy.getBaseVariableBorrowRate(mockReserveAddress) +
      rateStrategy.getVariableRateSlope1(mockReserveAddress);

    assertEq(expectedVariableRate, variableBorrowRate, 'Invalid borrow rate');
  }

  function test_calculate_interest_rate_100_usage_ratio() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();
    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);

    uint256 totalDebt = 1e18;
    uint256 virtualUnderlyingBalance = 0;

    uint256 utilizationRatio = getUtilizationRatio(totalDebt, virtualUnderlyingBalance);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: totalDebt,
        reserveFactor: 0,
        assetId: mockReserveAddress,
        virtualUnderlyingBalance: virtualUnderlyingBalance,
        usingVirtualBalance: true
      })
    );

    uint256 optimalUsageRatio = rateData.optimalUsageRatio;
    uint256 excessBorrowUsageRatio = ((utilizationRatio - optimalUsageRatio) * 10000) /
      optimalUsageRatio;

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate +
      ((rateData.variableRateSlope1 + rateData.variableRateSlope2) * excessBorrowUsageRatio) /
      10000;

    assertEq(expectedVariableRate, variableBorrowRate, 'Invalid borrow rate');
  }

  function test_calculate_interest_rate_below_optimal_usage() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();
    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);
    uint256 totalDebt = 4e17;
    uint256 virtualUnderlyingBalance = 6e17;

    uint256 utilizationRatio = getUtilizationRatio(totalDebt, virtualUnderlyingBalance);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: totalDebt,
        reserveFactor: 0,
        assetId: mockReserveAddress,
        virtualUnderlyingBalance: virtualUnderlyingBalance,
        usingVirtualBalance: true
      })
    );

    uint256 expectedVariableRate = rateData.baseVariableBorrowRate +
      (rateData.variableRateSlope1 * utilizationRatio) /
      rateData.optimalUsageRatio;
    assertEq(expectedVariableRate, variableBorrowRate, 'Invalid borrow rate below optimal usage');
  }

  function test_calculate_interest_rate_zero_debt() public {
    IDefaultInterestRateStrategy.InterestRateData memory rateData = _getMockInterestRateData();
    rateStrategy.setInterestRateParams(mockReserveAddress, rateData);

    uint256 variableBorrowRate = rateStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: 0,
        liquidityTaken: 0,
        totalDebt: 0,
        reserveFactor: 0,
        assetId: mockReserveAddress,
        virtualUnderlyingBalance: 1e18,
        usingVirtualBalance: true
      })
    );

    assertEq(
      variableBorrowRate,
      rateData.baseVariableBorrowRate,
      'Invalid borrow rate with zero debt'
    );
  }
}
