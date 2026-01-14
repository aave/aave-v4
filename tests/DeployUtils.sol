// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {
  TransparentUpgradeableProxy,
  ITransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Create2Utils} from 'tests/Create2Utils.sol';

library DeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function deploySpokeImplementation(address oracle) internal returns (ISpoke) {
    return deploySpokeImplementation(oracle, '');
  }

  function deploySpokeImplementation(address oracle, bytes32 salt) internal returns (ISpoke spoke) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle)
    );

    Create2Utils.setCreate2Factory();
    return ISpoke(Create2Utils.create2Deploy(salt, initCode));
  }

  function deploySpoke(
    address deployer,
    address oracle,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(
        _proxify(deployer, address(deploySpokeImplementation(oracle)), proxyAdminOwner, initData)
      );
  }

  function getDeterministicSpokeInstanceAddress(address oracle) internal returns (address) {
    return getDeterministicSpokeInstanceAddress(oracle, '');
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    bytes32 salt
  ) internal returns (address) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle)
    );
    bytes32 initCodeHash = keccak256(initCode);

    Create2Utils.setCreate2Factory();
    return Create2Utils.computeCreate2Address(salt, initCodeHash);
  }

  function deployHub(address authority) internal returns (IHub) {
    return deployHub(authority, '');
  }

  function deployHub(address authority, bytes32 salt) internal returns (IHub hub) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/hub/Hub.sol:Hub'),
      abi.encode(authority)
    );

    Create2Utils.setCreate2Factory();
    return IHub(Create2Utils.create2Deploy(salt, initCode));
  }

  function getDeterministicHubAddress(address authority) internal returns (address) {
    return getDeterministicHubAddress(authority, '');
  }

  function getDeterministicHubAddress(address authority, bytes32 salt) internal returns (address) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/hub/Hub.sol:Hub'),
      abi.encode(authority)
    );
    bytes32 initCodeHash = keccak256(initCode);

    Create2Utils.setCreate2Factory();
    return Create2Utils.computeCreate2Address(salt, initCodeHash);
  }

  function _proxify(
    address deployer,
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    vm.prank(deployer);
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      impl,
      proxyAdminOwner,
      initData
    );
    return address(proxy);
  }
}
