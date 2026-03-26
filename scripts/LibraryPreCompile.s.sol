// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';

/**
 * @dev Deploy LiquidationLogic library using CREATE2 and save the output
 *      to FOUNDRY_LIBRARIES env variable in .env file.
 *      This preprocessing step is required before running the main Deploy script,
 *      as SpokeInstance depends on LiquidationLogic as an external library.
 *
 *      The script will ask you to re-execute if FOUNDRY_LIBRARIES is set but the
 *      library is not deployed, due to setting mutation of bytecode that could
 *      result in different library addresses.
 *
 * Usage:
 *   forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi
 */
contract LibraryPreCompile is Script {
  function run() external {
    bool found = SpokeDeployUtils._librariesPathExists();

    if (found) {
      address lastLib = SpokeDeployUtils._getLiquidationLogicAddress();
      if (lastLib.code.length > 0) {
        console.log('[LibraryPreCompile] LiquidationLogic detected. Skipping re-deployment.');
        return;
      } else {
        SpokeDeployUtils._deleteLibrariesPath();
        console.log(
          'LibraryPreCompile: FOUNDRY_LIBRARIES was detected and removed. Please run again to deploy library with a fresh compilation.'
        );
        revert('RETRY AGAIN');
      }
    }

    vm.startBroadcast();
    SpokeDeployUtils._deployAndWriteLibrariesConfig(bytes32(0));
    vm.stopBroadcast();

    console.log('LibraryPreCompile: FOUNDRY_LIBRARIES set. Run the main deploy script.');
  }
}
