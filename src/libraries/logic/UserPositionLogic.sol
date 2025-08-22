// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/interfaces/ISpoke.sol';
import {IHub} from 'src/interfaces/IHub.sol';
import {IAaveOracle} from 'src/interfaces/IAaveOracle.sol';

import {PositionStatus} from 'src/libraries/configuration/PositionStatus.sol';
import {KeyValueListInMemory} from 'src/libraries/helpers/KeyValueListInMemory.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

library UserPositionLogic {
  using KeyValueListInMemory for KeyValueListInMemory.List;
  using PositionStatus for DataTypes.PositionStatus;
  using SafeCast for uint256;
  using MathUtils for *;
  using PercentageMath for *;
  using WadRayMath for *;

  /**
   * @return userRiskPremium
   * @return avgCollateralFactor
   * @return healthFactor
   * @return totalCollateralInBaseCurrency
   * @return totalDebtInBaseCurrency
   */
  function calculateUserAccountData(
    mapping(uint256 => DataTypes.Reserve reserveData) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition position)) storage _userPositions,
    mapping(uint256 => mapping(uint16 => DataTypes.DynamicReserveConfig config))
      storage _dynamicConfig,
    mapping(address => DataTypes.PositionStatus) storage _positionStatus,
    IAaveOracle oracle,
    uint256 reserveCount,
    address user
  ) external view returns (uint256, uint256, uint256, uint256, uint256) {
    return
      _calculateUserAccountData(
        _reserves,
        _userPositions,
        _dynamicConfig,
        _positionStatus[user],
        oracle,
        reserveCount,
        user
      );
  }

  function calculateAndRefreshUserAccountData(
    mapping(uint256 => DataTypes.Reserve reserveData) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition position)) storage _userPositions,
    mapping(uint256 => mapping(uint16 => DataTypes.DynamicReserveConfig config))
      storage _dynamicConfig,
    mapping(address => DataTypes.PositionStatus) storage _positionStatus,
    IAaveOracle oracle,
    uint256 reserveCount,
    address user
  ) external returns (uint256, uint256, uint256, uint256, uint256) {
    _refreshDynamicConfig(_reserves, _userPositions, _positionStatus, reserveCount, user);
    return
      _calculateUserAccountData(
        _reserves,
        _userPositions,
        _dynamicConfig,
        _positionStatus[user],
        oracle,
        reserveCount,
        user
      );
  }

  function _calculateUserAccountData(
    mapping(uint256 => DataTypes.Reserve reserveData) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition position)) storage _userPositions,
    mapping(uint256 => mapping(uint16 => DataTypes.DynamicReserveConfig config))
      storage _dynamicConfig,
    DataTypes.PositionStatus storage positionStatus,
    IAaveOracle oracle,
    uint256 reserveCount,
    address user
  ) internal view returns (uint256, uint256, uint256, uint256, uint256) {
    DataTypes.CalculateUserAccountDataVars memory vars;
    KeyValueListInMemory.List memory list = KeyValueListInMemory.init(
      positionStatus.collateralCount(reserveCount)
    );

    while (vars.reserveId < reserveCount) {
      if (!positionStatus.isUsingAsCollateralOrBorrowing(vars.reserveId)) {
        unchecked {
          ++vars.reserveId;
        }
        continue;
      }

      DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
      DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
      vars.assetId = reserve.assetId;
      IHub hub = reserve.hub;
      vars.assetPrice = oracle.getReservePrice(vars.reserveId);
      unchecked {
        vars.assetUnit = 10 ** reserve.decimals;
      }

      if (positionStatus.isUsingAsCollateral(vars.reserveId)) {
        DataTypes.DynamicReserveConfig storage dynConfig = _dynamicConfig[vars.reserveId][
          userPosition.configKey
        ];

        vars.userCollateralInBaseCurrency = _getUserBalanceInBaseCurrency(
          userPosition,
          hub,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );

        vars.totalCollateralInBaseCurrency += vars.userCollateralInBaseCurrency;
        list.add(vars.i, reserve.collateralRisk, vars.userCollateralInBaseCurrency);
        vars.avgCollateralFactor += vars.userCollateralInBaseCurrency * dynConfig.collateralFactor;

        unchecked {
          ++vars.i;
        }
      }

      if (positionStatus.isBorrowing(vars.reserveId)) {
        vars.totalDebtInBaseCurrency += _getUserDebtInBaseCurrency(
          userPosition,
          hub,
          vars.assetId,
          vars.assetPrice,
          vars.assetUnit
        );
      }

      unchecked {
        ++vars.reserveId;
      }
    }

    // at this point avgCollateralFactor is a weighted sum of collateral scaled by collateralFactor
    // (avgCollateralFactor / totalCollateral) * totalCollateral can be simplified to avgCollateralFactor
    // strip BPS factor from result, because running avgCollateralFactor sum has been scaled by collateralFactor (in BPS) above
    vars.healthFactor = vars.totalDebtInBaseCurrency == 0
      ? type(uint256).max
      : vars.avgCollateralFactor.wadDivDown(vars.totalDebtInBaseCurrency).fromBpsDown(); // HF of 1 -> 1e18

    // divide by total collateral to get avg collateral factor in wad
    vars.avgCollateralFactor = vars.totalCollateralInBaseCurrency == 0
      ? 0
      : vars.avgCollateralFactor.wadDivDown(vars.totalCollateralInBaseCurrency);

    vars.debtCounterInBaseCurrency = vars.totalDebtInBaseCurrency;

    list.sortByKey(); // sort by collateral risk
    vars.i = 0;
    // @dev from this point onwards, `collateralCounterInBaseCurrency` represents running collateral
    // value used in risk premium, `debtCounterInBaseCurrency` represents running outstanding debt
    while (vars.i < list.length() && vars.debtCounterInBaseCurrency > 0) {
      if (vars.debtCounterInBaseCurrency == 0) break;
      (vars.collateralRisk, vars.userCollateralInBaseCurrency) = list.get(vars.i);
      if (vars.userCollateralInBaseCurrency > vars.debtCounterInBaseCurrency) {
        vars.userCollateralInBaseCurrency = vars.debtCounterInBaseCurrency;
      }
      vars.userRiskPremium += vars.userCollateralInBaseCurrency * vars.collateralRisk;
      vars.collateralCounterInBaseCurrency += vars.userCollateralInBaseCurrency;
      vars.debtCounterInBaseCurrency -= vars.userCollateralInBaseCurrency;
      unchecked {
        ++vars.i;
      }
    }

    if (vars.collateralCounterInBaseCurrency > 0) {
      vars.userRiskPremium = vars.userRiskPremium / vars.collateralCounterInBaseCurrency;
    }

    return (
      vars.userRiskPremium,
      vars.avgCollateralFactor,
      vars.healthFactor,
      vars.totalCollateralInBaseCurrency,
      vars.totalDebtInBaseCurrency
    );
  }

  function refreshDynamicConfig(
    mapping(uint256 => DataTypes.Reserve) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition)) storage _userPositions,
    mapping(address => DataTypes.PositionStatus) storage _positionStatus,
    uint256 reserveCount,
    address user
  ) external {
    _refreshDynamicConfig(_reserves, _userPositions, _positionStatus, reserveCount, user);
  }

  function refreshDynamicConfig(
    mapping(uint256 => DataTypes.Reserve) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition)) storage _userPositions,
    address user,
    uint256 reserveId
  ) external {
    _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
    emit ISpoke.RefreshSingleUserDynamicConfig(user, reserveId);
  }

  function _refreshDynamicConfig(
    mapping(uint256 => DataTypes.Reserve) storage _reserves,
    mapping(address => mapping(uint256 => DataTypes.UserPosition)) storage _userPositions,
    mapping(address => DataTypes.PositionStatus) storage _positionStatus,
    uint256 reserveCount,
    address user
  ) internal {
    uint256 reserveId;
    while (reserveId < reserveCount) {
      if (_positionStatus[user].isUsingAsCollateral(reserveId)) {
        _userPositions[user][reserveId].configKey = _reserves[reserveId].dynamicConfigKey;
      }
      unchecked {
        ++reserveId;
      }
    }
    emit ISpoke.RefreshAllUserDynamicConfig(user);
  }

  /**
   * @dev Trigger risk premium update on all drawn reserves of `user`.
   * @param user The address of the user whose risk premium is being updated.
   * @param newUserRiskPremium The new risk premium of the user.
   * @return premiumIncrease True if the risk premium increased, false otherwise.
   */
  function notifyRiskPremiumUpdate(
    mapping(uint256 reserveId => DataTypes.Reserve reserveData) storage _reserves,
    mapping(address user => mapping(uint256 reserveId => DataTypes.UserPosition position))
      storage _userPositions,
    DataTypes.PositionStatus storage positionStatus,
    uint256 reserveCount,
    address user,
    uint256 newUserRiskPremium
  ) external returns (bool) {
    DataTypes.NotifyRiskPremiumUpdateVars memory vars;
    while (vars.reserveId < reserveCount) {
      if (positionStatus.isBorrowing(vars.reserveId)) {
        DataTypes.UserPosition storage userPosition = _userPositions[user][vars.reserveId];
        DataTypes.Reserve storage reserve = _reserves[vars.reserveId];
        vars.assetId = reserve.assetId;
        vars.hub = reserve.hub;

        uint256 oldUserPremiumShares = userPosition.premiumShares;
        uint256 oldUserPremiumOffset = userPosition.premiumOffset;
        uint256 accruedUserPremium = vars.hub.previewRestoreByShares(
          vars.assetId,
          oldUserPremiumShares
        ) - oldUserPremiumOffset;

        userPosition.premiumShares = userPosition
          .drawnShares
          .percentMulUp(newUserRiskPremium)
          .toUint128();
        userPosition.premiumOffset = _previewOffset(
          vars.hub,
          vars.assetId,
          userPosition.premiumShares
        ).toUint128();
        userPosition.realizedPremium += accruedUserPremium.toUint128();

        vars.premiumDelta = DataTypes.PremiumDelta({
          sharesDelta: userPosition.premiumShares.signedSub(oldUserPremiumShares),
          offsetDelta: userPosition.premiumOffset.signedSub(oldUserPremiumOffset),
          realizedDelta: int256(accruedUserPremium)
        });

        if (!vars.premiumIncrease) vars.premiumIncrease = vars.premiumDelta.sharesDelta > 0;

        vars.hub.refreshPremium(vars.assetId, vars.premiumDelta);
        emit ISpoke.RefreshPremiumDebt(vars.reserveId, user, vars.premiumDelta);
      }
      unchecked {
        ++vars.reserveId;
      }
    }
    emit ISpoke.UserRiskPremiumUpdate(user, newUserRiskPremium);

    return vars.premiumIncrease;
  }

  /**
   * @dev Calculates the user's premium debt offset in assets amount from a given share amount.
   * @dev Rounds down to the nearest assets amount.
   * @dev Uses the opposite rounding direction of the debt shares-to-assets conversion to prevent underflow
   * in premium debt.
   * @param hub The liquidity hub of the reserve.
   * @param assetId The identifier of the asset.
   * @param shares The amount of shares to convert to assets amount.
   * @return The amount of assets converted corresponding to user's premium offset.
   */
  function _previewOffset(
    IHub hub,
    uint256 assetId,
    uint256 shares
  ) internal view returns (uint256) {
    return hub.previewDrawByShares(assetId, shares);
  }

  function _getUserDebtInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    IHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    (uint256 drawnDebt, uint256 premiumDebt, ) = _getUserDebt(hub, assetId, userPosition);
    return ((drawnDebt + premiumDebt) * assetPrice).wadDivUp(assetUnit);
  }

  function _getUserDebt(
    IHub hub,
    uint256 assetId,
    DataTypes.UserPosition storage userPosition
  ) internal view returns (uint256, uint256, uint256) {
    uint256 accruedPremium = hub.previewRestoreByShares(assetId, userPosition.premiumShares) -
      userPosition.premiumOffset;
    return (
      hub.previewRestoreByShares(assetId, userPosition.drawnShares),
      userPosition.realizedPremium + accruedPremium,
      accruedPremium
    );
  }

  function _getUserBalanceInBaseCurrency(
    DataTypes.UserPosition storage userPosition,
    IHub hub,
    uint256 assetId,
    uint256 assetPrice,
    uint256 assetUnit
  ) internal view returns (uint256) {
    return
      (hub.previewRemoveByShares(assetId, userPosition.suppliedShares) * assetPrice).wadDivDown(
        assetUnit
      );
  }
}
