// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

/// @title BytecodeHelper
/// @author Aave Labs
/// @notice Library for loading contract bytecode.
library BytecodeHelper {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Loads the creation bytecode for the AccessManagerEnumerable contract.
  function getAccessManagerEnumerableBytecode() internal view returns (bytes memory) {
    if (vm.envOr('TEST_VYPER', false)) {
      return vm.getCode('AccessManagerEnumerable.vy:AccessManagerEnumerable');
    }
    return vm.getCode('src/access/AccessManagerEnumerable.sol:AccessManagerEnumerable');
  }

  /// @notice Loads the creation bytecode for the HubInstance contract.
  /// @return The raw creation bytecode.
  function getHubBytecode() internal view returns (bytes memory) {
    if (vm.envOr('TEST_VYPER', false)) {
      return vm.getCode('HubInstance.vy:HubInstance');
    }
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }

  /// @notice Loads the creation bytecode for the SpokeInstance contract.
  /// @return The raw creation bytecode.
  function getSpokeBytecode() internal returns (bytes memory) {
    if (vm.envOr('TEST_VYPER', false)) {
      address liquidationLogic = vm.deployCode(
        'LiquidationLogicContract.vy:LiquidationLogicContract'
      );
      return abi.encodePacked(vm.getCode('SpokeInstance.vy:SpokeInstance'), abi.encode(liquidationLogic));
    }
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }
}
