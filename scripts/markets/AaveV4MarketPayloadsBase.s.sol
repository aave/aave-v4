// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {ERC1967Utils} from 'src/dependencies/openzeppelin/ERC1967Utils.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

/// @title AaveV4MarketPayloadsBase
/// @author Aave Labs
/// @notice Shared helpers to configure a freshly deployed market through an Aave Governance Executor
/// owned by the deployer, and to hand the market over once configured.
abstract contract AaveV4MarketPayloadsBase is Script {
  /// @dev Transfers the position managers to the Executor and grants it the configurator domain admin roles.
  /// The position managers ownership is accepted by the PermissionsPayload.
  function _setupExecutor(
    address executor,
    address accessManager,
    address[5] memory positionManagers
  ) internal {
    for (uint256 i; i < positionManagers.length; ++i) {
      IOwnable(positionManagers[i]).transferOwnership(executor);
    }
    IAccessManager(accessManager).grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, executor, 0);
    IAccessManager(accessManager).grantRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      executor,
      0
    );
  }

  /// @dev Delegatecalls `execute()` on the payload from the Executor.
  function _exec(address executor, address payload) internal {
    IExecutor(executor).executeTransaction({
      target: payload,
      value: 0,
      signature: 'execute()',
      data: new bytes(0),
      withDelegatecall: true
    });
  }

  /// @dev Transfers the ownership of the ProxyAdmin of every proxy of the `label => proxy` map under `key` in `json`.
  function _transferProxyAdminsOwnership(
    string memory json,
    string memory key,
    address newOwner
  ) internal {
    string[] memory labels = vm.parseJsonKeys(json, key);
    for (uint256 i; i < labels.length; ++i) {
      _transferProxyAdminOwnership(
        vm.parseJsonAddress(json, string.concat(key, '.', labels[i])),
        newOwner
      );
    }
  }

  /// @dev Transfers the ownership of the ProxyAdmin of every TokenizationSpoke of a `hub => token => proxy` json.
  function _transferTokenizationProxyAdminsOwnership(
    string memory json,
    address newOwner
  ) internal {
    string[] memory hubs = vm.parseJsonKeys(json, '$');
    for (uint256 i; i < hubs.length; ++i) {
      _transferProxyAdminsOwnership(json, string.concat('.', hubs[i]), newOwner);
    }
  }

  function _transferProxyAdminOwnership(address proxy, address newOwner) internal {
    address proxyAdmin = address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
    IOwnable(proxyAdmin).transferOwnership(newOwner);
  }

  /// @dev Renounces every role the deployer was granted during the market deployment, admin role last.
  function _renounceDeployerRoles(address accessManager, address deployer) internal {
    uint64[10] memory roles = [
      Roles.HUB_DOMAIN_ADMIN_ROLE,
      Roles.HUB_CONFIGURATOR_ROLE,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      Roles.ACCESS_MANAGER_ADMIN_ROLE
    ];
    for (uint256 i; i < roles.length; ++i) {
      IAccessManager(accessManager).renounceRole(roles[i], deployer);
    }
  }
}

interface IExecutor {
  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    bool withDelegatecall
  ) external payable returns (bytes memory);
}

interface IOwnable {
  function transferOwnership(address newOwner) external;
}
