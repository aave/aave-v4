// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title SpokeDeployUtils
/// @notice Utilities for deploying the liquidation libraries as external libraries.
/// @dev LiquidationLogic and BabylonLiquidationLogic must be deployed before the spoke instances,
/// which are compiled with via-ir and have references to them.
/// 1. Run LibraryPreCompile.s.sol to deploy the libraries, writes FOUNDRY_LIBRARIES to .env
/// 2. Run the main deploy script to link via FOUNDRY_LIBRARIES
library SpokeDeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Deploys LiquidationLogic via CREATE2.
  /// @dev The CREATE2 factory must already be deployed on the target chain.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The deployed library address.
  function deployLiquidationLogic(bytes32 salt) internal returns (address) {
    bytes memory bytecode = vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');
    return Create2Utils.create2Deploy(salt, bytecode);
  }

  /// @notice Deploys BabylonLiquidationLogic via CREATE2.
  /// @dev The CREATE2 factory must already be deployed on the target chain.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The deployed library address.
  function deployBabylonLiquidationLogic(bytes32 salt) internal returns (address) {
    bytes memory bytecode = vm.getCode(
      'src/spoke/libraries/BabylonLiquidationLogic.sol:BabylonLiquidationLogic'
    );
    return Create2Utils.create2Deploy(salt, bytecode);
  }

  /// @notice Returns the FOUNDRY_LIBRARIES-compatible string for library linking.
  function getLibraryString(
    address liquidationLogic,
    address babylonLiquidationLogic
  ) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          'src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:',
          vm.toString(liquidationLogic),
          ',src/spoke/libraries/BabylonLiquidationLogic.sol:BabylonLiquidationLogic:',
          vm.toString(babylonLiquidationLogic)
        )
      );
  }

  /// @notice Deploys LiquidationLogic and appends FOUNDRY_LIBRARIES to .env.
  /// @param salt The CREATE2 salt for deterministic deployment.
  function _deployAndWriteLibrariesConfig(bytes32 salt) internal {
    address liquidationLogic = deployLiquidationLogic(salt);
    address babylonLiquidationLogic = deployBabylonLiquidationLogic(salt);

    string memory librariesSolcString = getLibraryString(liquidationLogic, babylonLiquidationLogic);

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

  /// @notice Reads the library addresses from FOUNDRY_LIBRARIES in .env.
  /// @return The LiquidationLogic address, or address(0) if not found.
  /// @return The BabylonLiquidationLogic address, or address(0) if not found.
  function _getLibraryAddresses() internal returns (address, address) {
    return (
      _getLibraryAddress('/LiquidationLogic.sol:LiquidationLogic:'),
      _getLibraryAddress('/BabylonLiquidationLogic.sol:BabylonLiquidationLogic:')
    );
  }

  /// @dev The entry prefix keeps its leading slash: `LiquidationLogic:` alone also matches the
  /// tail of the `BabylonLiquidationLogic:` entry.
  /// @param entryPrefix The FOUNDRY_LIBRARIES entry prefix, up to and including the trailing colon.
  /// @return The address of the entry, or address(0) if not found.
  function _getLibraryAddress(string memory entryPrefix) private returns (address) {
    string memory getLibraryAddress = string(
      abi.encodePacked("sed -nr 's|.*", entryPrefix, "([^,]*).*|\\1|p' .env")
    );
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
