// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {UserPositionDebt} from 'src/spoke/libraries/UserPositionDebt.sol';

contract UserPositionDebtWrapper {
  ISpoke.UserPosition internal _userPosition;

  function setUserPosition(ISpoke.UserPosition memory userPosition) external {
    _userPosition = userPosition;
  }

  function getUserPosition() external view returns (ISpoke.UserPosition memory) {
    return _userPosition;
  }

  function applyPremiumDelta(IHubBase.PremiumDelta memory premiumDelta) external {
    UserPositionDebt.applyPremiumDelta(_userPosition, premiumDelta);
  }

  function getPremiumDelta(
    uint256 drawnSharesTaken,
    uint256 drawnIndex,
    uint256 riskPremium,
    uint256 restoredPremiumRay
  ) external view returns (IHubBase.PremiumDelta memory) {
    return
      UserPositionDebt.getPremiumDelta(
        _userPosition,
        drawnSharesTaken,
        drawnIndex,
        riskPremium,
        restoredPremiumRay
      );
  }

  function getDebt(IHubBase hub, uint256 assetId) external view returns (uint256, uint256) {
    return UserPositionDebt.getDebt(_userPosition, hub, assetId);
  }

  function getDebt(uint256 drawnIndex) external view returns (uint256, uint256) {
    return UserPositionDebt.getDebt(_userPosition, drawnIndex);
  }

  function calculateRestoreAmount(
    uint256 drawnIndex,
    uint256 amount
  ) external view returns (uint256, uint256) {
    return UserPositionDebt.calculateRestoreAmount(_userPosition, drawnIndex, amount);
  }

  function calculatePremiumRay(uint256 drawnIndex) external view returns (uint256) {
    return UserPositionDebt._calculatePremiumRay(_userPosition, drawnIndex);
  }
}
