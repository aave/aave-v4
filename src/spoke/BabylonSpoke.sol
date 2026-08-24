// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title BabylonSpoke
/// @author Aave Labs
/// @notice Spoke variant for the Babylon integration: liquidations are bounded by a collateral cap,
/// with per-reserve flags to bypass dust protection and target health factor sizing.
abstract contract BabylonSpoke is IBabylonSpoke, Spoke {
  /// @dev Map of reserve identifiers to their liquidation bypass flags.
  mapping(uint256 reserveId => LiquidationBypass) internal _liquidationBypass;

  /// @inheritdoc IBabylonSpoke
  function updateLiquidationBypass(
    uint256 reserveId,
    LiquidationBypass calldata bypass
  ) external restricted {
    require(reserveId < _reserveCount, ReserveNotListed());
    _liquidationBypass[reserveId] = bypass;
    emit UpdateLiquidationBypass(reserveId, bypass);
  }

  /// @dev The canonical liquidation entry point is disabled on this Spoke: liquidations go
  /// through the cap-bounded `liquidationCall` overload.
  function liquidationCall(
    uint256,
    uint256,
    address,
    uint256,
    bool
  ) external pure override(ISpoke, Spoke) {
    revert UnsupportedLiquidationCall();
  }

  /// @inheritdoc IBabylonSpoke
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256 maxCollateralToRemove,
    bool receiveShares
  ) external nonReentrant {
    require(maxCollateralToRemove > 0, InvalidMaxCollateralToRemove());

    // dust protection and target health factor sizing are bypassed if either reserve has the corresponding flag set
    LiquidationBypass storage collateralBypass = _liquidationBypass[collateralReserveId];
    LiquidationBypass storage debtBypass = _liquidationBypass[debtReserveId];

    UserAccountData memory userAccountData = _calculateUserAccountData(user);
    BabylonLiquidationLogic.LiquidateUserParams memory params = BabylonLiquidationLogic
      .LiquidateUserParams({
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        liquidationConfig: _liquidationConfig,
        oracle: ORACLE,
        user: user,
        debtToCover: debtToCover,
        overrides: BabylonLiquidationLogic.LiquidationOverrides({
          maxCollateralToRemove: maxCollateralToRemove,
          dustThreshold: collateralBypass.bypassLiquidationDust || debtBypass.bypassLiquidationDust
            ? 0
            : DUST_LIQUIDATION_THRESHOLD,
          bypassTargetHealthFactor: collateralBypass.bypassTargetHealthFactor ||
            debtBypass.bypassTargetHealthFactor
        }),
        userAccountData: userAccountData,
        liquidator: msg.sender,
        receiveShares: receiveShares
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
  function getLiquidationBypass(
    uint256 reserveId
  ) external view returns (LiquidationBypass memory) {
    return _liquidationBypass[reserveId];
  }
}
