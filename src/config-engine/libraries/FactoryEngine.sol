// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

/// @title FactoryEngine
/// @author Aave Labs
/// @notice Library containing HubSpokeFactory deployment logic for AaveV4ConfigEngine.
/// @dev The engine runs via delegatecall from the payload, so the factory binds every salt to the governance
/// executor. Payloads predict the deployed addresses with the factory `predict*` functions, using the executor as
/// deployer.
library FactoryEngine {
  /// @dev Thrown when a deployment field carries a KEEP_CURRENT sentinel. A deployment has no
  /// current value to keep, so a sentinel there is always a drafting mistake.
  error KeepCurrentNotAllowed();

  /// @notice Deploys Hubs and their interest rate strategies.
  /// @param factory The HubSpokeFactory.
  /// @param deployments The Hub deployments to execute.
  function executeHubDeployments(
    IHubSpokeFactory factory,
    IAaveV4ConfigEngine.HubDeployment[] calldata deployments
  ) external {
    uint256 length = deployments.length;
    for (uint256 i; i < length; ++i) {
      require(!_hasKeepCurrent(deployments[i]), KeepCurrentNotAllowed());
      factory.deployHub({
        salt: deployments[i].salt,
        authority: deployments[i].authority,
        proxyAdminOwner: deployments[i].proxyAdminOwner
      });
    }
  }

  /// @notice Deploys Spokes and their AaveOracles.
  /// @param factory The HubSpokeFactory.
  /// @param deployments The Spoke deployments to execute.
  function executeSpokeDeployments(
    IHubSpokeFactory factory,
    IAaveV4ConfigEngine.SpokeDeployment[] calldata deployments
  ) external {
    uint256 length = deployments.length;
    for (uint256 i; i < length; ++i) {
      require(!_hasKeepCurrent(deployments[i]), KeepCurrentNotAllowed());
      factory.deploySpoke({
        salt: deployments[i].salt,
        authority: deployments[i].authority,
        maxUserReservesLimit: deployments[i].maxUserReservesLimit,
        proxyAdminOwner: deployments[i].proxyAdminOwner
      });
    }
  }

  /// @notice Deploys TreasurySpokes.
  /// @param factory The HubSpokeFactory.
  /// @param deployments The TreasurySpoke deployments to execute.
  function executeTreasurySpokeDeployments(
    IHubSpokeFactory factory,
    IAaveV4ConfigEngine.TreasurySpokeDeployment[] calldata deployments
  ) external {
    uint256 length = deployments.length;
    for (uint256 i; i < length; ++i) {
      require(!_hasKeepCurrent(deployments[i]), KeepCurrentNotAllowed());
      factory.deployTreasurySpoke({
        salt: deployments[i].salt,
        owner: deployments[i].owner,
        proxyAdminOwner: deployments[i].proxyAdminOwner
      });
    }
  }

  /// @notice Deploys a TokenizationSpoke, salted with its Hub asset and share token metadata.
  /// @param factory The HubSpokeFactory.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @param name The ERC20 name of the share token.
  /// @param symbol The ERC20 symbol of the share token.
  /// @param proxyAdminOwner The owner of the TokenizationSpoke ProxyAdmin.
  /// @return The TokenizationSpoke proxy.
  function deployTokenizationSpoke(
    IHubSpokeFactory factory,
    address hub,
    address underlying,
    string calldata name,
    string calldata symbol,
    address proxyAdminOwner
  ) internal returns (address) {
    return
      factory.deployTokenizationSpoke({
        salt: _tokenizationSpokeSalt(hub, underlying, name, symbol),
        hub: hub,
        underlying: underlying,
        name: name,
        symbol: symbol,
        proxyAdminOwner: proxyAdminOwner
      });
  }

  /// @notice Predicts the address of a TokenizationSpoke deployed on an asset listing.
  /// @param factory The HubSpokeFactory.
  /// @param deployer The governance executor running the payload.
  /// @param hub The Hub of the tokenized asset.
  /// @param underlying The underlying of the tokenized asset.
  /// @param name The ERC20 name of the share token.
  /// @param symbol The ERC20 symbol of the share token.
  /// @param proxyAdminOwner The owner of the TokenizationSpoke ProxyAdmin.
  /// @return The predicted TokenizationSpoke proxy.
  function predictTokenizationSpoke(
    IHubSpokeFactory factory,
    address deployer,
    address hub,
    address underlying,
    string memory name,
    string memory symbol,
    address proxyAdminOwner
  ) internal view returns (address) {
    return
      factory.predictTokenizationSpoke({
        deployer: deployer,
        salt: _tokenizationSpokeSalt(hub, underlying, name, symbol),
        hub: hub,
        underlying: underlying,
        name: name,
        symbol: symbol,
        proxyAdminOwner: proxyAdminOwner
      });
  }

  /// @dev Returns true if any Hub deployment field carries the KEEP_CURRENT sentinel of its width.
  function _hasKeepCurrent(
    IAaveV4ConfigEngine.HubDeployment calldata deployment
  ) private pure returns (bool) {
    return
      deployment.authority == EngineFlags.KEEP_CURRENT_ADDRESS ||
      deployment.proxyAdminOwner == EngineFlags.KEEP_CURRENT_ADDRESS;
  }

  /// @dev Returns true if any Spoke deployment field carries the KEEP_CURRENT sentinel of its width.
  function _hasKeepCurrent(
    IAaveV4ConfigEngine.SpokeDeployment calldata deployment
  ) private pure returns (bool) {
    return
      deployment.authority == EngineFlags.KEEP_CURRENT_ADDRESS ||
      deployment.maxUserReservesLimit == EngineFlags.KEEP_CURRENT_UINT16 ||
      deployment.proxyAdminOwner == EngineFlags.KEEP_CURRENT_ADDRESS;
  }

  /// @dev Returns true if any TreasurySpoke deployment field carries the KEEP_CURRENT sentinel of its width.
  function _hasKeepCurrent(
    IAaveV4ConfigEngine.TreasurySpokeDeployment calldata deployment
  ) private pure returns (bool) {
    return
      deployment.owner == EngineFlags.KEEP_CURRENT_ADDRESS ||
      deployment.proxyAdminOwner == EngineFlags.KEEP_CURRENT_ADDRESS;
  }

  function _tokenizationSpokeSalt(
    address hub,
    address underlying,
    string memory name,
    string memory symbol
  ) private pure returns (bytes32) {
    return keccak256(abi.encode(hub, underlying, name, symbol));
  }
}
