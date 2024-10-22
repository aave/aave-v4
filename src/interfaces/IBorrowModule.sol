// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DataTypes} from '../libraries/types/DataTypes.sol';
interface IBorrowModule {
  event Borrowed(uint256 indexed assetId, address user, uint256 amount);
  event Repaid(uint256 indexed assetId, address user, uint256 amount);

  /// @dev working with bps units 10_000 = 100%
  function getInterestRate(uint256 assetId) external view returns (uint256);

  function borrow(uint256 assetId, uint256 amount) external;
  function repay(uint256 assetId, uint256 amount) external;
}
