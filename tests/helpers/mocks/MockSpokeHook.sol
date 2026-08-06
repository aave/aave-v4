// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {BaseSpokeHook} from 'src/spoke/hooks/BaseSpokeHook.sol';

contract MockSpokeHook is BaseSpokeHook {
  bytes4 public lastSelector;
  address public lastCaller;
  address public lastOnBehalfOf;
  bytes4 public blockedSelector;

  error HookBlocked(bytes4 selector, address caller, address onBehalfOf);

  constructor(address spoke) BaseSpokeHook(spoke) {}

  function setBlockedSelector(bytes4 selector) external {
    blockedSelector = selector;
  }

  function _onSupply(address caller, address onBehalfOf) internal override {
    _record(ISpoke.supply.selector, caller, onBehalfOf);
  }

  function _onWithdraw(address caller, address onBehalfOf) internal override {
    _record(ISpoke.withdraw.selector, caller, onBehalfOf);
  }

  function _onBorrow(address caller, address onBehalfOf) internal override {
    _record(ISpoke.borrow.selector, caller, onBehalfOf);
  }

  function _onRepay(address caller, address onBehalfOf) internal override {
    _record(ISpoke.repay.selector, caller, onBehalfOf);
  }

  function _onLiquidationCall(address caller, address onBehalfOf) internal override {
    _record(ISpoke.liquidationCall.selector, caller, onBehalfOf);
  }

  function _onSetUsingAsCollateral(address caller, address onBehalfOf) internal override {
    _record(ISpoke.setUsingAsCollateral.selector, caller, onBehalfOf);
  }

  function _record(bytes4 selector, address caller, address onBehalfOf) internal {
    if (selector == blockedSelector) {
      revert HookBlocked(selector, caller, onBehalfOf);
    }
    lastSelector = selector;
    lastCaller = caller;
    lastOnBehalfOf = onBehalfOf;
  }
}
