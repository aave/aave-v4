// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {VmSafe} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4BabylonLibraries
/// @author Aave Labs
/// @notice Deploys LiquidationLogic and BabylonLiquidationLogic at the config's library salt, one per
/// run, and records them in the FOUNDRY_LIBRARIES entry of .env.
/// @dev The first run deploys LiquidationLogic. The second run deploys BabylonLiquidationLogic from
/// the artifact forge linked against it, so both libraries verify like any other contract. A run on
/// the full entry only checks that both libraries are deployed.
contract AaveV4BabylonLibraries is Script {
  string internal constant LIQUIDATION_LOGIC_ENTRY =
    'src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:';

  function run() external {
    bytes32 librarySalt = AaveV4BabylonConfig.read().librarySalt;
    bytes memory liquidationLogicCode = vm.getCode(SpokeDeployUtils.LIQUIDATION_LOGIC_ARTIFACT);
    address liquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      liquidationLogicCode
    );
    string memory libraries = vm.envOr('FOUNDRY_LIBRARIES', string(''));

    if (bytes(libraries).length == 0) {
      _deploy(librarySalt, liquidationLogicCode);
      _record(string.concat(LIQUIDATION_LOGIC_ENTRY, vm.toString(liquidationLogic)));
      console.log('[AaveV4BabylonLibraries] LiquidationLogic:', liquidationLogic);
      console.log('[AaveV4BabylonLibraries] run again to deploy BabylonLiquidationLogic');
      return;
    }

    require(liquidationLogic.code.length > 0, 'liquidation logic not deployed');
    bytes memory babylonLiquidationLogicCode = vm.getCode(
      SpokeDeployUtils.BABYLON_LIQUIDATION_LOGIC_ARTIFACT
    );
    address babylonLiquidationLogic = Create2Utils.computeCreate2Address(
      librarySalt,
      babylonLiquidationLogicCode
    );
    string memory linked = SpokeDeployUtils.getLibraryString(
      liquidationLogic,
      babylonLiquidationLogic
    );

    if (_equal(libraries, string.concat(LIQUIDATION_LOGIC_ENTRY, vm.toString(liquidationLogic)))) {
      _deploy(librarySalt, babylonLiquidationLogicCode);
      _record(linked);
    } else {
      require(_equal(libraries, linked), 'FOUNDRY_LIBRARIES is for another config');
      require(babylonLiquidationLogic.code.length > 0, 'babylon liquidation logic not deployed');
    }
    console.log('[AaveV4BabylonLibraries] LiquidationLogic:', liquidationLogic);
    console.log('[AaveV4BabylonLibraries] BabylonLiquidationLogic:', babylonLiquidationLogic);
  }

  function _deploy(bytes32 salt, bytes memory code) internal {
    if (Create2Utils.computeCreate2Address(salt, code).code.length > 0) {
      return;
    }
    vm.startBroadcast();
    Create2Utils.create2Deploy(salt, code);
    vm.stopBroadcast();
  }

  /// @dev Comments out the active FOUNDRY_LIBRARIES entry and appends `libraries`. A dry run leaves
  /// .env untouched.
  function _record(string memory libraries) internal {
    if (!vm.isContext(VmSafe.ForgeContext.ScriptBroadcast)) {
      console.log('[AaveV4BabylonLibraries] dry run, .env unchanged. Entry: %s', libraries);
      return;
    }
    string[] memory command = new string[](3);
    command[0] = 'bash';
    command[1] = '-c';
    command[2] = string.concat(
      "perl -pi -e 's/^FOUNDRY_LIBRARIES=/# FOUNDRY_LIBRARIES=/' .env && echo FOUNDRY_LIBRARIES=",
      libraries,
      ' >> .env'
    );
    vm.ffi(command);
    console.log('[AaveV4BabylonLibraries] .env FOUNDRY_LIBRARIES=%s', libraries);
  }

  function _equal(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(bytes(a)) == keccak256(bytes(b));
  }
}
