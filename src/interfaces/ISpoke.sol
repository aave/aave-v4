// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DataTypes} from '../libraries/types/DataTypes.sol';
interface ISpoke {
  event Borrowed(uint256 indexed assetId, address indexed user, uint256 amount);
  event Repaid(uint256 indexed assetId, address indexed user, uint256 amount);
  event Supplied(uint256 indexed assetId, address indexed user, uint256 amount);
  event Withdrawn(uint256 indexed assetId, address indexed user, uint256 amount);

  /// @dev working with bps units 10_000 = 100%
  function getInterestRate(uint256 assetId) external view returns (uint256);

  function borrow(uint256 assetId, address to, uint256 amount) external;
  function repay(uint256 assetId, uint256 amount) external;
}
