// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {console2} from 'forge-std/console2.sol';

import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title DeployEtherfiCashConfigEngine
/// @notice Deploys the stateless AaveV4ConfigEngine on OP Mainnet via the Safe Singleton
/// Factory (CREATE2, fixed salt) — the address is fully deterministic and independent of the
/// deployer. The engine holds no state or permissions; payloads delegatecall into it.
///   forge script scripts/etherfi/DeployEtherfiCashConfigEngine.s.sol --rpc-url optimism \
///     --account <keystore> --broadcast --verify
contract DeployEtherfiCashConfigEngineScript is Script {
  bytes32 internal constant SALT = keccak256('ETHERFI_CASH_AAVE_V4_CONFIG_ENGINE_V1');

  function run() external returns (address engine) {
    require(block.chainid == 10, 'expected OP Mainnet (chainid 10)');

    vm.startBroadcast();
    engine = Create2Utils.create2Deploy(SALT, type(AaveV4ConfigEngine).creationCode);
    vm.stopBroadcast();

    console2.log('AaveV4ConfigEngine deployed at:', engine);
  }
}
