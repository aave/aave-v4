// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {DataTypes} from '../libraries/types/DataTypes.sol';
interface ISpoke {
  event Borrowed(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Repaid(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Supplied(uint256 indexed reserveId, uint256 amount, address indexed user);
  event Withdrawn(uint256 indexed reserveId, uint256 amount, address indexed user);
  event UsingAsCollateral(uint256 indexed reserveId, bool usingAsCollateral, address indexed user);
  event ReserveConfigUpdated(
    uint256 indexed reserveId,
    uint256 lt,
    uint256 lb,
    uint256 liquidityPremium,
    bool borrowable,
    bool collateral
  );

  /// @dev working with bps units 10_000 = 100%
  function getInterestRate(uint256 reserveId) external view returns (uint256);
  function borrow(uint256 reserveId, uint256 amount, address to) external;
  function repay(uint256 reserveId, uint256 amount) external;
  function withdraw(uint256 reserveId, uint256 amount, address to) external;
  function supply(uint256 reserveId, uint256 amount) external;
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external;
  function getHealthFactor(address user) external view returns (uint256);
  function getUserRiskPremium(address user) external view returns (uint256);
}
