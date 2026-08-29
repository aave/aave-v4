// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {PositionStatusMap} from 'src/spoke/libraries/PositionStatusMap.sol';
import {ReserveFlags} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title BabylonSpoke
/// @author Aave Labs
/// @notice Spoke variant for the Babylon integration: liquidations are restricted to a configured
/// liquidation manager and sized by a collateral cap instead of a target health factor. Users can
/// register at most one reserve as collateral.
abstract contract BabylonSpoke is IBabylonSpoke, Spoke {
  using SafeCast for uint256;
  using SpokeUtils for *;
  using PositionStatusMap for PositionStatus;

  /// @dev The storage slot for the BabylonSpoke storage struct.
  /// @dev keccak256(abi.encode(uint256(keccak256("aave-v4.storage.BabylonSpoke")) - 1)) & ~bytes32(uint256(0xff))
  bytes32 private constant NAMESPACE_SLOT =
    0x9d0bb325e39ec38e3f35dd7d01fd86758ed3b17f7f51a6267958705e4771e200;

  /// @inheritdoc IBabylonSpoke
  function updateBabylonLiquidationConfig(
    address liquidationManager,
    uint256 managedCollateralReserveId
  ) external restricted {
    _reserves.get(managedCollateralReserveId);

    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    babylonSpokeStorage.liquidationManager = liquidationManager;
    babylonSpokeStorage.managedCollateralReserveId = managedCollateralReserveId.toUint96();
    emit UpdateBabylonLiquidationConfig(liquidationManager, managedCollateralReserveId);
  }

  /// @dev The canonical liquidation entry point is disabled on this Spoke: liquidations go
  /// through the manager-gated, cap-bounded `liquidationCall` overload.
  function liquidationCall(
    uint256,
    uint256,
    address,
    uint256,
    bool
  ) public pure virtual override(ISpoke, Spoke) {
    revert UnsupportedLiquidationCall();
  }

  /// @inheritdoc IBabylonSpoke
  function liquidationCall(
    uint256[] calldata debtReserveIds,
    uint256[] calldata debtToCoverAmounts,
    address user,
    uint256 maxCollateralToRemove
  ) external nonReentrant {
    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    require(msg.sender == babylonSpokeStorage.liquidationManager, Unauthorized());

    UserAccountData memory userAccountData = _calculateUserAccountData(user);
    BabylonLiquidationLogic.LiquidateUserParams memory params = BabylonLiquidationLogic
      .LiquidateUserParams({
        collateralReserveId: babylonSpokeStorage.managedCollateralReserveId,
        debtReserveIds: debtReserveIds,
        debtToCoverAmounts: debtToCoverAmounts,
        reserveCount: _reserveCount,
        liquidationConfig: _liquidationConfig,
        oracle: ORACLE,
        user: user,
        maxCollateralToRemove: maxCollateralToRemove,
        userAccountData: userAccountData,
        liquidator: msg.sender
      });

    bool isUserInDeficit = BabylonLiquidationLogic.liquidateUser({
      reserves: _reserves,
      userPositions: _userPositions,
      positionStatus: _positionStatus,
      dynamicConfig: _dynamicConfig,
      params: params
    });

    if (isUserInDeficit) {
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
  }

  /// @inheritdoc IBabylonSpoke
  function getBabylonLiquidationConfig() external view returns (address, uint256) {
    BabylonSpokeStorage storage babylonSpokeStorage = _getBabylonSpokeStorage();
    return (babylonSpokeStorage.liquidationManager, babylonSpokeStorage.managedCollateralReserveId);
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

  /// @dev Restricts users to at most one registered collateral.
  function _validateSetUsingAsCollateral(
    PositionStatus storage positionStatus,
    ReserveFlags flags,
    bool usingAsCollateral
  ) internal view virtual override {
    super._validateSetUsingAsCollateral(positionStatus, flags, usingAsCollateral);
    if (usingAsCollateral) {
      require(positionStatus.collateralCount(_reserveCount) == 0, CollateralLimitExceeded());
    }
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
