// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {EtherfiCashOpMainnet} from 'src/etherfi/EtherfiCashOpMainnet.sol';
import {DeployEtherfiCashLaunchPayloadScript} from 'scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol';

/// @title GenerateEtherfiCashSafeTx
/// @notice Step 3 of the whitelabel launch: produces the Owner-Safe transaction that executes
/// the deployed launch payload. This replaces the Aave Governance V3 createPayload() path —
/// the Owner Safe simply DELEGATECALLs the payload's execute().
///
/// Writes output/etherfi/safe-launch-tx.json with the raw Safe tx fields
/// (to = payload, value = 0, data = execute() calldata, operation = 1 / DELEGATECALL).
/// Propose it with any Safe tooling that supports delegatecall, e.g.:
///   safe-cli / Safe SDK: operation = 1
///   (the Safe web Transaction Builder only issues CALLs — do not use it for this tx)
///
/// Required env: PAYLOAD (deployed payload address).
///   PAYLOAD=0x... forge script scripts/etherfi/GenerateEtherfiCashSafeTx.s.sol --sig 'generate()' --rpc-url optimism
contract GenerateEtherfiCashSafeTxScript is DeployEtherfiCashLaunchPayloadScript {
  error NoCodeAtAddress(string name, address target);

  function generate() external {
    require(block.chainid == 10, 'run against OP Mainnet (chainid 10)');

    address payload = vm.envAddress('PAYLOAD');
    require(payload.code.length > 0, NoCodeAtAddress('payload', payload));

    address ownerSafe = vm.envOr('ETHERFI_CASH_OWNER_SAFE', EtherfiCashOpMainnet.OWNER_SAFE);
    require(ownerSafe.code.length > 0, NoCodeAtAddress('owner safe', ownerSafe));

    bytes memory data = abi.encodeCall(AaveV4Payload.execute, ());

    string memory json = string.concat(
      '{\n',
      '  "description": "ether.fi Cash Aave V4 launch: Owner Safe delegatecalls the launch payload",\n',
      '  "chainId": "10",\n',
      '  "safe": "',
      vm.toString(ownerSafe),
      '",\n',
      '  "to": "',
      vm.toString(payload),
      '",\n',
      '  "value": "0",\n',
      '  "data": "',
      vm.toString(data),
      '",\n',
      '  "operation": 1\n',
      '}\n'
    );

    vm.createDir('output/etherfi', true);
    vm.writeFile('output/etherfi/safe-launch-tx.json', json);

    console2.log('wrote output/etherfi/safe-launch-tx.json');
    console2.log('Owner Safe:      ', ownerSafe);
    console2.log('to (payload):    ', payload);
    console2.log('operation:        1 (DELEGATECALL)');
    console2.log('data:            ', vm.toString(data));
    console2.log('');
    console2.log('preconditions (instance deployment must have granted the Owner Safe):');
    console2.log('  - AccessManager admin role (0)');
    console2.log('  - HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE (200)');
    console2.log('  - SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE (400)');
  }
}
