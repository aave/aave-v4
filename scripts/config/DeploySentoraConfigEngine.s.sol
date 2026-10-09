// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4SentoraConfigEngine} from 'scripts/config/AaveV4SentoraConfigEngine.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title DeploySentoraConfigEngine
/// @author Aave Labs
/// @notice Deploys the `AaveV4ConfigEngine` configuration payloads delegatecall into.
/// @dev Independent of the market deploy: the engine is stateless, holds no permissions and sits at
/// a deterministic address, so it can be deployed before or after the market and nothing needs to
/// record where it went. Re-running is safe — `Create2Utils` reverts rather than deploying twice.
///
/// Five engine libraries are deployed and linked by forge ahead of this script's body, so they
/// appear as additional deployments in the broadcast.
contract DeploySentoraConfigEngine is Script {
  /// @notice Deploys the config engine, or reports it is already deployed.
  /// @return engine The config engine address.
  function run() external returns (address engine) {
    engine = AaveV4SentoraConfigEngine.predictedAddress();

    if (engine.code.length > 0) {
      console.log('AaveV4ConfigEngine already deployed at', engine);
      return engine;
    }

    vm.startBroadcast();
    engine = AaveV4SentoraConfigEngine.deploy();
    vm.stopBroadcast();

    console.log('AaveV4ConfigEngine deployed at', engine);
  }
}
