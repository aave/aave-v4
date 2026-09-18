// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title SpokeDeployUtils
/// @notice Utilities for deploying LiquidationLogic as an external library.
/// @dev LiquidationLogic must be deployed before SpokeInstance because SpokeInstance
/// is compiled with via-ir and has references to the library.
/// 1. Run LibraryPreCompile.s.sol to deploy library, writes FOUNDRY_LIBRARIES to .env
/// 2. Run the main deploy script to link via FOUNDRY_LIBRARIES
library SpokeDeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice The CREATE2 salt the live V4 markets deployed LiquidationLogic with.
  /// @dev Reusing it puts the library at `0x88dF535473C5adf1f57789734A05E555F7Deb8DB` on every
  /// chain, which is where Ethereum and Avalanche already have it and what every Spoke on both
  /// links against. The salt is not derived from anything: it was read back off the Ethereum
  /// deployment transaction, whose calldata to the Safe Singleton Factory is the salt followed by
  /// the creation code.
  ///
  /// A salt of zero lands on `0x818E84198224535FAeaEc1b583d3Ff6b812A5AF3` instead, which is what
  /// Arc runs and what this deployed before. Same bytecode either way — only the address differs.
  bytes32 internal constant LIQUIDATION_LOGIC_SALT = bytes32(uint256(0x2bdf));

  /// @notice Deploys LiquidationLogic via CREATE2.
  /// @dev The CREATE2 factory must already be deployed on the target chain. The creation code is
  /// address-independent, so a given salt yields the same address on every chain as long as the
  /// compiler settings are unchanged: LiquidationLogic is not in `compilation_restrictions`, so it
  /// builds under the default profile rather than the Spoke's via-ir one.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The deployed library address.
  function deployLiquidationLogic(bytes32 salt) internal returns (address) {
    bytes memory bytecode = vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');
    return Create2Utils.create2Deploy(salt, bytecode);
  }

  /// @notice Returns the FOUNDRY_LIBRARIES-compatible string for library linking.
  function getLibraryString(address liquidationLogic) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          'src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:',
          vm.toString(liquidationLogic)
        )
      );
  }

  /// @notice Deploys LiquidationLogic and appends FOUNDRY_LIBRARIES to .env.
  /// @param salt The CREATE2 salt for deterministic deployment.
  function _deployAndWriteLibrariesConfig(bytes32 salt) internal {
    address liquidationLogic = deployLiquidationLogic(salt);

    string memory librariesSolcString = getLibraryString(liquidationLogic);

    string memory sedCommand = string(
      abi.encodePacked('echo FOUNDRY_LIBRARIES=', librariesSolcString, ' >> .env')
    );
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = string(abi.encodePacked('response="$(', sedCommand, ')"; $response;'));
    vm.ffi(command);
  }

  /// @notice Checks if .env contains a FOUNDRY_LIBRARIES entry.
  function _librariesPathExists() internal returns (bool) {
    string
      memory checkCommand = '[ -e .env ] && grep -q "FOUNDRY_LIBRARIES" .env && echo true || echo false';
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = string(
      abi.encodePacked(
        'response="$(',
        checkCommand,
        ')"; cast abi-encode "response(bool)" $response;'
      )
    );
    bytes memory res = vm.ffi(command);

    return abi.decode(res, (bool));
  }

  /// @notice Deletes the FOUNDRY_LIBRARIES line from .env.
  function _deleteLibrariesPath() internal {
    string memory deleteCommand = "sed -i.bak -r '/FOUNDRY_LIBRARIES/d' .env && rm .env.bak";
    string[] memory delCommand = new string[](3);

    delCommand[0] = 'bash';
    delCommand[1] = '-c';
    delCommand[2] = string(abi.encodePacked('response="$(', deleteCommand, ')"; $response;'));
    vm.ffi(delCommand);
  }

  /// @notice Reads the LiquidationLogic address from FOUNDRY_LIBRARIES in .env.
  /// @return The address, or address(0) if not found.
  function _getLiquidationLogicAddress() internal returns (address) {
    string memory getLibraryAddress = "sed -nr 's/.*LiquidationLogic:([^,]*).*/\\1/p' .env";
    string[] memory getAddressCommand = new string[](3);

    getAddressCommand[0] = 'bash';
    getAddressCommand[1] = '-c';
    getAddressCommand[2] = string(
      abi.encodePacked(
        'response="$(',
        getLibraryAddress,
        ')"; [ -z "$response" ] && cast abi-encode "response(address)" 0x0000000000000000000000000000000000000000 || cast abi-encode "response(address)" $response'
      )
    );

    bytes memory res = vm.ffi(getAddressCommand);
    return abi.decode(res, (address));
  }
}
