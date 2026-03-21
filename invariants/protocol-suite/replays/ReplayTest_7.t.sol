// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import 'forge-std/Test.sol';
import 'forge-std/console.sol';

// Contracts
import {Invariants} from '../Invariants.t.sol';
import {Setup} from '../Setup.t.sol';

// Utils
import {Actor} from '../../shared/utils/Actor.sol';

contract ReplayTest7 is Invariants, Setup {
  // Generated from Echidna reproducers

  // Target contract instance (you may need to adjust this)
  ReplayTest7 Tester = this;

  modifier setup() override {
    _;
  }

  function setUp() public {
    // Deploy protocol contracts
    _setUp();

    /// @dev fixes the actor to the first user
    actor = userToActor[USER1];

    vm.warp(101007);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   		REPLAY TESTS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function test_replay_7_updateUserRiskPremium() public {
    _setUpActor(USER3);
    Tester.supply(790, 128, 71, 203);
    Tester.setUsingAsCollateral(true, 111, 255);
    Tester.borrow(527, 68, 203, 11);
    _setUpActor(USER1);
    _delay(1812425);
    _delay(320876);
    Tester.updateFrozen(false, 59, 87);
    _setUpActor(USER2);
    _delay(343393);
    Tester.updateHealthFactorForMaxBonus(105, 146);
    _setUpActor(USER1);
    _delay(2272303);
    _setUpActor(USER2);
    _delay(62189);
    Tester.updateUserRiskPremium(101);
    _setUpActor(USER3);
    _delay(323286);
    Tester.donateUnderlyingToHub(194, 231, 231);
    _delay(505810);
    Tester.borrow(56, 77, 155, 23);
    _setUpActor(USER2);
    _delay(112744);
    Tester.updateBorrowable(false, 223, 159);
    _setUpActor(USER1);
    _delay(1632525);
    _setUpActor(USER2);
    _delay(128066);
    Tester.updateFrozen(false, 52, 208);
    _delay(180364);
    Tester.setPrice(
      44015031536544474472307730349212877645270025151054012889336165188860863984788,
      87
    );
    _setUpActor(USER3);
    _delay(460111);
    Tester.updateBorrowable(true, 160, 11);
    _setUpActor(USER1);
    _delay(898801);
    _setUpActor(USER3);
    _delay(271962);
    Tester.pauseAllReserves(251);
    _setUpActor(USER2);
    _delay(928317);
    _setUpActor(USER1);
    _delay(23908);
    Tester.updateBorrowable(true, 217, 55);
    _setUpActor(USER3);
    _delay(582766);
    Tester.updateUserRiskPremium(25);
    _checkAllHubInvariants();
    _checkAllSpokeInvariants();
  }

  function test_replay_7_repay() public {
    _setUpActor(USER3);
    _delay(321376);
    Tester.supply(790, 197, 87, 203);
    Tester.supply(100000000000000000000000002, 50, 228, 214);
    Tester.setUsingAsCollateral(true, 197, 255);
    _delay(20833);
    Tester.borrow(2973933138, 65, 107, 12);
    _setUpActor(USER1);
    Tester.updateSpokeAddCap(172, 180, 253, 253);
    _setUpActor(USER3);
    _delay(997);
    Tester.repay(
      1209722426464509529070304541882533570806727645123886685504166337177518312,
      62,
      253,
      252
    );
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Fast forward the time and set up an actor,
  /// @dev Use for ECHIDNA call-traces
  function _delay(uint256 _seconds) internal {
    vm.warp(block.timestamp + _seconds);
  }

  /// @notice Set up an actor
  function _setUpActor(address _origin) internal {
    actor = userToActor[_origin];
  }

  /// @notice Set up an actor and fast forward the time
  /// @dev Use for ECHIDNA call-traces
  function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
    actor = userToActor[_origin];
    vm.warp(block.timestamp + _seconds);
  }

  /// @notice Set up a specific block and actor
  function _setUpBlockAndActor(uint256 _block, address _user) internal {
    vm.roll(_block);
    actor = userToActor[_user];
  }

  /// @notice Set up a specific timestamp and actor
  function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
    vm.warp(_timestamp);
    actor = userToActor[_user];
  }
}
