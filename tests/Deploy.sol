// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library Deploy {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function deploySpokeInstance(address oracle) internal returns (ISpoke) {
    return deploySpokeInstance(oracle, '');
  }

  function deploySpokeInstance(address oracle, bytes memory salt) internal returns (ISpoke spoke) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle)
    );
    assembly {
      spoke := create2(0, add(initCode, 0x20), mload(initCode), salt)
    }
  }

  function deployHub(address authority) internal returns (IHub) {
    return deployHub(authority, '');
  }

  function deployHub(address authority, bytes memory salt) internal returns (IHub hub) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/hub/Hub.sol:Hub'),
      abi.encode(authority)
    );
    assembly {
      hub := create2(0, add(initCode, 0x20), mload(initCode), salt)
    }
  }
}
