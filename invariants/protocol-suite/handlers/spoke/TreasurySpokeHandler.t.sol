// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Interfaces
import {ITreasurySpokeHandler} from '../interfaces/ITreasurySpokeHandler.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

// Test Contracts
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title TreasurySpokeHandler
/// @notice Handler test contract for a set of actions
contract TreasurySpokeHandler is BaseHandler, ITreasurySpokeHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function supply(uint256 amount, uint8 i, uint8 j) external {
    address hub = _getRandomHub(i);
    address spoke = hubInfo[hub].treasurySpoke;
    uint256 reserveId = _getRandomReserveId(spoke, j);
    _tryMintAndApprove(_underlying(spoke, reserveId), address(this), spoke, amount);

    _before();
    try ISpoke(spoke).supply(reserveId, amount, msg.sender) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  function withdraw(uint256 amount, uint8 i, uint8 j) external {
    address hub = _getRandomHub(i);
    address spoke = hubInfo[hub].treasurySpoke;
    uint256 reserveId = _getRandomReserveId(spoke, j);

    _before();
    try ISpoke(spoke).withdraw(reserveId, amount, msg.sender) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  function transfer(uint256 amount, uint8 i, uint8 j, uint8 k) external {
    address hub = _getRandomHub(i);
    address asset = _getRandomBaseAsset(j);
    address to = _getRandomActor(k);

    _before();
    try ITreasurySpoke(hubInfo[hub].treasurySpoke).transfer(asset, to, amount) {
      _after();
    } catch {
      vm.assume(false);
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
