pragma solidity 0.8.28;
pragma experimental ABIEncoderV2;

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
contract FuzzingTob_Failing_Test is Test {
  FuzzingTob target;

  function setUp() public {
    target = new FuzzingTob();
  }
  // Reproduced from: tests/tob/medusa-corpus//test_results/1765291373480200000-ed1e866d-fcad-4903-addb-894782002630.json
  function test_auto_borrow_must_succeed_0() public {
    vm.skip(true, 'pending rft');
    vm.warp(block.timestamp + 267059);
    vm.roll(block.number + 14930);
    vm.prank(0x0000000000000000000000000000000000030000);
    target.supply_must_succeed(
      uint256(5722656613849161648401722593467304373771800295876563284168186495911927034366),
      uint256(904625697166532776746648320380374280103671755200316906558262375057526360806),
      uint256(1809251394333065553493296640760748560207343510400633813116524750123645997240)
    );

    vm.warp(block.timestamp + 192901);
    vm.roll(block.number + 300);
    vm.prank(0x0000000000000000000000000000000000010000);
    target.supply_must_succeed(
      uint256(30253424997041156644776616946560213800538322912767653797247242932674985123285),
      uint256(68394268422454371938628920663810917489324890252002321675008622068620942042100),
      uint256(115792089237316195423570985008687907853269984665640564039457584007913129639931)
    );

    vm.warp(block.timestamp + 84030);
    vm.roll(block.number + 22767);
    vm.prank(0x0000000000000000000000000000000000010000);
    target.borrow_must_succeed(
      uint256(931887952338119378215805843187999075752847953667644349213571243191303058089),
      uint256(7237005577332262213973186563042994240802015460443235294944627994579210045628),
      uint256(1329228075013078387167863183127360786)
    );

    vm.warp(block.timestamp + 359345);
    vm.roll(block.number + 23766);
    vm.prank(0x0000000000000000000000000000000000010000);
    target.borrow_must_succeed(
      uint256(638000679473712168303975477509522841443249847391934656050475673331758366055),
      uint256(48986214112031296953294442374498310653042660123368680789925709688587089254252),
      uint256(0)
    );
  }
}
