// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
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

  // ==================== Library Deployment ====================

  /// @notice Deploys LiquidationLogic via CREATE2.
  /// @dev The CREATE2 factory must already be deployed on the target chain.
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

  // ==================== .env Management (FFI) ====================

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
