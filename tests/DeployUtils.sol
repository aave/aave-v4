// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubInstance} from 'tests/mocks/IHubInstance.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {Create2Utils} from 'tests/Create2Utils.sol';

library DeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal returns (ISpokeInstance) {
    return deploySpokeImplementation(oracle, maxUserReservesLimit, '');
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
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(
        proxify(
          address(deploySpokeImplementation(oracle, maxUserReservesLimit, '')),
          proxyAdminOwner,
          initData
        )
      );
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal returns (address) {
    return getDeterministicSpokeInstanceAddress(oracle, maxUserReservesLimit, '');
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

  function deployHubImplementation() internal returns (IHubInstance) {
    return deployHubImplementation('');
  }

  function deployHubImplementation(bytes32 salt) internal returns (IHubInstance) {
    Create2Utils.loadCreate2Factory();
    return IHubInstance(Create2Utils.create2Deploy(salt, _getHubInstanceInitCode()));
  }

  function deployHub(address authority, address proxyAdminOwner) internal returns (IHub) {
    return
      IHub(
        proxify(
          address(deployHubImplementation()),
          proxyAdminOwner,
          abi.encodeCall(IHubInstance.initialize, (authority))
        )
      );
  }

  function deployHub(
    address authority,
    address proxyAdminOwner,
    bytes32 salt
  ) internal returns (IHub) {
    return
      IHub(
        proxify(
          address(deployHubImplementation(salt)),
          proxyAdminOwner,
          abi.encodeCall(IHubInstance.initialize, (authority))
        )
      );
  }

  function proxify(
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

  function _getHubInstanceInitCode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }
}
