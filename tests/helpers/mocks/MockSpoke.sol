// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Spoke, ISpoke, IHubBase, SafeCast, PositionStatusMap} from 'src/spoke/Spoke.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SpokeUtils} from 'src/spoke/libraries/SpokeUtils.sol';
import {Test} from 'forge-std/Test.sol';

/// @dev inherit from Test to exclude contract from forge size check
contract MockSpoke is Spoke, Test {
  using SpokeUtils for *;
  using SafeCast for *;
  using PositionStatusMap for *;

  // Data structure to mock the user account data
  struct AccountDataInfo {
    uint256[] collateralReserveIds;
    uint256[] collateralAmounts;
    uint256[] collateralDynamicConfigKeys;
    uint256[] suppliedAssetsReserveIds;
    uint256[] suppliedAssetsAmounts;
    uint256[] debtReserveIds;
    uint256[] drawnDebtAmounts;
    uint256[] realizedPremiumAmountsRay;
    uint256[] accruedPremiumAmounts;
  }

  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) Spoke(oracle_, maxUserReservesLimit_) {}

  function initialize(address) external override {}

  // same as spoke's borrow, but without health factor check
  function borrowWithoutHfCheck(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external nonReentrant onlyPositionManager(onBehalfOf) returns (uint256, uint256) {
    Reserve storage reserve = _reserves.get(reserveId);
    bytes32 positionId = _getPositionIdentifier(onBehalfOf, USER_POSITION_DEFAULT_SALT);
    UserPosition storage userPosition = _userPositions[positionId][reserveId];
    PositionStatus storage positionStatus = _positionStatus[positionId];
    _validateBorrow(reserve.flags);

    uint256 drawnShares = reserve.hub.draw(reserve.assetId, amount, msg.sender);
    userPosition.drawnShares += drawnShares.toUint120();
    if (!positionStatus.isBorrowing(reserveId)) {
      require(
        MAX_USER_RESERVES_LIMIT == MAX_ALLOWED_USER_RESERVES_LIMIT ||
          positionStatus.borrowCount(_reserveCount) < MAX_USER_RESERVES_LIMIT,
        MaximumUserReservesExceeded()
      );
      positionStatus.setBorrowing(reserveId, true);
    }

    _refreshAllDynamicConfig(positionId);
    uint256 newRiskPremium = _calculateUserAccountData(positionId).riskPremium;
    _notifyRiskPremiumUpdate(positionId, newRiskPremium);

    emit Borrow(reserveId, msg.sender, positionId, drawnShares, amount);

    return (drawnShares, amount);
  }

  // Mock the user account data
  function mockStorage(address user, AccountDataInfo memory info) external {
    bytes32 positionId = _getPositionIdentifier(user, USER_POSITION_DEFAULT_SALT);
    PositionStatus storage positionStatus = _positionStatus[positionId];
    for (uint256 i = 0; i < info.collateralReserveIds.length; i++) {
      positionStatus.setUsingAsCollateral(info.collateralReserveIds[i], true);
      Reserve storage reserve = _reserves[info.collateralReserveIds[i]];
      _userPositions[positionId][info.collateralReserveIds[i]].suppliedShares = reserve
        .hub
        .previewAddByAssets(reserve.assetId, info.collateralAmounts[i])
        .toUint120();

      _userPositions[positionId][info.collateralReserveIds[i]].dynamicConfigKey = info
        .collateralDynamicConfigKeys[i]
        .toUint32();
    }

    for (uint256 i = 0; i < info.suppliedAssetsReserveIds.length; i++) {
      Reserve storage reserve = _reserves[info.suppliedAssetsReserveIds[i]];
      _userPositions[positionId][info.suppliedAssetsReserveIds[i]].suppliedShares = reserve
        .hub
        .previewAddByAssets(reserve.assetId, info.suppliedAssetsAmounts[i])
        .toUint120();
    }

    for (uint256 i = 0; i < info.debtReserveIds.length; i++) {
      positionStatus.setBorrowing(info.debtReserveIds[i], true);
      Reserve storage reserve = _reserves[info.debtReserveIds[i]];
      _userPositions[positionId][info.debtReserveIds[i]].drawnShares = reserve
        .hub
        .previewDrawByAssets(reserve.assetId, info.drawnDebtAmounts[i])
        .toUint120();
      _userPositions[positionId][info.debtReserveIds[i]].premiumShares = vm
        .randomUint(
          reserve.hub.previewRemoveByAssets(reserve.assetId, info.accruedPremiumAmounts[i]),
          100e18
        )
        .toUint120();
      _userPositions[positionId][info.debtReserveIds[i]].premiumOffsetRay =
        (_userPositions[positionId][info.debtReserveIds[i]].premiumShares *
          reserve.hub.getAssetDrawnIndex(reserve.assetId)).toInt256().toInt200() -
        (info.accruedPremiumAmounts[i] * WadRayMath.RAY).toInt256().toInt200() -
        (info.realizedPremiumAmountsRay[i]).toInt256().toInt200();
    }
  }

  // Exposes spoke's calculateUserAccountData
  function calculateUserAccountData(
    address user,
    bool refreshConfig
  ) external returns (UserAccountData memory) {
    bytes32 positionId = _getPositionIdentifier(user, USER_POSITION_DEFAULT_SALT);
    if (refreshConfig) {
      _refreshAllDynamicConfig(positionId);
    }
    return _calculateUserAccountData(positionId);
  }

  function getRiskPremium(address user) external view returns (uint24) {
    return _positionStatus[_getPositionIdentifier(user, USER_POSITION_DEFAULT_SALT)].riskPremium;
  }

  function setReserveDynamicConfigKey(uint256 reserveId, uint32 configKey) external {
    _reserves[reserveId].dynamicConfigKey = configKey;
  }
}
