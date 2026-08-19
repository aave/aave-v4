// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {DiscreteLiquidationLogic} from 'src/spoke/libraries/DiscreteLiquidationLogic.sol';
import {IDiscreteLiquidationSpoke} from 'src/spoke/interfaces/IDiscreteLiquidationSpoke.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title DiscreteLiquidationSpoke
/// @author Aave Labs
/// @notice Spoke variant exposing a discrete liquidation entry point restricted to a configured
/// liquidation manager, sized by a collateral cap instead of a target health factor.
abstract contract DiscreteLiquidationSpoke is IDiscreteLiquidationSpoke, Spoke {
  /// @dev The only address allowed to perform discrete liquidations.
  address internal _liquidationManager;

  /// @inheritdoc IDiscreteLiquidationSpoke
  function updateLiquidationManager(address liquidationManager) external restricted {
    _liquidationManager = liquidationManager;
    emit UpdateLiquidationManager(liquidationManager);
  }

  /// @inheritdoc IDiscreteLiquidationSpoke
  function discreteLiquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    uint256 maxCollateralToReceive
  ) external nonReentrant {
    require(msg.sender == _liquidationManager, Unauthorized());

    UserAccountData memory userAccountData = _calculateUserAccountData(user);
    DiscreteLiquidationLogic.LiquidateUserParams memory params = DiscreteLiquidationLogic
      .LiquidateUserParams({
        collateralReserveId: collateralReserveId,
        debtReserveId: debtReserveId,
        liquidationConfig: _liquidationConfig,
        oracle: ORACLE,
        user: user,
        debtToCover: debtToCover,
        maxCollateralToReceive: maxCollateralToReceive,
        userAccountData: userAccountData,
        liquidator: msg.sender
      });

    bool isUserInDeficit = DiscreteLiquidationLogic.liquidateUser({
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

  /// @inheritdoc IDiscreteLiquidationSpoke
  function getLiquidationManager() external view returns (address) {
    return _liquidationManager;
  }
}
