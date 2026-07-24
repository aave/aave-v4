// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {AaveV4EtherfiCash} from 'src/etherfi/AaveV4EtherfiCash.sol';
import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';

/// @title GenerateEtherfiCashSafeTx
/// @notice Produces the two Owner-Safe transactions of the two-phase launch:
///   phase 1 (safe-launch-tx.json)     — delegatecall the dormant-config launch payload
///   phase 2 (safe-activation-tx.json) — delegatecall the activation payload, ONLY after
///                                       `make etherfi-verify` passes against the live state
/// Both are raw Safe tx fields (to, value = 0, data = execute() calldata, operation = 1 /
/// DELEGATECALL). Propose with Safe tooling that supports delegatecall (safe-cli / SDK);
/// the Safe web Transaction Builder only issues CALLs — do not use it for these.
///
/// Required env: PAYLOAD (launch payload), ACTIVATION (activation payload).
///   PAYLOAD=0x... ACTIVATION=0x... forge script scripts/etherfi/GenerateEtherfiCashSafeTx.s.sol \
///     --sig 'generate()' --rpc-url optimism
contract GenerateEtherfiCashSafeTxScript is EtherfiCashScriptBase {

  function generate() external {
    _requireOpMainnet();

    address payload = vm.envAddress('PAYLOAD');
    _requireCode('payload', payload);
    address activation = vm.envAddress('ACTIVATION');
    _requireCode('activation payload', activation);

    address ownerSafe = AaveV4EtherfiCash.OWNER_SAFE;
    _requireCode('owner safe', ownerSafe);

    vm.createDir('output/etherfi', true);
    vm.writeFile(
      'output/etherfi/safe-launch-tx.json',
      _safeTxJson(
        'phase 1: Owner Safe delegatecalls the dormant-config launch payload',
        ownerSafe,
        payload
      )
    );
    vm.writeFile(
      'output/etherfi/safe-activation-tx.json',
      _safeTxJson(
        'phase 2: Owner Safe delegatecalls the activation payload AFTER etherfi-verify passes',
        ownerSafe,
        activation
      )
    );

    console2.log('wrote output/etherfi/safe-launch-tx.json      (phase 1) to:', payload);
    console2.log('wrote output/etherfi/safe-activation-tx.json  (phase 2) to:', activation);
    console2.log('operation for both: 1 (DELEGATECALL)');
    console2.log('');
    console2.log(
      'sequence: phase 1 -> make etherfi-verify (dormant) -> phase 2 -> make etherfi-verify'
    );
    console2.log('preconditions (instance deployment must have granted the Owner Safe):');
    console2.log('  - AccessManager admin role (0)');
    console2.log('  - HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE (200)');
    console2.log('  - SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE (400)');
  }

  function _safeTxJson(
    string memory description,
    address safe,
    address target
  ) internal view returns (string memory) {
    return
      string.concat(
        '{\n',
        '  "description": "',
        description,
        '",\n',
        '  "chainId": "10",\n',
        '  "safe": "',
        vm.toString(safe),
        '",\n',
        '  "to": "',
        vm.toString(target),
        '",\n',
        '  "value": "0",\n',
        '  "data": "',
        vm.toString(abi.encodeCall(AaveV4Payload.execute, ())),
        '",\n',
        '  "operation": 1\n',
        '}\n'
      );
  }
}
