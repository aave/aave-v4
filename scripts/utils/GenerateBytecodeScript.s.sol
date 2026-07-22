// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

contract GenerateHubBytecodeScript is Script {
  string private constant HUB_BYTECODE_PATH = 'tests/bin/hub.bytecode';
  string private constant SPOKE_INSTANCE_BYTECODE_PATH = 'tests/bin/spokeInstance.bytecode';

  function run() external {
    bytes memory hubBytecode = vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
    vm.writeFileBinary(HUB_BYTECODE_PATH, hubBytecode);

    string memory artifact = vm.readFile('out/SpokeInstance.sol/SpokeInstance.json');
    string memory spokeHex = vm.parseJsonString(artifact, '.bytecode.object');
    vm.writeFile(SPOKE_INSTANCE_BYTECODE_PATH, spokeHex);
  }
}
