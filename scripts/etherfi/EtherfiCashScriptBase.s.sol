// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

/// @title EtherfiCashScriptBase
/// @notice Shared base for every ether.fi Cash launch script: OP Mainnet guard and
/// standardized custom errors. All addresses come from the AaveV4EtherfiCash address-book
/// libraries — the payloads are fully hardcoded and take no inputs.
abstract contract EtherfiCashScriptBase is Script {
  error WrongChain(uint256 chainId);
  error NoCodeAtAddress(string name, address target);

  function _requireOpMainnet() internal view {
    require(block.chainid == 10, WrongChain(block.chainid));
  }

  function _requireCode(string memory name, address target) internal view {
    require(target.code.length > 0, NoCodeAtAddress(name, target));
  }
}
