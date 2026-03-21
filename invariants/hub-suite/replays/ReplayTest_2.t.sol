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

contract ReplayTest2Hub is Invariants, Setup {
  // Generated from Echidna reproducers

  // Target contract instance (you may need to adjust this)
  ReplayTest2Hub Tester = this;

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

  /// @dev Replays a low-liquidity scenario where virtual assets/shares skew exchange rate.
  /// Early redeemers get more assets per share than late redeemers - accepted by design.
  function test_replay_2_add() public {
    _setUpActor(USER1);
    Tester.add(1, 0);
    Tester.draw(1, 0);
    _delay(1);
    Tester.add(3, 0);
  }

  /// @dev PASS
  function test_replay_2_payFeeShares() public {
    _setUpActor(USER1);
    Tester.add(1, 0);
    Tester.add(2, 1);
    Tester.draw(1, 1);
    _delay(1);
    Tester.payFeeShares(1, 0);
    _checkAllHubInvariants();
  }

  /// @dev PASS
  function test_replay_2_remove() public {
    _setUpActor(USER1);
    Tester.add(2, 1);
    Tester.add(1, 0);
    Tester.draw(1, 1);
    _delay(1);
    Tester.remove(1, 0);
  }

  /// @dev PASS
  function test_replay_2_transferShares() public {
    _setUpActor(USER1);
    Tester.add(1, 1);
    Tester.add(2, 0);
    Tester.draw(1, 0);
    _delay(1);
    Tester.transferShares(1, 1, 0);
  }

  /// @dev PASS
  function test_replay_2_draw() public {
    _setUpActor(USER1);
    Tester.add(1, 0);
    Tester.add(2, 1);
    Tester.draw(1, 1);
    _delay(1);
    Tester.draw(1, 0);
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
