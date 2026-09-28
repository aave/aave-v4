// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeDeployUtils} from 'scripts/utils/SpokeDeployUtils.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

import {Test} from 'forge-std/Test.sol';

/// @title LiquidationLogicAddressTest
/// @author Aave Labs
/// @notice Pins the address `LibraryPreCompile` deploys LiquidationLogic to, which every Spoke of
///         the market is then linked against.
/// @dev The address is a CREATE2 result over the creation code, so it only stays put while the
///      compiler settings do. LiquidationLogic is not in `compilation_restrictions`, so it builds
///      under the default profile: changing `optimizer_runs`, `evm_version`, `solc_version` or
///      `bytecode_hash` there moves it, and this fails rather than letting a fresh deploy land
///      somewhere new without anyone noticing.
contract LiquidationLogicAddressTest is Test {
  /// @dev Where Ethereum and Avalanche have LiquidationLogic, and what every Spoke on both links
  ///      against. Read off the chain, not computed.
  address internal constant LIVE_LIQUIDATION_LOGIC = 0x88dF535473C5adf1f57789734A05E555F7Deb8DB;

  /// @dev keccak256 of the creation code the live deployments were made from, taken from the
  ///      calldata of the Ethereum deployment transaction to the Safe Singleton Factory.
  bytes32 internal constant LIVE_INITCODE_HASH =
    0xf0680649108428dca385b0d0f3288de9089d012f18516d6a6a586e2eea2de028;

  function test_creationCodeMatchesTheLiveDeployment() public view {
    bytes memory bytecode = vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');
    assertEq(keccak256(bytecode), LIVE_INITCODE_HASH, 'creation code');
  }

  function test_saltLandsOnTheLiveAddress() public view {
    bytes memory bytecode = vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');

    assertEq(
      Create2Utils.computeCreate2Address(SpokeDeployUtils.LIQUIDATION_LOGIC_SALT, bytecode),
      LIVE_LIQUIDATION_LOGIC,
      'liquidation logic address'
    );
  }
}
