// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {VmSafe} from 'forge-std/Vm.sol';

/// @title SetupHelpers
/// @notice Test setup utilities for the Aave V4 test suite.
abstract contract SetupHelpers is Test {
  /// @notice Pauses the prank mode to allow test helpers to prank other actors.
  modifier pausePrank() {
    (VmSafe.CallerMode callerMode, address msgSender, address txOrigin) = vm.readCallers();
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.stopPrank();
    _;
    if (callerMode == VmSafe.CallerMode.RecurrentPrank) vm.startPrank(msgSender, txOrigin);
  }

  function _makeEntity(string memory id, bytes32 key) internal returns (address) {
    return makeAddr(string.concat(id, '-', vm.toString(uint256(key))));
  }

  function _makeKey(string memory name) internal returns (uint256) {
    (, uint256 key) = makeAddrAndKey(name);
    return key;
  }

  function _makeUser(uint256 i) internal virtual returns (address) {
    return _makeEntity('user', bytes32(i));
  }

  function _makeUser() internal virtual returns (address) {
    return _makeEntity('user', vm.randomBytes8());
  }

  function _randomAddressOmit(address omit) internal returns (address) {
    address addr = vm.randomAddress();
    while (addr == omit) addr = vm.randomAddress();
    return addr;
  }
}
