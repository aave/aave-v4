// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title BabylonSpoke
/// @author Aave Labs
/// @notice Spoke variant for the Babylon integration: liquidations are restricted to a configured
/// liquidation manager and sized by a collateral cap instead of a target health factor. Users hold
/// at most one collateral and one debt reserve, the managed collateral reserve is never borrowable
/// and reserves cannot charge a liquidation fee.
abstract contract BabylonSpoke is IBabylonSpoke, Spoke {
  using SafeCast for uint256;
  using SpokeUtils for *;
  using ReserveFlagsMap for ReserveFlags;

  /// @dev The storage slot for the BabylonSpoke storage struct.
  /// @dev keccak256(abi.encode(uint256(keccak256("aave-v4.storage.BabylonSpoke")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant NAMESPACE_SLOT =
    0x9d0bb325e39ec38e3f35dd7d01fd86758ed3b17f7f51a6267958705e4771e200;

  /// @dev Users hold at most one collateral and one debt reserve.
  uint16 internal constant USER_RESERVES_LIMIT = 1;

  /// @dev Constructor.
  /// @param oracle_ The address of the oracle.
  constructor(address oracle_) Spoke(oracle_, USER_RESERVES_LIMIT) {}

  /// @inheritdoc IBabylonSpoke
  function updateBabylonLiquidationConfig(
    address liquidationManager,
    uint256 managedCollateralReserveId
  ) external restricted {
    require(
      !_reserves.get(managedCollateralReserveId).flags.borrowable(),
      UnsupportedBorrowableCollateral()
    );

    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    babylonSpokeStorage.liquidationManager = liquidationManager;
    babylonSpokeStorage.managedCollateralReserveId = managedCollateralReserveId.toUint96();
    emit UpdateBabylonLiquidationConfig(liquidationManager, managedCollateralReserveId);
  }

  /// @inheritdoc IBabylonSpoke
  function liquidationCall(
    uint256 debtReserveId,
    uint256 debtToCover,
    address user,
    uint256 maxCollateralToRemove
  ) external nonReentrant returns (uint256 liquidationBonus, uint256 collateralAmountRemoved) {
    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    require(msg.sender == babylonSpokeStorage.liquidationManager, Unauthorized());

    BabylonLiquidationLogic.LiquidationResult memory result = BabylonLiquidationLogic
      .liquidateUser({
        reserves: _reserves,
        userPositions: _userPositions,
        positionStatus: _positionStatus,
        dynamicConfig: _dynamicConfig,
        params: BabylonLiquidationLogic.LiquidateUserParams({
          collateralReserveId: babylonSpokeStorage.managedCollateralReserveId,
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

  /// @inheritdoc IBabylonSpoke
  function getBabylonLiquidationConfig() external view returns (address, uint256) {
    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    return (babylonSpokeStorage.liquidationManager, babylonSpokeStorage.managedCollateralReserveId);
  }

  /// @dev The canonical liquidation entry point is disabled on this Spoke: liquidations execute
  /// through the manager-gated, cap-bounded `liquidationCall` overload.
  function liquidationCall(
    uint256,
    uint256,
    address,
    uint256,
    bool
  ) external pure virtual override(ISpoke, Spoke) {
    revert UnsupportedLiquidationCall();
  }

  /// @dev Only the managed collateral reserve can be registered as collateral.
  function setUsingAsCollateral(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) public virtual override(ISpoke, Spoke) {
    if (usingAsCollateral) {
      require(
        reserveId == _getBabylonSpokeStorage().managedCollateralReserveId,
        UnsupportedCollateralReserve()
      );
    }
    super.setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @dev The managed collateral reserve is never borrowable: a user holds a single debt reserve,
  /// which can never be the collateral being seized. A reserve being listed is skipped, since the
  /// managed collateral reserve is always already listed.
  function _validateReserveConfig(
    uint256 reserveId,
    ReserveConfig calldata config
  ) internal view virtual override {
    super._validateReserveConfig(reserveId, config);
    require(
      !config.borrowable ||
        reserveId == _reserveCount ||
        reserveId != _getBabylonSpokeStorage().managedCollateralReserveId,
      UnsupportedBorrowableCollateral()
    );
  }

  /// @dev Rejects a non-zero liquidation fee on every reserve: only the managed collateral reserve
  /// can be enabled as collateral, and Babylon liquidations never charge the fee.
  function _validateDynamicReserveConfig(
    DynamicReserveConfig calldata config
  ) internal pure virtual override {
    super._validateDynamicReserveConfig(config);
    require(config.liquidationFee == 0, UnsupportedLiquidationFee());
  }

  /// @dev Returns the pointer to the BabylonSpoke storage struct.
  function _getBabylonSpokeStorage()
    private
    pure
    returns (BabylonSpokeStorage storage babylonSpokeStorage)
  {
    assembly ('memory-safe') {
      babylonSpokeStorage.slot := NAMESPACE_SLOT
    }
  }
}
