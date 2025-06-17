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
  event DynamicReserveConfigUpdated(
    uint256 indexed reserveId,
    uint16 indexed configKey,
    DataTypes.DynamicReserveConfig config
  );
  event UserDynamicConfigRefreshed(address indexed user);

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
    uint256 realizedPremiumAdded,
    uint256 realizedPremiumTaken
  );
  event OracleUpdated(uint256 indexed reserveId, address indexed oracle);
  event LiquidationConfigUpdated(DataTypes.LiquidationConfig config);
  event UserRiskPremiumUpdate(address indexed user, uint256 riskPremium);

  /**
   * @dev Emitted when a borrower is liquidated.
   * @param collateralAsset The address of the underlying asset used as collateral, to receive as result of the liquidation.
   * @param debtAsset The address of the underlying borrowed asset to be repaid with the liquidation.
   * @param user The address of the borrower getting liquidated.
   * @param liquidatedDebt The debt amount of borrowed asset to be liquidated.
   * @param liquidatedCollateral The amount of collateral received by the liquidator.
   * @param liquidator The address of the liquidator.
   */
  event LiquidationCall(
    address indexed collateralAsset,
    address indexed debtAsset,
    address indexed user,
    uint256 liquidatedDebt,
    uint256 liquidatedCollateral,
    address liquidator
  );

  // TODO: rm when treasury accounting is done; indexing to read more easily
  event TmpLiquidationFee(uint256 indexed tmpLiquidationFee);

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
  error InvalidHubAddress();
  error InvalidHealthFactorForMaxBonus();
  error InvalidLiquidationBonusFactor();
  error NoUserRiskPremiumDecrease();
  error HealthFactorNotBelowThreshold();
  error CollateralCannotBeLiquidated();
  error SpecifiedCurrencyNotBorrowedByUser();
  error InvalidDebtToCover();
  error InvalidLiquidationProtocolFee();
  error InvalidOracleAddress();
  error UsersAndDebtLengthMismatch();
  error Unauthorized();
  error CollateralStatusUnchanged();

  function addReserve(
    uint256 assetId,
    DataTypes.ReserveConfig memory config,
    DataTypes.DynamicReserveConfig memory dynConfig
  ) external returns (uint256);

  function updateReserveConfig(uint256 reserveId, DataTypes.ReserveConfig calldata params) external;

  function updateDynamicReserveConfig(
    uint256 reserveId,
    DataTypes.DynamicReserveConfig calldata dynamicConfig
  ) external;

  function updateLiquidationConfig(DataTypes.LiquidationConfig calldata config) external;

  /**
   * @notice Supplies a specified amount of the underlying asset to a given reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior approval is required.
   * @param reserveId The identifier of the reserve
   * @param amount The amount of asset to supply.
   */
  function supply(uint256 reserveId, uint256 amount) external;

  /**
   * @notice Withdraws a specified amount of underlying asset from the given reserve.
   * @dev Providing an amount greater than the maximum withdrawable value signals a full withdrawal.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to withdraw.
   * @param to The address receiving the withdrawn assets.
   */
  function withdraw(uint256 reserveId, uint256 amount, address to) external;

  /**
   * @notice Borrows a specified amount of underlying asset from the given reserve.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to borrow.
   * @param to The address receiving the borrowed assets.
   */
  function borrow(uint256 reserveId, uint256 amount, address to) external;

  /**
   * @notice Repays a specified amount of underlying asset to a given reserve.
   * @dev The Liquidity Hub pulls the underlying asset from the caller, so prior approval is required.
   * @param reserveId The identifier of the reserve.
   * @param amount The amount of asset to repay.
   */
  function repay(uint256 reserveId, uint256 amount) external;

  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover
  ) external;

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

  function getHealthFactor(address user) external view returns (uint256);

  function getReserve(uint256 reserveId) external view returns (DataTypes.Reserve memory);

  function getReserveDebt(uint256 reserveId) external view returns (uint256, uint256);

  function getReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.ReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId
  ) external view returns (DataTypes.DynamicReserveConfig memory);

  function getDynamicReserveConfig(
    uint256 reserveId,
    uint16 configKey
  ) external view returns (DataTypes.DynamicReserveConfig memory);

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

  function getVariableLiquidationBonus(
    uint256 reserveId,
    uint256 healthFactor
  ) external view returns (uint256);

  function getLiquidationConfig() external view returns (DataTypes.LiquidationConfig memory);

  function HEALTH_FACTOR_LIQUIDATION_THRESHOLD() external view returns (uint256);

  function MAX_LIQUIDITY_PREMIUM() external view returns (uint256);
}
