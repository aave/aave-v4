// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title DonationAttackHandler
/// @notice Handler test contract for a set of actions
contract DonationAttackHandler is BaseHandler {
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function donateUnderlyingToHub(uint256 amount, uint8 i, uint8 j) external {
    address hub = _getRandomHub(j);
    address underlying = _getRandomBaseAsset(i);

    // Register all spoke/reserve pairs that map to this hub so hub postconditions fire
    _registerAllReservesForHub(hub);

    _before();
    TestnetERC20(underlying).mint(hub, amount);
    _after();
  }

  function donateUnderlyingToSpoke(uint256 amount, uint8 i, uint8 j) external {
    address spoke = _getRandomSpoke(j);
    address underlying = _getRandomBaseAsset(i);

    // Register all reserves for this spoke so hub postconditions fire
    _registerAllReservesForSpoke(spoke);

    _before();
    TestnetERC20(underlying).mint(spoke, amount);
    _after();
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @dev Registers a user-to-check entry for every reserve of every spoke that is connected
  ///      to the given hub, so that hub-level postconditions (GPOST_HUB_A..G) are evaluated.
  ///      Uses address(this) as the user since donations don't act on a specific user.
  function _registerAllReservesForHub(address hubAddress) internal {
    for (uint256 s; s < spokes.length(); s++) {
      address spoke = spokes.at(s);
      uint256 reserveCount = ISpoke(spoke).getReserveCount();
      for (uint256 r; r < reserveCount; r++) {
        if (reserveIdToHubAddress[spoke][r] == hubAddress) {
          _registerUserToCheck(spoke, r, address(this));
        }
      }
    }
  }

  /// @dev Registers a user-to-check entry for every reserve of the given spoke,
  ///      so that hub-level postconditions are evaluated for all assets of the spoke.
  ///      Uses address(this) as the user since donations don't act on a specific user.
  function _registerAllReservesForSpoke(address spoke) internal {
    uint256 reserveCount = ISpoke(spoke).getReserveCount();
    for (uint256 r; r < reserveCount; ++r) {
      _registerUserToCheck(spoke, r, address(this));
    }
  }
}
