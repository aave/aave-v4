// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {ITakerPositionManager} from 'src/position-manager/interfaces/ITakerPositionManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SetupHelpers
/// @notice Data builders for TakerPositionManager tests.
abstract contract SetupHelpers is SpokeHelpers {
  function _withdrawPermitData(
    ITakerPositionManager positionManager,
    ISpoke spoke,
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.WithdrawPermit memory) {
    return
      ITakerPositionManager.WithdrawPermit({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _approveBorrowData(
    ITakerPositionManager positionManager,
    ISpoke spoke,
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (ITakerPositionManager.BorrowPermit memory) {
    return
      ITakerPositionManager.BorrowPermit({
        spoke: address(spoke),
        reserveId: _randomReserveId(spoke),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }
}
