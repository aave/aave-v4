// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title ISpoke
 * @author Aave Labs
 * @notice Basic interface for Spoke
 */
interface ISpoke is IMulticall {
  event ReserveAdded(uint256 indexed reserveId, uint256 indexed assetId);
  event ReserveConfigUpdated(uint256 indexed reserveId, DataTypes.ReserveConfig config);
  event LiquidityPremiumUpdated(uint256 indexed reserveId, uint256 liquidityPremium);

  event Supply(uint256 indexed reserveId, address indexed user, uint256 suppliedShares);
  event Withdraw(
    uint256 indexed reserveId,
    address indexed user,
    uint256 suppliedShares,
    address indexed to
  );
  event Borrow(
    uint256 indexed reserveId,
    address indexed user,
    uint256 drawnShares,
    address indexed to
  );
  event Repay(uint256 indexed reserveId, address indexed user, uint256 drawnShares);
  event UsingAsCollateral(uint256 indexed reserveId, address indexed user, bool usingAsCollateral);
  event RefreshPremiumDebt(
    uint256 indexed reserveId,
    address indexed user,
    int256 premiumDrawnSharesDelta,
    int256 premiumOffsetDelta,
    int256 realizedPremiumDelta
  );
  event OracleUpdated(uint256 indexed reserveId, address indexed oracle);
  event LiquidationConfigUpdated(DataTypes.LiquidationConfig config);
  event UserRiskPremiumUpdate(address indexed user, uint256 riskPremium);

  error InvalidReserve();
  error UserNotBorrowingReserve(uint256 reserveId);
  error ReserveNotListed();
  error InvalidLiquidityPremium();
  error InsufficientSupply(uint256 supply);
  error NotAvailableLiquidity(uint256 availableLiquidity);
  error ReserveNotBorrowable(uint256 reserveId);
  error ReserveCannotBeUsedAsCollateral(uint256 reserveId);
  error ReserveNotActive();
  error ReservePaused();
  error ReserveFrozen();
  error InvalidCollateralFactor();
  error InvalidLiquidationBonus();
  error InvalidReserveDecimals();
  error HealthFactorBelowThreshold();
  error InvalidCloseFactor();
  error InvalidOracleAddress();
  error InvalidHubAddress();
  error InvalidHealthFactorBonusThreshold();
  error InvalidLiquidationBonusFactor();
  error Unauthorized();

  function addReserve(
    uint256 assetId,
    DataTypes.ReserveConfig memory params
  ) external returns (uint256);

  function updateReserveConfig(uint256 reserveId, DataTypes.ReserveConfig calldata params) external;

  function updateLiquidationConfig(DataTypes.LiquidationConfig calldata config) external;

  /**
   * @notice Supply an amount of underlying asset of the specified reserve.
   * @dev Liquidity Hub pulls underlying asset from caller, hence it needs prior approval.
   * @param reserveId The reserveId of the underlying asset as registered on the spoke.
   * @param amount The amount of asset to supply.
   */
  function supply(uint256 reserveId, uint256 amount) external;

  /**
   * @notice Withdraw supplied amount of underlying asset from the specified reserve.
   * @param reserveId The reserveId of the underlying asset as registered on the spoke.
   * @param amount The amount of asset to withdraw.
   * @param to The address to transfer the assets to.
   */
  function withdraw(uint256 reserveId, uint256 amount, address to) external;

  /**
   * @notice Borrow an amount of underlying asset from the specified reserve.
   * @param reserveId The reserveId of the underlying asset as registered on the spoke.
   * @param amount The amount of underlying assets to borrow.
   * @param to The address to transfer the underlying assets to.
   */
  function borrow(uint256 reserveId, uint256 amount, address to) external;

  /**
   * @notice Repays a borrowed amount on a specified reserve.
   * @dev Liquidity Hub pulls underlying asset from caller, hence it needs prior approval.
   * @param reserveId The reserveId of the underlying asset as registered on the spoke.
   * @param amount The amount to repay.
   */
  function repay(uint256 reserveId, uint256 amount) external;

  /**
   * @notice Allows suppliers to enable/disable a specific supplied reserve as collateral.
   * @param reserveId The reserveId of the underlying asset as registered on the spoke.
   * @param usingAsCollateral True if the user wants to use the supply as collateral, false otherwise.
   */
  function setUsingAsCollateral(uint256 reserveId, bool usingAsCollateral) external;

  /**
   * @notice Allows updating the risk premium on user position.
   * @dev If the risk premium has increased, the caller must be authorized or the owner of the position,
   * reverts with `Unauthorized` otherwise.
   * @param user The address of the user.
   */
  function updateUserRiskPremium(address user) external;

  function getCollateralFactor(uint256 reserveId) external view returns (uint256);

  function getHealthFactor(address user) external view returns (uint256);

  function getLiquidityPremium(uint256 reserveId) external view returns (uint256);

  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory);

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  function getReservePrice(uint256 reserveId) external view returns (uint256);

  function getReserveRiskPremium(uint256 reserveId) external view returns (uint256);

  function getReserveSuppliedAmount(uint256 reserveId) external view returns (uint256);

  function getReserveSuppliedShares(uint256 reserveId) external view returns (uint256);

  function getReserveTotalDebt(uint256 reserveId) external view returns (uint256);

  function getUserAccountData(
    address user
  )
    external
    view
    returns (
      uint256 userRiskPremium,
      uint256 avgCollateralFactor,
      uint256 healthFactor,
      uint256 totalCollateralInBaseCurrency,
      uint256 totalDebtInBaseCurrency
    );

  function getUserDebt(uint256 reserveId, address user) external view returns (uint256, uint256);

  function getUserPosition(
    uint256 reserveId,
    address user
  ) external view returns (DataTypes.UserPosition memory);

  function getUserRiskPremium(address user) external view returns (uint256);

  function getUserSuppliedAmount(uint256 reserveId, address user) external view returns (uint256);

  function getUserSuppliedShares(uint256 reserveId, address user) external view returns (uint256);

  function getUserTotalDebt(uint256 reserveId, address user) external view returns (uint256);

  function getUsingAsCollateral(uint256 reserveId, address user) external view returns (bool);

  function reserveCount() external view returns (uint256);

  function reservesList(uint256) external view returns (uint256);

  function HEALTH_FACTOR_LIQUIDATION_THRESHOLD() external view returns (uint256);

  function getVariableLiquidationBonus(
    uint256 reserveId,
    uint256 healthFactor
  ) external view returns (uint256);

  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory);
}
