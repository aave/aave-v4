// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke, DataTypes, IHubBase, SafeCast, PositionStatus} from 'src/contracts/Spoke.sol';

contract MockSpoke is Spoke {
  using SafeCast for *;
  using PositionStatus for *;

  constructor(address oracle_) Spoke(oracle_) {}

  function initialize(address) external override {}

  // same as spoke's borrow, but without health factor check
  function borrowWithoutHfCheck(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyPositionManager(onBehalfOf) {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    uint256 assetId = reserve.assetId;
    IHubBase hub = reserve.hub;

    uint256 drawnShares = hub.draw(assetId, amount, msg.sender);

    userPosition.drawnShares += drawnShares.toUint128();
    positionStatus.setBorrowing(reserveId, true);

    DataTypes.UserAccountData memory userAccountData = _calculateAndRefreshUserAccountData(
      onBehalfOf
    );
    _notifyRiskPremiumUpdate(onBehalfOf, userAccountData.userRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares);
  }
}
