// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title BabylonSpoke
/// @author Aave Labs
/// @notice Spoke variant for the Babylon integration, with liquidations restricted to a liquidation
/// manager and sized by a collateral removal cap instead of a target health factor.
/// @dev Users hold at most one collateral and one debt reserve.
/// @dev Only the managed collateral reserve can be enabled as collateral, and it can never be borrowable.
/// @dev Reserves cannot charge a liquidation fee, and the liquidator always receives collateral in underlying assets.
abstract contract BabylonSpoke is IBabylonSpoke, Spoke {
  using ReserveFlagsMap for ReserveFlags;

  /// @dev Users hold at most one collateral and one debt reserve.
  uint16 internal constant USER_RESERVES_LIMIT = 1;

  /// @inheritdoc IBabylonSpoke
  address public immutable LIQUIDATION_MANAGER;

  /// @inheritdoc IBabylonSpoke
  uint256 public immutable MANAGED_COLLATERAL_RESERVE_ID;

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  /// @param liquidationManager_ The only address allowed to perform liquidations on this Spoke.
  /// @param managedCollateralReserveId_ The identifier of the only reserve usable as collateral.
  constructor(
    address oracle_,
    address liquidationManager_,
    uint256 managedCollateralReserveId_
  ) Spoke(oracle_, USER_RESERVES_LIMIT) {
    require(liquidationManager_ != address(0), InvalidAddress());
    LIQUIDATION_MANAGER = liquidationManager_;
    MANAGED_COLLATERAL_RESERVE_ID = managedCollateralReserveId_;
  }

  /// @inheritdoc IBabylonSpoke
  function liquidationCall(
    uint256 debtReserveId,
    uint256 debtToCover,
    address user,
    uint256 maxCollateralToRemove
  ) external nonReentrant returns (uint256 liquidationBonus, uint256 collateralAmountRemoved) {
    require(msg.sender == LIQUIDATION_MANAGER, Unauthorized());

    BabylonLiquidationLogic.LiquidationResult memory result = BabylonLiquidationLogic
      .liquidateUser({
        reserves: _reserves,
        userPositions: _userPositions,
        positionStatus: _positionStatus,
        dynamicConfig: _dynamicConfig,
        params: BabylonLiquidationLogic.LiquidateUserParams({
          collateralReserveId: MANAGED_COLLATERAL_RESERVE_ID,
          debtReserveId: debtReserveId,
          liquidationConfig: _liquidationConfig,
          oracle: ORACLE,
          user: user,
          debtToCover: debtToCover,
          maxCollateralToRemove: maxCollateralToRemove,
          userAccountData: _calculateUserAccountData(user),
          liquidator: msg.sender
        })
      });

    if (result.isUserInDeficit) {
      // report deficit for all debt reserves, including the reserve being repaid
      LiquidationLogic.notifyReportDeficit(
        _reserves,
        _userPositions,
        _positionStatus,
        _reserveCount,
        user
      );
    } else {
      uint256 newRiskPremium = _calculateUserAccountData(user).riskPremium;
      _notifyRiskPremiumUpdate(user, newRiskPremium);
    }

    return (result.liquidationBonus, result.collateralAmountRemoved);
  }

  /// @dev Reverts with `UnsupportedLiquidationCall`, liquidations execute through the cap-bounded overload.
  function liquidationCall(
    uint256,
    uint256,
    address,
    uint256,
    bool
  ) external pure virtual override(ISpoke, Spoke) {
    revert UnsupportedLiquidationCall();
  }

  /// @dev Overrides Spoke `addReserve` function to reject listing the managed collateral reserve as borrowable.
  function addReserve(
    address hub,
    uint256 assetId,
    address priceSource,
    ReserveConfig calldata config,
    DynamicReserveConfig calldata dynamicConfig
  ) public virtual override(ISpoke, Spoke) returns (uint256) {
    uint256 reserveId = super.addReserve({
      hub: hub,
      assetId: assetId,
      priceSource: priceSource,
      config: config,
      dynamicConfig: dynamicConfig
    });
    _validateManagedCollateralReserve(reserveId);
    return reserveId;
  }

  /// @dev Overrides Spoke `updateReserveConfig` function to reject making the managed collateral reserve borrowable.
  function updateReserveConfig(
    uint256 reserveId,
    ReserveConfig calldata config
  ) public virtual override(ISpoke, Spoke) {
    super.updateReserveConfig(reserveId, config);
    _validateManagedCollateralReserve(reserveId);
  }

  /// @dev Overrides Spoke `setUsingAsCollateral` function to allow enabling only the managed collateral reserve as collateral.
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) public virtual override(ISpoke, Spoke) {
    if (usingAsCollateral) {
      require(reserveId == MANAGED_COLLATERAL_RESERVE_ID, UnsupportedCollateralReserve());
    }
    super.setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @dev Reverts with `UnsupportedBorrowableCollateral` if the reserve is the managed collateral reserve and is borrowable.
  /// @dev A reserve that is not listed yet has no flags set, so it passes the check.
  /// @param reserveId The identifier of the reserve to validate.
  function _validateManagedCollateralReserve(uint256 reserveId) internal view {
    require(
      reserveId != MANAGED_COLLATERAL_RESERVE_ID || !_reserves[reserveId].flags.borrowable(),
      UnsupportedBorrowableCollateral()
    );
  }

  /// @dev Overrides Spoke `_validateDynamicReserveConfig` function to reject a non-zero liquidation fee.
  /// @dev Babylon liquidations never charge the fee, so no reserve needs one.
  function _validateDynamicReserveConfig(
    DynamicReserveConfig calldata config
  ) internal pure virtual override {
    super._validateDynamicReserveConfig(config);
    require(config.liquidationFee == 0, UnsupportedLiquidationFee());
  }
}
