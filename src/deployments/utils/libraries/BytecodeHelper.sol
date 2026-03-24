// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

/// @title BytecodeHelper
/// @notice Library for loading contract bytecode.
library BytecodeHelper {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function getHubBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }

  function getSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }
}
