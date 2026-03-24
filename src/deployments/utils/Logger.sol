// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';

contract Logger {
  using stdJson for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));
  struct AddressEntry {
    string label;
    address value;
  }

  struct ValueEntry {
    string label;
    uint256 value;
  }

  string internal _outputPath;
  string internal _jsonKey;
  string internal _json;

  constructor(string memory outputPath_) {
    _jsonKey = 'root';
    _outputPath = outputPath_;
    _json = _jsonKey;
  }

  function write(string memory label, address value) public {
    _write(label, value);
  }

  function write(string memory label, uint256 value) public {
    _write(label, value);
  }

  function write(string memory value) public {
    _write(value);
  }

  function writeGroup(string memory groupLabel, AddressEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function writeGroup(string memory groupLabel, ValueEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function save(string memory fileName, bool withTimestamp) public {
    console.log();
    console.log('Saving log to %s', _outputPath);
    string memory appendedMetadata = withTimestamp ? string.concat(_getTimestamp(), '-') : '';
    vm.writeJson(
      _json,
      string.concat(
        _outputPath,
        appendedMetadata,
        vm.toString(block.chainid),
        '-',
        fileName,
        '.json'
      )
    );
  }

  function log(string memory label, address value) public pure {
    _log(label, value);
  }

  function log(string memory label, uint256 value) public pure {
    _log(label, value);
  }

  function log(string memory value) public pure {
    _log(value);
  }

  function logHeader1(string memory value) public pure {
    _logHeader1(value);
  }

  function logHeader1(string memory label, address value) public pure {
    _logHeader1(label, value);
  }

  function logDetail(string memory label, address value) public pure {
    _logDetail(label, value);
  }

  function logNewLine() public pure {
    _logNewLine();
  }

  function _write(string memory label, bytes32 value) internal {
    _json = vm.serializeBytes32(_jsonKey, label, value);
  }

  function _write(string memory label, address value) internal {
    _json = vm.serializeAddress(_jsonKey, label, value);
  }

  function _write(string memory label, uint256 value) internal {
    _json = vm.serializeUint(_jsonKey, label, value);
  }

  function _write(string memory value) internal {
    _json = vm.serializeString(_jsonKey, 'message', value);
  }

  function _writeGroup(string memory groupLabel, AddressEntry[] memory entries) internal {
    string memory group;
    for (uint256 i = 0; i < entries.length; i++) {
      group = vm.serializeAddress(groupLabel, entries[i].label, entries[i].value);
    }
    _json = vm.serializeString(_jsonKey, groupLabel, group);
  }

  /// @dev Writes a nested group: { groupLabel: { entryLabel: { proxy: ..., implementation: ... }, ... } }
  function _writeNestedProxyGroup(
    string memory groupLabel,
    string[] memory labels,
    address[] memory proxies,
    address[] memory implementations
  ) internal {
    string memory group;
    for (uint256 i = 0; i < labels.length; i++) {
      string memory inner;
      inner = vm.serializeAddress(labels[i], 'proxy', proxies[i]);
      inner = vm.serializeAddress(labels[i], 'implementation', implementations[i]);
      group = vm.serializeString(groupLabel, labels[i], inner);
    }
    _json = vm.serializeString(_jsonKey, groupLabel, group);
  }

  function _writeGroup(string memory groupLabel, ValueEntry[] memory entries) internal {
    string memory group;
    for (uint256 i = 0; i < entries.length; i++) {
      group = vm.serializeString(groupLabel, entries[i].label, vm.toString(entries[i].value));
    }
    _json = vm.serializeString(_jsonKey, groupLabel, group);
  }

  function _getTimestamp() internal view returns (string memory) {
    return vm.toString(vm.unixTime() / 1000);
  }

  function _log(string memory label, address value) internal pure {
    console.log('%s: %s', label, value);
  }

  function _log(string memory label, uint256 value) internal pure {
    console.log('%s: %s', label, value);
  }

  function _log(string memory value) internal pure {
    console.log(value);
  }

  function _logHeader1(string memory value) internal pure {
    console.log('...%s...', value);
  }

  function _logHeader1(string memory label, address value) internal pure {
    console.log('...%s %s...', label, value);
  }

  function _logDetail(string memory label, address value) internal pure {
    console.log('  %s: %s', label, value);
  }

  function _logNewLine() internal pure {
    console.log();
  }
}
