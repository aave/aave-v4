// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ISpoke
 * @author Aave Labs
 * @notice Basic interface for Spoke
 */
interface ISpoke {
  event ReserveAdded(uint256 indexed reserveId, uint256 indexed assetId);
  event ReserveConfigUpdated(
    uint256 indexed reserveId,
    uint256 lt,
    uint256 lb,
    uint256 liquidityPremium,
    bool borrowable,
    bool collateral
  );
  event LiquidityPremiumUpdated(uint256 indexed reserveId, uint256 liquidityPremium);

  event Supplied(uint256 indexed reserveId, address indexed user, uint256 amount);
  event Withdrawn(uint256 indexed reserveId, address indexed user, uint256 amount);
  event Borrowed(uint256 indexed reserveId, address indexed user, uint256 amount);
  event Repaid(uint256 indexed reserveId, address indexed user, uint256 amount);
  event UsingAsCollateral(uint256 indexed reserveId, address indexed user, bool usingAsCollateral);

  error InvalidReserve();
  error ReserveNotListed();
  error InvalidLiquidityPremium();
  error InsufficientSupply(uint256 supply);
  error NotAvailableLiquidity(uint256 availableLiquidity);
  error ReserveNotBorrowable(uint256 reserveId);
  error RepayAmountExceedsDebt(uint256 debt);
  error ReserveNotCollateral(uint256 reserveId);

  function addReserve(
    uint256 assetId,
    DataTypes.ReserveConfig memory params,
    address asset
  ) external returns (uint256);
  function updateReserveConfig(uint256 reserveId, DataTypes.ReserveConfig calldata params) external;
  function updateLiquidityPremium(uint256 reserveId, uint256 liquidityPremium) external;

  function supply(uint256 reserveId, uint256 amount) external;
  function withdraw(uint256 reserveId, uint256 amount, address to) external;
  function borrow(uint256 reserveId, uint256 amount, address to) external;
  function repay(uint256 reserveId, uint256 amount) external;
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external;

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);
  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);
  function getUserCumulativeDebt(uint256 reserveId, address user) external view returns (uint256);
  function getSuppliedShares(uint256 reserveId, address user) external view returns (uint256);
  function getSuppliedAmount(uint256 reserveId, address user) external view returns (uint256);
  function getUserBaseBorrowIndex(uint256 reserveId, address user) external view returns (uint256);
  // TODO: Remove this in favor of the below global user risk premium once implemented
  function getUserRiskPremium(uint256 reserveId, address user) external view returns (uint256);
  function getUserLastUpdate(uint256 reserveId, address user) external view returns (uint256);
  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);
  function getReserveCumulativeDebt(uint256 reserveId) external view returns (uint256);
  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256);
  function getUserRiskPremium(address user) external view returns (uint256);
  function getLastUsedUserRiskPremium(address user) external view returns (uint256);
  function getHealthFactor(address user) external view returns (uint256);
  function getReservePrice(uint256 reserveId) external view returns (uint256);
  function getLiquidityPremium(uint256 reserveId) external view returns (uint256);
  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory);
  function getUser(
    uint256 reserveId,
    address user
  ) external view returns (DataTypes.UserConfig memory);
}
