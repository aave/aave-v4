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

  /// @notice The CREATE2 salt of the canonical LiquidationLogic deployment.
  /// @dev Lands LiquidationLogic at `0x88dF535473C5adf1f57789734A05E555F7Deb8DB`, the address the
  /// Ethereum Spokes link against.
  bytes32 internal constant LIQUIDATION_LOGIC_SALT = bytes32(uint256(0x2bdf));

  string internal constant LIQUIDATION_LOGIC_ARTIFACT =
    'out/LiquidationLogic.sol/LiquidationLogic.json';
  string internal constant BABYLON_LIQUIDATION_LOGIC_ARTIFACT =
    'out/BabylonLiquidationLogic.sol/BabylonLiquidationLogic.json';
  string internal constant LIQUIDATION_LOGIC_FQN =
    'src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic';

  /// @notice Deploys LiquidationLogic via CREATE2, or returns it if already deployed.
  /// @dev The CREATE2 factory must already be deployed on the target chain.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The library address.
  function deployLiquidationLogic(bytes32 salt) internal returns (address) {
    return _deployOrGet(salt, vm.getCode(LIQUIDATION_LOGIC_ARTIFACT));
  }

  /// @notice Deploys BabylonLiquidationLogic via CREATE2, linked against the given LiquidationLogic,
  /// or returns it if already deployed.
  /// @dev Links the unlinked artifact explicitly, as forge would otherwise link a LiquidationLogic
  /// it deploys on its own.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @param liquidationLogic The LiquidationLogic address to link against.
  /// @return The library address.
  function deployBabylonLiquidationLogic(
    bytes32 salt,
    address liquidationLogic
  ) internal returns (address) {
    return _deployOrGet(salt, getLinkedBabylonLiquidationLogicCode(liquidationLogic));
  }

  /// @notice Returns the BabylonLiquidationLogic creation code linked against the given LiquidationLogic.
  /// @param liquidationLogic The LiquidationLogic address to link against.
  /// @return The linked creation code.
  function getLinkedBabylonLiquidationLogicCode(
    address liquidationLogic
  ) internal view returns (bytes memory) {
    require(liquidationLogic.code.length > 0, 'liquidation logic not deployed');
    string memory unlinked = vm.parseJsonString(
      vm.readFile(BABYLON_LIQUIDATION_LOGIC_ARTIFACT),
      '.bytecode.object'
    );
    string memory placeholder = string.concat(
      '__$',
      vm.replace(
        vm.toString(abi.encodePacked(bytes17(keccak256(bytes(LIQUIDATION_LOGIC_FQN))))),
        '0x',
        ''
      ),
      '$__'
    );
    require(vm.contains(unlinked, placeholder), 'liquidation logic placeholder not found');
    string memory linked = vm.replace(
      unlinked,
      placeholder,
      vm.replace(vm.toString(liquidationLogic), '0x', '')
    );
    require(!vm.contains(linked, '__$'), 'unlinked library reference');
    return vm.parseBytes(linked);
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

  /// @notice Deploys the liquidation libraries and appends FOUNDRY_LIBRARIES to .env.
  /// @param salt The CREATE2 salt for deterministic deployment.
  function _deployAndWriteLibrariesConfig(bytes32 salt) internal {
    address liquidationLogic = deployLiquidationLogic(salt);
    address babylonLiquidationLogic = deployBabylonLiquidationLogic(salt, liquidationLogic);

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

  /// @dev Deploys `bytecode` via CREATE2, or returns the existing contract at its CREATE2 address.
  function _deployOrGet(bytes32 salt, bytes memory bytecode) private returns (address) {
    address computed = Create2Utils.computeCreate2Address({salt: salt, bytecode: bytecode});
    if (Create2Utils.isContractDeployed(computed)) {
      return computed;
    }
    return Create2Utils.create2Deploy(salt, bytecode);
  }
}
