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

  // keccak256('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic')[:34]
  string internal constant LIQUIDATION_LOGIC_PLACEHOLDER =
    '__$a48140799943db40fec4e369e92a011fa5$__';

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
        Create2Utils.create2Deploy(
          salt,
          _getSpokeInstanceInitCode(oracle, maxUserReservesLimit, salt)
        )
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
    Create2Utils.loadCreate2Factory();
    bytes32 initCodeHash = keccak256(_getSpokeInstanceInitCode(oracle, maxUserReservesLimit, salt));
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
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (bytes memory) {
    bytes memory liquidationLogicInitCode = vm.parseJsonBytes(
      vm.readFile('out/LiquidationLogic.sol/LiquidationLogic.spoke.json'),
      '.bytecode.object'
    );
    address liquidationLogic = Create2Utils.create2Deploy(salt, liquidationLogicInitCode);

    string memory spokeHex = vm.parseJsonString(
      vm.readFile('out/SpokeInstance.sol/SpokeInstance.json'),
      '.bytecode.object'
    );

    string memory addrHex = vm.replace(vm.toLowercase(vm.toString(liquidationLogic)), '0x', '');
    string memory patchedHex = vm.replace(spokeHex, LIQUIDATION_LOGIC_PLACEHOLDER, addrHex);

    return abi.encodePacked(vm.parseBytes(patchedHex), abi.encode(oracle, maxUserReservesLimit));
  }

  function _getHubInstanceInitCode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }
}
