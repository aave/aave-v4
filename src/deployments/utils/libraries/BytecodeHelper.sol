// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

/// @title BytecodeHelper
/// @author Aave Labs
/// @notice Library for loading contract bytecode.
library BytecodeHelper {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Loads the creation bytecode for the HubInstance contract.
  /// @return The raw creation bytecode.
  function getHubBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }

  /// @notice Loads the creation bytecode for the SpokeInstance contract.
  /// @return The raw creation bytecode.
  function getSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }

  /// @notice Loads the creation bytecode for the EtherFiSpokeInstance contract.
  /// @return The raw creation bytecode.
  function getEtherFiSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/etherfi/EtherFiSpokeInstance.sol:EtherFiSpokeInstance');
  }
}
