// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke, DataTypes, IHubBase, SafeCast, PositionStatus} from 'src/contracts/Spoke.sol';

contract MockSpoke is Spoke {
  using SafeCast for *;
  using PositionStatus for *;

  constructor(address authority_) Spoke(authority_) {}

  // same as spoke's borrow, but without health factor check and no position manager check for onBehalfOf
  function borrowWithoutHfCheck(uint256 reserveId, uint256 amount, address onBehalfOf) external {
    DataTypes.Reserve storage reserve = _reserves[reserveId];
    DataTypes.UserPosition storage userPosition = _userPositions[onBehalfOf][reserveId];
    DataTypes.PositionStatus storage positionStatus = _positionStatus[onBehalfOf];
    uint256 assetId = reserve.assetId;
    IHubBase hub = reserve.hub;

    _validateBorrow(reserve);

    uint256 drawnShares = hub.draw(assetId, amount, msg.sender);

    userPosition.drawnShares += drawnShares.toUint128();
    if (!positionStatus.isBorrowing(reserveId)) {
      positionStatus.setBorrowing(reserveId, true);
    }

    DataTypes.UserAccountData memory userAccountData = _calculateAndRefreshUserAccountData(
      onBehalfOf
    );
    _notifyRiskPremiumUpdate(onBehalfOf, userAccountData.userRiskPremium);

    emit Borrow(reserveId, msg.sender, onBehalfOf, drawnShares);
  }
}
