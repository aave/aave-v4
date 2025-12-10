// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/// --------------------------------------------------------------------
/// @notice This file was automatically generated using fuzz-utils
/// --------------------------------------------------------------------

import {StdInvariant} from 'lib/forge-std/src/StdInvariant.sol';
import {StdAssertions} from 'lib/forge-std/src/StdAssertions.sol';
import {StdUtils} from 'lib/forge-std/src/StdUtils.sol';
import {StdCheats} from 'lib/forge-std/src/StdCheats.sol';
import {CommonBase} from 'lib/forge-std/src/Base.sol';
import {StdChains} from 'lib/forge-std/src/StdChains.sol';
import {FuzzingTob} from 'tests/tob/Fuzzing.sol';

interface StdCheatsMedusa {
  // Set block.timestamp
  function warp(uint256) external;

  // Set block.number
  function roll(uint256) external;

  // Set block.basefee
  function fee(uint256) external;

  // Set block.difficulty (deprecated in `medusa`)
  function difficulty(uint256) external;

  // Set block.prevrandao
  function prevrandao(bytes32) external;

  // Set block.chainid
  function chainId(uint256) external;

  // Sets the block.coinbase
  function coinbase(address) external;

  // Loads a storage slot from an address
  function load(address account, bytes32 slot) external returns (bytes32);

  // Stores a value to an address' storage slot
  function store(address account, bytes32 slot, bytes32 value) external;

  // Sets the *next* call's msg.sender to be the input address
  function prank(address) external;

  // Sets all subsequent call's msg.sender (until stopPrank is called) to be the input address
  function startPrank(address) external;

  // Stops a previously called startPrank
  function stopPrank() external;

  // Set msg.sender to the input address until the current call exits
  function prankHere(address) external;

  // Sets an address' balance
  function deal(address who, uint256 newBalance) external;

  // Sets an address' code
  function etch(address who, bytes calldata code) external;

  // Signs data
  function sign(
    uint256 privateKey,
    bytes32 digest
  ) external returns (uint8 v, bytes32 r, bytes32 s);

  // Computes address for a given private key
  function addr(uint256 privateKey) external returns (address);

  // Gets the creation bytecode of a contract
  function getCode(string calldata) external returns (bytes memory);

  // Gets the nonce of an account
  function getNonce(address account) external returns (uint64);

  // Sets the nonce of an account
  // The new nonce must be higher than the current nonce of the account
  function setNonce(address account, uint64 nonce) external;

  // Performs a foreign function call via terminal
  function ffi(string[] calldata) external returns (bytes memory);

  // Take a snapshot of the current state of the EVM
  function snapshot() external returns (uint256);

  // Revert state back to a snapshot
  function revertTo(uint256) external returns (bool);

  // Convert Solidity types to strings
  function toString(address) external returns (string memory);
  function toString(bytes calldata) external returns (string memory);
  function toString(bytes32) external returns (string memory);
  function toString(bool) external returns (string memory);
  function toString(uint256) external returns (string memory);
  function toString(int256) external returns (string memory);

  // Convert strings into Solidity types
  function parseBytes(string memory) external returns (bytes memory);
  function parseBytes32(string memory) external returns (bytes32);
  function parseAddress(string memory) external returns (address);
  function parseUint(string memory) external returns (uint256);
  function parseInt(string memory) external returns (int256);
  function parseBool(string memory) external returns (bool);
}
abstract contract TestBase is CommonBase {}

abstract contract Test is TestBase, StdAssertions, StdChains, StdCheats, StdInvariant, StdUtils {
  // Note: IS_TEST() must return true.
  bool public IS_TEST = true;
}

contract FuzzingTob_Echidna_Test is Test {
  FuzzingTob target;

  function setUp() public {
    target = new FuzzingTob();
  }
  // Reproduced from: tests/tob/echidna-corpus/reproducers/3424420381669855043.txt
  function test_auto_repay_must_succeed_0() public {
    vm.prank(0x0000000000000000000000000000000000010000);
    target.supply_must_succeed(
      87669998380135013944655482319761109383673513094720148,
      97357561939694076932504968509553643870202560362395033542934,
      468729004370817393095665742246514496055218591
    );

    vm.prank(0x0000000000000000000000000000000000010000);
    target.supply_must_succeed(
      3408103604828507420782137788076078612270825242064307620714553401160793607,
      2,
      654
    );

    vm.prank(0x0000000000000000000000000000000000010000);
    target.borrow_must_succeed(
      217339498505318544659016025904636228697021317495960920335905122793994,
      43260544853363427186131023338314501715129510724582722732668955456861,
      5677914750281338402870909907329113265810941203539463281402
    );

    vm.warp(block.timestamp + 1);
    vm.roll(block.number + 1);
    vm.prank(0x0000000000000000000000000000000000010000);
    target.repay_must_succeed(
      38088060875087632084196354918713796435068677594891704144982,
      3241725997292967638999360345163195068099011668795471064482310641,
      0
    );
  }
}
