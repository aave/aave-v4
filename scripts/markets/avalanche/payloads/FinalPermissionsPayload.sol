// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Infra} from 'scripts/markets/avalanche/AaveV4Contracts.sol';

contract FinalPermissionsPayload {
  address internal constant SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;

  function execute() public {
    _positionManagers();
  }

  function _positionManagers() internal {
    address[5] memory positionManagers = [
      Infra.CONFIG_POSITION_MANAGER,
      Infra.GIVER_POSITION_MANAGER,
      Infra.TAKER_POSITION_MANAGER,
      Infra.NATIVE_TOKEN_GATEWAY,
      Infra.SIGNATURE_GATEWAY
    ];
    for (uint256 i; i < positionManagers.length; ++i) {
      IOwnable2Step(positionManagers[i]).transferOwnership(SECURITY_COUNCIL);
    }
  }
}

interface IOwnable2Step {
  function transferOwnership(address newOwner) external;
}
