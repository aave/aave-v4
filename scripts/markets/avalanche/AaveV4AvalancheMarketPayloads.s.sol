// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

import {AaveV4MarketPayloadsBase, IOwnable} from 'scripts/markets/AaveV4MarketPayloadsBase.s.sol';
import {Infra} from 'scripts/markets/avalanche/AaveV4Contracts.sol';
import {PermissionsPayload} from 'scripts/markets/avalanche/payloads/PermissionsPayload.sol';
import {ConfigPayload_1_HubAssetListings} from 'scripts/markets/avalanche/payloads/ConfigPayload_1_HubAssetListings.sol';
import {ConfigPayload_2_HubSpokeRegistrations} from 'scripts/markets/avalanche/payloads/ConfigPayload_2_HubSpokeRegistrations.sol';
import {ConfigPayload_3_SpokeReserveListings} from 'scripts/markets/avalanche/payloads/ConfigPayload_3_SpokeReserveListings.sol';
import {ConfigPayload_4_SpokePositionManagerUpdates} from 'scripts/markets/avalanche/payloads/ConfigPayload_4_SpokePositionManagerUpdates.sol';
import {ConfigPayload_5_PositionManagerSpokeRegistrations} from 'scripts/markets/avalanche/payloads/ConfigPayload_5_PositionManagerSpokeRegistrations.sol';
import {TokenizationSpokePayload} from 'scripts/markets/avalanche/payloads/TokenizationSpokePayload.sol';
import {DeactivateHub} from 'scripts/markets/avalanche/payloads/DeactivateHub.sol';
import {FinalPermissionsPayload} from 'scripts/markets/avalanche/payloads/FinalPermissionsPayload.sol';

/// @title AaveV4AvalancheMarketPayloads
/// @author Aave Labs
/// @notice Configures the initial Aave V4 Avalanche market through the deployer-owned Executor, then hands it over.
/// @dev Steps, in broadcast order (see scripts/markets/README.md):
///      1. setup()     after AaveV4DeployAvalancheMarket
///      2. TokenizationSpokeDeploy, then regenerate TokenizationSpokePayload
///      3. listings()
///      4. handover()  once EXECUTOR_2 is deployed
contract AaveV4AvalancheMarketPayloads is AaveV4MarketPayloadsBase {
  address internal constant EXECUTOR = 0x5066364AE356DC95837772d9fC17ed926Fd54576;
  address internal constant EXECUTOR_2 = 0xb619fA61e795D47f517702e63ce50292370561F1;
  address internal constant GOVERNANCE_EXECUTOR = 0x3C06dce358add17aAf230f2234bCCC4afd50d090;
  address internal constant SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;

  /// @notice Hands the position managers and configurator domain admin roles to the Executor,
  /// then deploys the ConfigEngine and executes the permissions and listing payloads.
  function setup() external {
    vm.startBroadcast();
    _setupExecutor(EXECUTOR, Infra.ACCESS_MANAGER, _positionManagers());
    _exec(EXECUTOR, address(new PermissionsPayload()));

    AaveV4ConfigEngine configEngine = new AaveV4ConfigEngine();
    address[5] memory payloads = [
      address(new ConfigPayload_1_HubAssetListings(configEngine)),
      address(new ConfigPayload_2_HubSpokeRegistrations(configEngine)),
      address(new ConfigPayload_3_SpokeReserveListings(configEngine)),
      address(new ConfigPayload_4_SpokePositionManagerUpdates(configEngine)),
      address(new ConfigPayload_5_PositionManagerSpokeRegistrations(configEngine))
    ];
    for (uint256 i; i < payloads.length; ++i) {
      _exec(EXECUTOR, payloads[i]);
    }
    vm.stopBroadcast();
  }

  /// @notice Registers the TokenizationSpokes on the hub and deactivates the hub assets.
  function listings() external {
    vm.startBroadcast();
    _exec(EXECUTOR, address(new TokenizationSpokePayload(new AaveV4ConfigEngine())));
    _exec(EXECUTOR, address(new DeactivateHub()));
    vm.stopBroadcast();
  }

  /// @notice Hands the market over to Governance and the Security Council, and renounces the deployer roles.
  function handover() external {
    IAccessManager accessManager = IAccessManager(Infra.ACCESS_MANAGER);
    string memory deployment = vm.readFile('scripts/markets/avalanche/config/deployment.json');
    string memory tokenization = vm.readFile(
      'scripts/markets/avalanche/config/tokenization-deploy.json'
    );

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, GOVERNANCE_EXECUTOR, 0);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, SECURITY_COUNCIL, 0);
    _exec(EXECUTOR, address(new FinalPermissionsPayload()));
    accessManager.revokeRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, EXECUTOR);
    accessManager.revokeRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, EXECUTOR);
    IOwnable(Infra.TREASURY_SPOKE).transferOwnership(SECURITY_COUNCIL);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, GOVERNANCE_EXECUTOR, 0);

    _transferProxyAdminOwnership(Infra.TREASURY_SPOKE, SECURITY_COUNCIL);
    _transferProxyAdminsOwnership(deployment, '.hub', SECURITY_COUNCIL);
    _transferProxyAdminsOwnership(deployment, '.spoke', SECURITY_COUNCIL);
    _transferTokenizationProxyAdminsOwnership(tokenization, SECURITY_COUNCIL);

    IOwnable(EXECUTOR_2).transferOwnership(SECURITY_COUNCIL);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, EXECUTOR_2, 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, EXECUTOR_2, 0);

    _renounceDeployerRoles(address(accessManager), deployer);
    IOwnable(EXECUTOR).transferOwnership(SECURITY_COUNCIL);
    vm.stopBroadcast();
  }

  function _positionManagers() internal pure returns (address[5] memory) {
    return
      [
        Infra.CONFIG_POSITION_MANAGER,
        Infra.GIVER_POSITION_MANAGER,
        Infra.TAKER_POSITION_MANAGER,
        Infra.NATIVE_TOKEN_GATEWAY,
        Infra.SIGNATURE_GATEWAY
      ];
  }
}
