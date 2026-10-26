// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

import {AaveV4MarketPayloadsBase, IOwnable} from 'scripts/markets/AaveV4MarketPayloadsBase.s.sol';
import {Infra} from 'scripts/markets/ethereum/AaveV4Contracts.sol';
import {PermissionsPayload} from 'scripts/markets/ethereum/payloads/PermissionsPayload.sol';
import {ConfigPayload_1_HubAssetListings} from 'scripts/markets/ethereum/payloads/ConfigPayload_1_HubAssetListings.sol';
import {TokenizationSpokePayload} from 'scripts/markets/ethereum/payloads/TokenizationSpokePayload.sol';
import {ConfigPayload_2_HubSpokeRegistrations} from 'scripts/markets/ethereum/payloads/ConfigPayload_2_HubSpokeRegistrations.sol';
import {ConfigPayload_3a_SpokeReserveListings} from 'scripts/markets/ethereum/payloads/ConfigPayload_3a_SpokeReserveListings.sol';
import {ConfigPayload_3b_SpokeReserveListings} from 'scripts/markets/ethereum/payloads/ConfigPayload_3b_SpokeReserveListings.sol';
import {Deactivate} from 'scripts/markets/ethereum/payloads/Deactivate.sol';
import {DiffPayload} from 'scripts/markets/ethereum/payloads/DiffPayload.sol';
import {ConfigPayload_4_SpokePositionManagerUpdates} from 'scripts/markets/ethereum/payloads/ConfigPayload_4_SpokePositionManagerUpdates.sol';
import {ConfigPayload_5_PositionManagerSpokeRegistrations} from 'scripts/markets/ethereum/payloads/ConfigPayload_5_PositionManagerSpokeRegistrations.sol';
import {FinalPermissionsPayload} from 'scripts/markets/ethereum/payloads/FinalPermissionsPayload.sol';

/// @title AaveV4EthereumMarketPayloads
/// @author Aave Labs
/// @notice Configures the initial Aave V4 Ethereum market through the deployer-owned Executor, then hands it over.
/// @dev Steps, in broadcast order (see scripts/markets/README.md):
///      1. setup()     after AaveV4DeployEthereumMarket
///      2. TokenizationSpokeDeploy, then regenerate TokenizationSpokePayload
///      3. listings()  with the ConfigEngine deployed in setup()
///      4. handover()
contract AaveV4EthereumMarketPayloads is AaveV4MarketPayloadsBase {
  address internal constant EXECUTOR = 0x778b07a501a7a8d7625e51C3Ea84D090118f0161;
  address internal constant GOVERNANCE_EXECUTOR = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;
  address internal constant SECURITY_COUNCIL = 0x187AAE17d4931310B3fc75743e7F16Bdc9eD77e9;

  /// @notice Hands the position managers and configurator domain admin roles to the Executor,
  /// then deploys the ConfigEngine and executes the permissions and hub asset listings payloads.
  function setup() external {
    vm.startBroadcast();
    _setupExecutor(EXECUTOR, Infra.ACCESS_MANAGER, _positionManagers());
    _exec(EXECUTOR, address(new PermissionsPayload()));

    AaveV4ConfigEngine configEngine = new AaveV4ConfigEngine();
    _exec(EXECUTOR, address(new ConfigPayload_1_HubAssetListings(configEngine)));
    vm.stopBroadcast();
  }

  /// @notice Executes the tokenization, spoke registrations, reserve listings and remaining payloads.
  /// @param configEngine The ConfigEngine deployed in setup().
  function listings(IAaveV4ConfigEngine configEngine) external {
    vm.startBroadcast();
    _exec(EXECUTOR, address(new TokenizationSpokePayload(configEngine)));
    _exec(EXECUTOR, address(new ConfigPayload_2_HubSpokeRegistrations(configEngine)));
    _exec(EXECUTOR, address(new ConfigPayload_3a_SpokeReserveListings(configEngine)));
    _exec(EXECUTOR, address(new ConfigPayload_3b_SpokeReserveListings(configEngine)));
    _exec(EXECUTOR, address(new Deactivate()));
    _exec(EXECUTOR, address(new DiffPayload(configEngine)));
    _exec(EXECUTOR, address(new ConfigPayload_4_SpokePositionManagerUpdates(configEngine)));
    _exec(EXECUTOR, address(new ConfigPayload_5_PositionManagerSpokeRegistrations(configEngine)));
    vm.stopBroadcast();
  }

  /// @notice Hands the market over to Governance and the Security Council, and renounces the deployer roles.
  function handover() external {
    IAccessManager accessManager = IAccessManager(Infra.ACCESS_MANAGER);
    string memory deployment = vm.readFile('scripts/markets/ethereum/config/deployment.json');
    string memory tokenization = vm.readFile(
      'scripts/markets/ethereum/config/tokenization-deploy.json'
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

    _renounceDeployerRoles(address(accessManager), deployer);
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
