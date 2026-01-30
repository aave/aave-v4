// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {Create2Utils} from 'tests/Create2Utils.sol';
import {Constants} from 'tests/Constants.sol';

library DeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function deploySpokeImplementation(address oracle) internal returns (ISpokeInstance) {
    return deploySpokeImplementation(oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT, '');
  }

  function deploySpokeImplementation(
    address oracle,
    bytes32 salt
  ) internal returns (ISpokeInstance spoke) {
    return deploySpokeImplementation(oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT, salt);
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (ISpokeInstance spoke) {
    Create2Utils.loadCreate2Factory();
    return
      ISpokeInstance(
        Create2Utils.create2Deploy(salt, _getSpokeInstanceInitCode(oracle, maxUserReservesLimit))
      );
  }

  function deploySpoke(
    address oracle,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      deploySpoke(oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT, proxyAdminOwner, initData);
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(
        _proxify(
          address(deploySpokeImplementation(oracle, maxUserReservesLimit, '')),
          proxyAdminOwner,
          initData
        )
      );
  }

  function getDeterministicSpokeInstanceAddress(address oracle) internal returns (address) {
    return
      getDeterministicSpokeInstanceAddress(oracle, Constants.MAX_ALLOWED_USER_RESERVES_LIMIT, '');
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address) {
    bytes32 initCodeHash = keccak256(_getSpokeInstanceInitCode(oracle, maxUserReservesLimit));

    Create2Utils.loadCreate2Factory();
    return Create2Utils.computeCreate2Address(salt, initCodeHash);
  }

  function deployHub(address authority) internal returns (IHub) {
    return deployHub(authority, '');
  }

  function deployHub(address authority, bytes32 salt) internal returns (IHub hub) {
    Create2Utils.loadCreate2Factory();
    return IHub(Create2Utils.create2Deploy(salt, _getHubInitCode(authority)));
  }

  function getDeterministicHubAddress(address authority) internal returns (address) {
    return getDeterministicHubAddress(authority, '');
  }

  function getDeterministicHubAddress(address authority, bytes32 salt) internal returns (address) {
    bytes32 initCodeHash = keccak256(_getHubInitCode(authority));

    Create2Utils.loadCreate2Factory();
    return Create2Utils.computeCreate2Address(salt, initCodeHash);
  }

  function _proxify(
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      impl,
      proxyAdminOwner,
      initData
    );
    return address(proxy);
  }

  function _getSpokeInstanceInitCode(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal view returns (bytes memory) {
    return
      abi.encodePacked(
        vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
        abi.encode(oracle, maxUserReservesLimit)
      );
  }

  function _getHubInitCode(address authority) internal view returns (bytes memory) {
    return abi.encodePacked(vm.getCode('src/hub/Hub.sol:Hub'), abi.encode(authority));
  }
}
