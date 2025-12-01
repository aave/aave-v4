pragma solidity 0.8.28;
pragma experimental ABIEncoderV2;

import {StdInvariant} from 'lib/forge-std/src/StdInvariant.sol';
import {StdAssertions} from 'lib/forge-std/src/StdAssertions.sol';
import {StdUtils} from 'lib/forge-std/src/StdUtils.sol';
import {StdCheats} from 'lib/forge-std/src/StdCheats.sol';
import {CommonBase} from 'lib/forge-std/src/Base.sol';
import {StdChains} from 'lib/forge-std/src/StdChains.sol';
import {Multicall} from 'src/dependencies/openzeppelin/Multicall.sol';
import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {FuzzingTob} from 'tests/FuzzingTob/FuzzingTob.sol';

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
contract FuzzingTob_Medusa_Test is Test {
  FuzzingTob target;

  function setUp() public {
    target = new FuzzingTob();
  }
  // Reproduced from: tests/tob/medusa-corpus//test_results/1762250731229396575-9bd2af0b-5d88-4815-8deb-8c8ce4933cf7.json
  function test_auto_borrow_must_succeed_0() public {
    vm.warp(block.timestamp + 122643);
    vm.roll(block.number + 18885);
    vm.prank(0x0000000000000000000000000000000000020000);
    target.supply_must_succeed(
      uint256(3864933140551952956875444221360552541158157406780648670691840661528254091238),
      uint256(15855599816030908029110106679254548207506641316260005152262944081825769786844),
      uint256(883423432959530707694546537161342073110144641503323393852088459833582713)
    );

    vm.warp(block.timestamp + 602344);
    vm.roll(block.number + 26379);
    vm.prank(0x0000000000000000000000000000000000010000);
    target.supply_must_succeed(
      uint256(43678591548571110861031342850784645818916109438798219308888726649923180347757),
      uint256(109394527743465207194465459398930052586463559735355324288318330572154643998002),
      uint256(10)
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
