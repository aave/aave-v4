// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from '../../src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from '../../src/dependencies/openzeppelin/IERC20.sol';
import {WadRayMath} from '../../src/contracts/WadRayMath.sol';
import {IBorrowModule} from '../../src/interfaces/IBorrowModule.sol';
import {ILiquidityHub} from '../../src/interfaces/ILiquidityHub.sol';
import {IReserveInterestRateStrategy} from '../../src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from '../../src/libraries/types/DataTypes.sol';

contract MockBorrowModuleCreditLine is IBorrowModule {
  using WadRayMath for uint256;
  using SafeERC20 for IERC20;

  // fetch liquidity from liquidityHub
  address public liquidityHub;
  uint256 public interestRate;
  address public interestRateStrategy;

  constructor(address liquidityHubAddress, address interestRateStrategyAddress) {
    liquidityHub = liquidityHubAddress;
    interestRateStrategy = interestRateStrategyAddress;
  }

  function setInterestRate(uint256 rate) external {
    interestRate = rate;
  }

  function borrow(uint256 assetId, uint256 amount) external {
    ILiquidityHub(liquidityHub).draw(assetId, amount);
  }

  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external {}

  function getInterestRate() public view returns (uint256) {
    return interestRate;
  }

  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) public view returns (uint256) {
    return IReserveInterestRateStrategy(interestRateStrategy).calculateInterestRates(params);
  }
}
