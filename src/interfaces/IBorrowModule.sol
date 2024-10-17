// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DataTypes} from '../libraries/types/DataTypes.sol';
interface IBorrowModule {
  event Borrowed(uint256 assetId, address user, uint256 amount);
  event Repaid(uint256 assetId, address user, uint256 amount);

  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view returns (uint256);
  function getInterestRate() external view returns (uint256);

  function borrow(uint256 assetId, uint256 amount) external;
  function repay(uint256 assetId, uint256 amount, address onBehalfOf) external;
}
