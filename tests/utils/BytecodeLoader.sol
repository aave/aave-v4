// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';

library BytecodeLoader {
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  string private constant HUB_BYTECODE_PATH = 'tests/bin/hub.bytecode';
  string private constant SPOKE_INSTANCE_BYTECODE_PATH = 'tests/bin/spokeInstance.bytecode';

  string private constant LIQUIDATION_LOGIC_PLACEHOLDER =
    '__$a48140799943db40fec4e369e92a011fa5$__';

  function loadHubBytecode() public view returns (bytes memory) {
    return vm.readFileBinary(HUB_BYTECODE_PATH);
  }

  function loadSpokeInstanceBytecode() public view returns (bytes memory) {
    string memory hexBytecode = vm.readFile(SPOKE_INSTANCE_BYTECODE_PATH);
    string memory addrHex = vm.replace(
      vm.toString(abi.encodePacked(address(LiquidationLogic))),
      '0x',
      ''
    );
    string memory linked = vm.replace(hexBytecode, LIQUIDATION_LOGIC_PLACEHOLDER, addrHex);
    return vm.parseBytes(linked);
  }
}
