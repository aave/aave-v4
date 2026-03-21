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

  function test_replay_withdraw() public {
    _setUpActor(USER2);
    _delay(151486);
    Tester.updateUserRiskPremium(127);
    _setUpActor(USER3);
    _delay(1030565);
    Tester.setUsingAsCollateral(true, 0, 0);
    _setUpActor(USER2);
    _delay(70441);
    Tester.updatePaused(true, 0, 152);
    _delay(140369);
    Tester.updateSpokeRiskPremiumThreshold(0, 13, 20, 75);
    Tester.updateUserRiskPremium(156);
    _setUpActor(USER1);
    _delay(71842);
    Tester.updateUserRiskPremium(7);
    _setUpActor(USER2);
    _delay(3481);
    Tester.updateUserDynamicConfig(127);
    Tester.updatePaused(true, 118, 165);
    _setUpActor(USER1);
    Tester.updateUserDynamicConfig(13);
    _delay(340229);
    Tester.updatePaused(false, 134, 157);
    _setUpActor(USER2);
    _delay(267059);
    Tester.updateFrozen(true, 121, 98);
    _delay(70398);
    Tester.donateUnderlyingToSpoke(10, 26, 123);
    _delay(570296);
    Tester.updateSpokeHalted(false, 225, 36, 0);
    _setUpActor(USER3);
    _delay(40);
    Tester.setPrice(528, 24);
    _setUpActor(USER2);
    Tester.supply(255, 190, 60, 95);
    _setUpActor(USER3);
    Tester.updateUserDynamicConfig(61);
    _delay(28399);
    Tester.freezeAllReserves(209);
    _delay(352625);
    Tester.updateUserRiskPremium(126);
    _setUpActor(USER1);
    Tester.pauseAllReserves(17);
    _setUpActor(USER3);
    _delay(585234);
    Tester.updateFrozen(true, 190, 214);
    _setUpActor(USER2);
    _delay(395602);
    Tester.updatePaused(false, 211, 9);
    _delay(420078);
    Tester.setPrice(
      32073901804028723412800996385287954179043683908620921829695310985447157891024,
      32
    );
    _setUpActor(USER1);
    Tester.updateUserDynamicConfig(32);
    _setUpActor(USER3);
    _delay(233249);
    Tester.freezeAllReserves(31);
    _setUpActor(USER1);
    _delay(147712);
    Tester.freezeAllReserves(0);
    _setUpActor(USER3);
    Tester.updatePaused(false, 69, 124);
    _setUpActor(USER1);
    Tester.updatePaused(false, 204, 59);
    _setUpActor(USER2);
    _delay(3);
    Tester.freezeAllReserves(208);
    _setUpActor(USER1);
    _delay(563779);
    Tester.updateSpokeHalted(false, 24, 223, 0);
    _setUpActor(USER3);
    Tester.freezeAllReserves(78);
    _setUpActor(USER2);
    Tester.updateSpokeHalted(true, 144, 0, 21);
    _setUpActor(USER1);
    Tester.updateUserDynamicConfig(248);
    _setUpActor(USER3);
    _delay(434606);
    Tester.updateSpokeHalted(true, 38, 5, 100);
    _setUpActor(USER1);
    _delay(260725);
    Tester.updateBorrowable(false, 0, 174);
    _setUpActor(USER3);
    _delay(23626);
    Tester.donateUnderlyingToHub(
      57896044618658097711785492504343953926547177528453588222701002057468963542481,
      121,
      149
    );
    _setUpActor(USER1);
    Tester.setPrice(-2500, 70);
    _setUpActor(USER3);
    _delay(207320);
    Tester.donateUnderlyingToHub(
      57896044618658097711785492504343953926464851149359812787997104700240680714240,
      0,
      22
    );
    _setUpActor(USER2);
    Tester.updateBorrowable(true, 64, 0);
    _setUpActor(USER3);
    Tester.setPrice(
      13855700271963159636037022216593078218492230319803981905413115251605142940095,
      31
    );
    Tester.updateUserRiskPremium(80);
    _setUpActor(USER2);
    Tester.updatePaused(true, 104, 80);
    _setUpActor(USER3);
    _delay(448805);
    Tester.freezeAllReserves(90);
    _setUpActor(USER2);
    Tester.updateFrozen(true, 0, 0);
    _delay(432000);
    Tester.updateUserDynamicConfig(86);
    Tester.updateBorrowable(false, 225, 98);
    _setUpActor(USER1);
    _delay(333625);
    Tester.updateUserRiskPremium(0);
    _setUpActor(USER3);
    _delay(531501);
    Tester.withdraw(
      28019993473610222170674694923366466910776419356246130299415631191766869810267,
      1,
      188,
      147
    );
  }

  function test_replay_withdraw_2() public {
    _setUpActor(USER2);
    _delay(48);
    Tester.supply(5765, 214, 57, 2);
    Tester.pauseAllReserves(229);
    Tester.withdraw(
      79270905586291627497307400106420653318261579396350751610744730950627405265,
      190,
      189,
      2
    );
  }

  function test_replay_withdraw_3() public {
    _setUpActor(USER1);
    _delay(48);
    Tester.updatePaused(false, 43, 7);
    _setUpActor(USER2);
    Tester.donateUnderlyingToSpoke(
      4453226477229950780488458817391925832298660130277646469228882959756527864210,
      82,
      35
    );
    Tester.updateBorrowable(true, 102, 225);
    Tester.updateUserRiskPremium(232);
    _setUpActor(USER3);
    Tester.updatePaused(true, 92, 0);
    _setUpActor(USER1);
    _delay(184974);
    Tester.updateFrozen(false, 5, 196);
    _setUpActor(USER2);
    Tester.setPrice(-1, 56);
    _setUpActor(USER1);
    Tester.updateUserDynamicConfig(22);
    _delay(12646);
    Tester.supply(50000000, 0, 27, 2);
    _setUpActor(USER3);
    _delay(367615);
    Tester.pauseAllReserves(137);
    _setUpActor(USER1);
    _delay(187876);
    Tester.updateUserDynamicConfig(35);
    Tester.donateUnderlyingToHub(
      15900516933484199723709268303309061460856563576000487395170929283679828504510,
      100,
      0
    );
    _setUpActor(USER2);
    Tester.updatePaused(false, 153, 221);
    _setUpActor(USER1);
    Tester.withdraw(
      34926635329146824736853381233931534329217246589975803687784392641014182723417,
      0,
      201,
      10
    );
  }

  function test_replay_setUsingAsCollateral_1() public {
    _setUpActor(USER3);
    _delay(48);
    Tester.setUsingAsCollateral(true, 0, 42);
    _setUpActor(USER1);
    Tester.addLiquidationFee(
      13323504814495136016677116177882803507625235598720014455673974911556623963286,
      124,
      0
    );
    _setUpActor(USER3);
    Tester.setUsingAsCollateral(false, 200, 146);
  }

  function test_updateUserDynamicConfig_1() public {
    _setUpActor(USER3);
    _delay(56);
    Tester.addMaxLiquidationBonus(
      172001014342743600581657909606579704666279210377953032615107995338039342389,
      14,
      0
    );
    _setUpActor(USER1);
    Tester.updateUserDynamicConfig(0);
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
