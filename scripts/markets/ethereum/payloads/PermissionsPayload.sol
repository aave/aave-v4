// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Infra} from 'scripts/markets/ethereum/AaveV4Contracts.sol';

contract PermissionsPayload {
  function execute() public {
    address[5] memory positionManagers = [
      Infra.CONFIG_POSITION_MANAGER,
      Infra.GIVER_POSITION_MANAGER,
      Infra.TAKER_POSITION_MANAGER,
      Infra.NATIVE_TOKEN_GATEWAY,
      Infra.SIGNATURE_GATEWAY
    ];
    for (uint256 i; i < positionManagers.length; ++i) {
      IOwnable2Step(positionManagers[i]).acceptOwnership();
    }
  }
}

interface IOwnable2Step {
  function acceptOwnership() external;
}
