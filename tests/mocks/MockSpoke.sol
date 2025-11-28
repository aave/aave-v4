// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke, ISpoke, IHubBase, SafeCast, PositionStatusMap} from 'src/spoke/Spoke.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {Test} from 'forge-std/Test.sol';

/// @dev inherit from Test to exclude contract from forge size check
contract MockSpoke is Spoke, Test {
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

  constructor(address oracle_) Spoke(oracle_) {}

  function initialize(address) external override {}

  // same as spoke's borrow, but without health factor check
  function borrowWithoutHfCheck(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    Reserve storage reserve = _reserves[reserveId];
    UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    uint256 assetId = reserve.assetId;
    IHubBase hub = reserve.hub;

    uint256 drawnShares = hub.draw(assetId, amount, msg.sender);

    userPosition.drawnShares += drawnShares.toUint120();
    positionStatus.setBorrowing(reserveId, true);

    ISpoke.UserAccountData memory userAccountData = _processUserAccountData(onBehalfOf, true);
    _notifyRiskPremiumUpdate(onBehalfOf, userAccountData.riskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares, amount);
  }

  // Mock the user account data
  function mockStorage(address user, AccountDataInfo memory info) external {
    PositionStatus storage positionStatus = _positionStatus[user];
    for (uint256 i = 0; i < info.collateralReserveIds.length; i++) {
      positionStatus.setUsingAsCollateral(info.collateralReserveIds[i], true);
      Reserve storage reserve = _reserves[info.collateralReserveIds[i]];
      _userPositions[user][info.collateralReserveIds[i]].suppliedShares = reserve
        .hub
        .previewAddByAssets(reserve.assetId, info.collateralAmounts[i])
        .toUint120();

      _userPositions[user][info.collateralReserveIds[i]].dynamicConfigKey = info
        .collateralDynamicConfigKeys[i]
        .toUint16();
    }

    for (uint256 i = 0; i < info.suppliedAssetsReserveIds.length; i++) {
      Reserve storage reserve = _reserves[info.suppliedAssetsReserveIds[i]];
      _userPositions[user][info.suppliedAssetsReserveIds[i]].suppliedShares = reserve
        .hub
        .previewAddByAssets(reserve.assetId, info.suppliedAssetsAmounts[i])
        .toUint120();
    }

    for (uint256 i = 0; i < info.debtReserveIds.length; i++) {
      positionStatus.setBorrowing(info.debtReserveIds[i], true);
      Reserve storage reserve = _reserves[info.debtReserveIds[i]];
      _userPositions[user][info.debtReserveIds[i]].drawnShares = reserve
        .hub
        .previewDrawByAssets(reserve.assetId, info.drawnDebtAmounts[i])
        .toUint120();
      _userPositions[user][info.debtReserveIds[i]].premiumShares = vm
        .randomUint(
          reserve.hub.previewRemoveByAssets(reserve.assetId, info.accruedPremiumAmounts[i]),
          100e18
        )
        .toUint120();
      _userPositions[user][info.debtReserveIds[i]].premiumOffsetRay =
        (_userPositions[user][info.debtReserveIds[i]].premiumShares *
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
    return _processUserAccountData(user, refreshConfig);
  }

  function getRiskPremium(address user) external view returns (uint24) {
    return _positionStatus[user].riskPremium;
  }

  function setReserveDynamicConfigKey(uint256 reserveId, uint24 configKey) external {
    _reserves[reserveId].dynamicConfigKey = configKey;
  }
}
