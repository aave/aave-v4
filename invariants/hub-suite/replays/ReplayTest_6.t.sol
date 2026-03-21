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

contract ReplayTest6 is Invariants, Setup {
  // Generated from Echidna reproducers

  // Target contract instance (you may need to adjust this)
  ReplayTest6 Tester = this;

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

  /// @dev PASS
  function test_replay_6_restore() public {
    _setUpActor(USER1);
    Tester.refreshPremium(1310678, 2);
    _delay(4813);
    Tester.restore(0, 2, 0, 2);
  }

  /// @dev PASS
  function test_replay_6_draw() public {
    _setUpActor(USER1);
    Tester.add(1, 0);
    Tester.refreshPremium(1, 0);
    _delay(1);
    Tester.draw(1, 0);
  }

  /// @dev PASS
  function test_replay_6_roundtrip_ERC4626_RT_D() public {
    _setUpActor(USER1);
    Tester.add(2, 0);
    Tester.draw(1, 0);
    _delay(1);
    Tester.roundtrip_ERC4626_RT_D(1, 0);
  }

  /// @dev PASS
  function test_replay_6_roundtrip_ERC4626_RT_B() public {
    _setUpActor(USER1);
    Tester.add(1, 1);
  }

  /// @dev PASS
  function test_replay_6_roundtrip_ERC4626_RT_C() public {
    _setUpActor(USER1);
    Tester.refreshPremium(1, 0);
    _delay(1);
    Tester.roundtrip_ERC4626_RT_C(1, 0);
  }

  /// @dev PASS
  function test_replay_6_remove() public {
    _setUpActor(USER1);
    Tester.add(563, 0);
    Tester.refreshPremium(34015034, 0);
    _delay(174592);
    Tester.remove(5, 0);
  }

  /// @dev PASS
  function test_replay_6_add() public {
    _setUpActor(USER1);
    Tester.add(1, 1);
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
