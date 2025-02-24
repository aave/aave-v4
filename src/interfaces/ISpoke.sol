// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

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

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);
  function getUserCumulativeDebt(uint256 reserveId, address user) external view returns (uint256);
  function getReserveCumulativeDebt(uint256 reserveId) external view returns (uint256);
  function getUserRiskPremium(address user) external view returns (uint256);
  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256);
  function getSuppliedAmount(uint256 reserveId, address user) external view returns (uint256);
  function getSuppliedShares(uint256 reserveId, address user) external view returns (uint256);
}

/**
 * @title Spoke Errors Library
 * @author Aave Labs
 * @notice Defines the error messages emitted by the Spoke
 */
library SpokeErrors {
  string public constant INVALID_RESERVE = 'INVALID_RESERVE';
  string public constant RESERVE_NOT_LISTED = 'RESERVE_NOT_LISTED';
  string public constant INSUFFICIENT_SUPPLY = 'INSUFFICIENT_SUPPLY';
  string public constant RESERVE_NOT_BORROWABLE = 'RESERVE_NOT_BORROWABLE';
  string public constant REPAY_EXCEEDS_DEBT = 'REPAY_EXCEEDS_DEBT';
  string public constant RESERVE_NOT_COLLATERAL = 'RESERVE_NOT_COLLATERAL';
}
