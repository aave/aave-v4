// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

import {AaveV4BabylonConfig} from 'scripts/markets/babylon/AaveV4BabylonConfig.sol';
import {
  IBabylonAaveAdapter,
  IBabylonBTCVaultSwap,
  IBabylonVaultBTC
} from 'scripts/markets/babylon/interfaces/IBabylonIntegration.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {ERC1967Utils} from 'src/dependencies/openzeppelin/ERC1967Utils.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {ProxyAdmin} from 'src/dependencies/openzeppelin/ProxyAdmin.sol';
import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IBabylonSpoke} from 'src/spoke/interfaces/IBabylonSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title AaveV4BabylonVerification
/// @author Aave Labs
/// @notice Read-only checks of a Babylon market against its config, reverting on the first mismatch.
/// @dev The role end state follows Ethereum with every governance holder collapsed into `admin`:
///
/// | role                                | holder                |
/// | ----------------------------------- | --------------------- |
/// | 0   ACCESS_MANAGER_ADMIN            | admin                 |
/// | 101 HUB_CONFIGURATOR_ROLE           | the HubConfigurator   |
/// | 200 HUB_CONFIGURATOR_DOMAIN_ADMIN   | admin                 |
/// | 301 SPOKE_CONFIGURATOR_ROLE         | the SpokeConfigurator |
/// | 400 SPOKE_CONFIGURATOR_DOMAIN_ADMIN | admin                 |
/// | every other role                    | nobody                |
///
/// When the config sets `authority`, the Hubs and the BabylonSpoke move to it and the deployed
/// AccessManager is left with no admin and no role member, see `verifyAbandonedAccessManager`.
library AaveV4BabylonVerification {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Reverts unless every deployed contract exists and is wired to the others as configured.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  /// @param authority The expected AccessManager of the Hubs and the BabylonSpoke.
  function verifyDeployment(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment,
    address authority
  ) internal view {
    address accessManager = deployment.accessManager;
    _requireCode(accessManager, 'access manager code');
    _requireCode(deployment.treasurySpoke, 'treasury spoke code');
    _requireCode(deployment.oracle, 'oracle code');
    require(
      IAccessManaged(deployment.hubConfigurator).authority() == accessManager,
      'hub configurator authority'
    );
    require(
      IAccessManaged(deployment.spokeConfigurator).authority() == accessManager,
      'spoke configurator authority'
    );

    for (uint256 i; i < deployment.hubs.length; ++i) {
      require(IAccessManaged(deployment.hubs[i]).authority() == authority, 'hub authority');
      require(
        getImplementation(deployment.hubs[i]) == deployment.hubImplementations[i],
        'hub implementation'
      );
      require(
        config.referenceHub == address(0) ||
          deployment.hubImplementations[i].codehash ==
            getImplementation(config.referenceHub).codehash,
        'hub implementation code'
      );
      require(
        IAssetInterestRateStrategy(deployment.irStrategies[i]).HUB() == deployment.hubs[i],
        'ir strategy hub'
      );
    }

    IBabylonSpoke babylonSpoke = IBabylonSpoke(deployment.babylonSpoke);
    require(
      IAccessManaged(deployment.babylonSpoke).authority() == authority,
      'babylon spoke authority'
    );
    require(
      getImplementation(deployment.babylonSpoke) == deployment.babylonSpokeImplementation,
      'babylon spoke implementation'
    );
    require(ISpoke(deployment.babylonSpoke).ORACLE() == deployment.oracle, 'babylon spoke oracle');
    require(IAaveOracle(deployment.oracle).spoke() == deployment.babylonSpoke, 'oracle spoke');
    address liquidationLogic = ISpoke(deployment.babylonSpoke).getLiquidationLogic();
    address babylonLiquidationLogic = babylonSpoke.getBabylonLiquidationLogic();
    _requireCode(liquidationLogic, 'liquidation logic code');
    _requireCode(babylonLiquidationLogic, 'babylon liquidation logic code');
    // BabylonLiquidationLogic exposes the LiquidationLogic it links through the Spoke's getter
    require(
      ISpoke(babylonLiquidationLogic).getLiquidationLogic() == liquidationLogic,
      'babylon liquidation logic'
    );
    require(babylonSpoke.LIQUIDATION_MANAGER() == config.liquidationManager, 'liquidation manager');
    require(
      babylonSpoke.MANAGED_COLLATERAL_RESERVE_ID() == config.managedCollateralReserveId,
      'managed collateral reserve id'
    );
  }

  /// @notice Reverts unless every role holds exactly its end-state members.
  /// @dev Exact member lists also prove the deployer holds no role, since `admin` is not the deployer.
  /// @param deployment The deployed Babylon market.
  /// @param admin The address the market is handed over to.
  /// @param deployer The deployer.
  function verifyRoles(
    AaveV4BabylonConfig.Deployment memory deployment,
    address admin,
    address deployer
  ) internal view {
    require(admin != deployer, 'admin is deployer');
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    _requireOnlyMember(accessManager, Roles.ACCESS_MANAGER_ADMIN_ROLE, admin);
    _requireOnlyMember(accessManager, Roles.HUB_CONFIGURATOR_ROLE, deployment.hubConfigurator);
    _requireOnlyMember(accessManager, Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);
    _requireOnlyMember(accessManager, Roles.SPOKE_CONFIGURATOR_ROLE, deployment.spokeConfigurator);
    _requireOnlyMember(accessManager, Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, admin);

    uint64[5] memory unheld = [
      Roles.HUB_DOMAIN_ADMIN_ROLE,
      Roles.HUB_FEE_MINTER_ROLE,
      Roles.HUB_DEFICIT_ELIMINATOR_ROLE,
      Roles.SPOKE_DOMAIN_ADMIN_ROLE,
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE
    ];
    for (uint256 i; i < unheld.length; ++i) {
      _requireNoMembers(accessManager, unheld[i]);
    }

    // catches a role outside `Roles` that something granted
    uint256 roleCount = accessManager.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      uint64 role = accessManager.getRole(i);
      if (
        role != Roles.HUB_CONFIGURATOR_ROLE &&
        role != Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE &&
        role != Roles.SPOKE_CONFIGURATOR_ROLE &&
        role != Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE
      ) {
        _requireNoMembers(accessManager, role);
      }
    }
  }

  /// @notice Reverts unless a production config sets every field its checks depend on.
  /// @param config The Babylon market config.
  function verifyProductionConfig(AaveV4BabylonConfig.Config memory config) internal view {
    if (!config.production) {
      return;
    }
    require(config.admin.code.length > 0, 'production admin code');
    require(config.authority != address(0), 'production authority');
    require(config.feeReceiver != address(0), 'production fee receiver');
    require(config.referenceHub != address(0), 'production reference hub');
    require(
      config.liquidationManagerDeployer != address(0),
      'production liquidation manager deployer'
    );
    require(
      config.btcVaultSwap.swap != address(0) && config.btcVaultSwap.hub != address(0),
      'production btc vault swap'
    );
  }

  /// @notice Reverts unless `config.authority` has left the Hubs and the BabylonSpoke untouched: open,
  /// with no admin delay and no restricted function mapped, and the deployer holds no role on it.
  /// @dev Holds from the handover until governance maps the roles. Skipped without `authority`. A
  /// target admin delay that is scheduled but not yet in effect is not visible to it.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function verifyAuthorityTargets(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view {
    if (config.authority == address(0)) {
      return;
    }
    require(config.authority != deployment.accessManager, 'authority is the deployed one');
    require(config.authority.code.length > 0, 'authority code');
    IAccessManagerEnumerable authority = IAccessManagerEnumerable(config.authority);
    (bool deployerIsAdmin, ) = authority.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, config.deployer);
    require(!deployerIsAdmin, 'deployer holds the authority');
    uint256 roleCount = authority.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      (bool hasRole, ) = authority.hasRole(authority.getRole(i), config.deployer);
      require(!hasRole, 'deployer holds an authority role');
    }

    for (uint256 i; i < deployment.hubs.length; ++i) {
      _requireUntouchedTarget(authority, deployment.hubs[i]);
      _requireUnmapped(authority, deployment.hubs[i], Roles.getHubConfiguratorRoleSelectors());
      _requireUnmapped(authority, deployment.hubs[i], Roles.getHubFeeMinterRoleSelectors());
      _requireUnmapped(authority, deployment.hubs[i], Roles.getHubDeficitEliminatorRoleSelectors());
    }
    _requireUntouchedTarget(authority, deployment.babylonSpoke);
    _requireUnmapped(authority, deployment.babylonSpoke, Roles.getSpokeConfiguratorRoleSelectors());
    _requireUnmapped(
      authority,
      deployment.babylonSpoke,
      Roles.getSpokePositionUpdaterRoleSelectors()
    );
  }

  /// @notice Reverts unless the deployed AccessManager, left behind when the Hubs and the BabylonSpoke
  /// moved to `config.authority`, has no holder.
  /// @dev `getRole` does not list the admin role, so it is checked on its own.
  /// @param deployment The deployed Babylon market.
  /// @param admin The address the market is handed over to.
  /// @param deployer The deployer.
  function verifyAbandonedAccessManager(
    AaveV4BabylonConfig.Deployment memory deployment,
    address admin,
    address deployer
  ) internal view {
    require(admin != deployer, 'admin is deployer');
    IAccessManagerEnumerable accessManager = IAccessManagerEnumerable(deployment.accessManager);
    (bool adminIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, admin);
    require(!adminIsAdmin, 'admin holds the deployed access manager');
    (bool deployerIsAdmin, ) = accessManager.hasRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, deployer);
    require(!deployerIsAdmin, 'deployer holds the deployed access manager');
    _requireNoMembers(accessManager, Roles.ACCESS_MANAGER_ADMIN_ROLE);

    uint256 roleCount = accessManager.getRoleCount();
    for (uint256 i; i < roleCount; ++i) {
      _requireNoMembers(accessManager, accessManager.getRole(i));
    }
  }

  /// @notice Reverts unless every ProxyAdmin in the market is owned by `owner`.
  /// @dev Walks every spoke registered on each Hub asset too, so a spoke connected later is covered.
  /// @param deployment The deployed Babylon market.
  /// @param owner The expected owner of every ProxyAdmin.
  /// @param externalSpokes The configured external spokes, which this market does not own.
  /// @param externalFeeReceiver The configured fee receiver when it is outside this market, else zero.
  /// @param treasurySpokeOwner The expected owner of the deployed TreasurySpoke's ProxyAdmin.
  function verifyProxyAdmins(
    AaveV4BabylonConfig.Deployment memory deployment,
    address owner,
    AaveV4BabylonConfig.ExternalSpoke[] memory externalSpokes,
    address externalFeeReceiver,
    address treasurySpokeOwner
  ) internal view {
    _requireProxyAdminOwner(deployment.babylonSpoke, owner);
    _requireProxyAdminOwner(deployment.treasurySpoke, treasurySpokeOwner);
    for (uint256 i; i < deployment.hubs.length; ++i) {
      IHub hub = IHub(deployment.hubs[i]);
      _requireProxyAdminOwner(address(hub), owner);
      uint256 assetCount = hub.getAssetCount();
      for (uint256 assetId; assetId < assetCount; ++assetId) {
        uint256 spokeCount = hub.getSpokeCount(assetId);
        for (uint256 j; j < spokeCount; ++j) {
          address spoke = hub.getSpokeAddress(assetId, j);
          if (
            spoke != externalFeeReceiver &&
            spoke != deployment.treasurySpoke &&
            !_isExternalSpoke(externalSpokes, address(hub), spoke)
          ) {
            _requireProxyAdminOwner(spoke, owner);
          }
        }
      }
    }
  }

  /// @notice Reverts unless the TreasurySpoke is owned by `owner`, or, if `allowPending`, has
  /// `owner` as pending owner.
  /// @param deployment The deployed Babylon market.
  /// @param owner The expected TreasurySpoke owner.
  /// @param allowPending Whether an ownership transfer that is not accepted yet passes.
  function verifyTreasurySpokeOwner(
    AaveV4BabylonConfig.Deployment memory deployment,
    address owner,
    bool allowPending
  ) internal view {
    Ownable2StepUpgradeable treasurySpoke = Ownable2StepUpgradeable(deployment.treasurySpoke);
    if (treasurySpoke.owner() == owner) {
      require(treasurySpoke.pendingOwner() == address(0), 'treasury spoke pending owner');
      return;
    }
    require(allowPending && treasurySpoke.pendingOwner() == owner, 'treasury spoke owner');
  }

  /// @notice Reverts unless the Hubs and the BabylonSpoke hold exactly the configured market.
  /// @param deployment The deployed Babylon market.
  /// @param marketConfig The configured market.
  /// @param feeReceiver The expected fee receiver of every listed asset.
  function verifyMarketConfig(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.MarketConfig memory marketConfig,
    address feeReceiver
  ) internal view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    require(
      spoke.getReserveCount() ==
        marketConfig.reserves.length + marketConfig.externalReserves.length,
      'reserve count'
    );
    for (uint256 i; i < deployment.hubs.length; ++i) {
      require(
        IHub(deployment.hubs[i]).getAssetCount() == _listingCount(marketConfig, deployment.hubs[i]),
        'hub asset count'
      );
    }

    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      _verifyReserve({
        deployment: deployment,
        listing: marketConfig.reserves[i],
        reserveId: i,
        externalSpokes: marketConfig.externalSpokes,
        feeReceiver: feeReceiver
      });
    }

    for (uint256 i; i < marketConfig.externalReserves.length; ++i) {
      _verifyExternalReserve({
        deployment: deployment,
        externalReserve: marketConfig.externalReserves[i],
        reserveId: marketConfig.reserves.length + i
      });
    }

    for (uint256 i; i < marketConfig.externalSpokes.length; ++i) {
      AaveV4BabylonConfig.ExternalSpoke memory externalSpoke = marketConfig.externalSpokes[i];
      IHub hub = IHub(externalSpoke.hub);
      uint256 assetId = hub.getAssetId(externalSpoke.underlying);
      require(hub.isSpokeListed(assetId, externalSpoke.spoke), 'external spoke not listed');
      require(
        keccak256(abi.encode(hub.getSpokeConfig(assetId, externalSpoke.spoke))) ==
          keccak256(abi.encode(externalSpoke.spokeConfig)),
        'external spoke config'
      );
    }

    require(
      keccak256(abi.encode(spoke.getLiquidationConfig())) ==
        keccak256(abi.encode(marketConfig.liquidationConfig)),
      'liquidation config'
    );
  }

  /// @notice Reverts unless every configured TokenizationSpoke is in the report, wraps its asset on
  /// its Hub with the configured name and symbol, has its ProxyAdmin owned by `owner` and is not
  /// connected on the Hub.
  /// @param config The Babylon market config.
  /// @param marketConfig The market config.
  /// @param owner The expected owner of every TokenizationSpoke ProxyAdmin.
  function verifyTokenizationSpokes(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.MarketConfig memory marketConfig,
    address owner
  ) internal view {
    for (uint256 i; i < marketConfig.tokenizationSpokes.length; ++i) {
      AaveV4BabylonConfig.TokenizationSpoke memory expected = marketConfig.tokenizationSpokes[i];
      (address proxy, address implementation) = AaveV4BabylonConfig.readTokenizationSpoke(
        config,
        expected.symbol
      );
      require(proxy != address(0), 'tokenization spoke not deployed');
      _requireCode(proxy, 'tokenization spoke');
      _requireCode(implementation, 'tokenization spoke implementation');
      require(getImplementation(proxy) == implementation, 'tokenization spoke implementation');
      _requireProxyAdminOwner(proxy, owner);
      require(_isListedReserve(marketConfig, expected), 'tokenization spoke asset not a reserve');

      ITokenizationSpoke tokenizationSpoke = ITokenizationSpoke(proxy);
      IHub hub = IHub(expected.hub);
      uint256 assetId = hub.getAssetId(expected.underlying);
      require(tokenizationSpoke.hub() == expected.hub, 'tokenization spoke hub');
      require(tokenizationSpoke.assetId() == assetId, 'tokenization spoke asset id');
      require(tokenizationSpoke.asset() == expected.underlying, 'tokenization spoke asset');
      require(
        keccak256(bytes(tokenizationSpoke.name())) == keccak256(bytes(expected.name)),
        'tokenization spoke name'
      );
      require(
        keccak256(bytes(tokenizationSpoke.symbol())) == keccak256(bytes(expected.symbol)),
        'tokenization spoke symbol'
      );
      require(!hub.isSpokeListed(assetId, proxy), 'tokenization spoke connected');
    }
  }

  /// @notice Reverts unless Babylon's AaveAdapter and BTCVaultSwap are wired to the market as configured.
  /// @dev On a production config both must be deployed. Otherwise each is checked only when deployed.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function verifyBabylonContracts(
    AaveV4BabylonConfig.Config memory config,
    AaveV4BabylonConfig.Deployment memory deployment
  ) internal view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    address adapter = config.liquidationManager;
    if (adapter.code.length == 0) {
      require(!config.production, 'aave adapter not deployed');
    } else {
      IBabylonAaveAdapter aaveAdapter = IBabylonAaveAdapter(adapter);
      require(aaveAdapter.BTC_VAULT_CORE_SPOKE() == address(spoke), 'aave adapter spoke');
      require(
        aaveAdapter.VAULT_BTC_RESERVE_ID() == config.managedCollateralReserveId,
        'aave adapter vaultBTC reserve'
      );
      require(
        aaveAdapter.BTC_VAULT_HUB() ==
          address(spoke.getReserve(config.managedCollateralReserveId).hub),
        'aave adapter hub'
      );
      require(
        aaveAdapter.EXIT_BTC_RESERVE_ID() == config.exitReserveId,
        'aave adapter exit reserve'
      );
      require(
        aaveAdapter.liquidationFeeBps() == config.liquidationManagerFeeBps,
        'aave adapter liquidation fee'
      );
      ISpoke.Reserve memory collateral = spoke.getReserve(config.managedCollateralReserveId);
      require(aaveAdapter.VAULT_BTC() == collateral.underlying, 'aave adapter vaultBTC');
      require(IBabylonVaultBTC(collateral.underlying).adapter() == adapter, 'vaultBTC adapter');
      require(
        IBabylonVaultBTC(collateral.underlying).HUB() == address(collateral.hub),
        'vaultBTC hub'
      );
      require(
        !config.production || IERC20(collateral.underlying).totalSupply() == 0,
        'vaultBTC supply'
      );
    }

    AaveV4BabylonConfig.BtcVaultSwap memory expected = config.btcVaultSwap;
    if (expected.swap.code.length == 0) {
      require(!config.production, 'btc vault swap not deployed');
      return;
    }
    IBabylonBTCVaultSwap btcVaultSwap = IBabylonBTCVaultSwap(expected.swap);
    address exitBtc = spoke.getReserve(config.exitReserveId).underlying;
    require(btcVaultSwap.ADAPTER() == adapter, 'btc vault swap adapter');
    require(btcVaultSwap.HUB() == expected.hub, 'btc vault swap hub');
    require(btcVaultSwap.EXIT_BTC() == exitBtc, 'btc vault swap exit btc');
    require(
      btcVaultSwap.EXIT_BTC_ASSET_ID() == IHub(expected.hub).getAssetId(exitBtc),
      'btc vault swap exit asset id'
    );
    require(
      btcVaultSwap.sellDiscountBps() == expected.sellDiscountBps,
      'btc vault swap sell discount'
    );
    require(
      btcVaultSwap.minimumProfitThresholdBps() == expected.minimumProfitThresholdBps,
      'btc vault swap minimum profit'
    );
    require(
      IAccessManaged(expected.swap).authority() ==
        AaveV4BabylonConfig.finalAuthority(config, deployment),
      'btc vault swap authority'
    );
    _requireProxyAdminOwner(expected.swap, config.admin);
  }

  /// @notice Returns the ProxyAdmin of a transparent proxy, read from its ERC-1967 admin slot.
  /// @param proxy The proxy.
  function getProxyAdmin(address proxy) internal view returns (address) {
    // the slot holds a left-padded address, truncating the high bits is intended
    return address(uint160(uint256(vm.load(proxy, ERC1967Utils.ADMIN_SLOT))));
  }

  /// @notice Returns the implementation of a proxy, read from its ERC-1967 implementation slot.
  /// @param proxy The proxy.
  function getImplementation(address proxy) internal view returns (address) {
    // the slot holds a left-padded address, truncating the high bits is intended
    return address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT))));
  }

  function _verifyReserve(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.ReserveListing memory listing,
    uint256 reserveId,
    AaveV4BabylonConfig.ExternalSpoke[] memory externalSpokes,
    address feeReceiver
  ) private view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    require(address(reserve.hub) == listing.hub, 'reserve hub');
    require(reserve.underlying == listing.underlying, 'reserve underlying');
    require(spoke.getReserveId(listing.hub, reserve.assetId) == reserveId, 'reserve id');
    require(
      IAaveOracle(deployment.oracle).getReserveSource(reserveId) == listing.priceSource,
      'reserve price source'
    );
    require(
      keccak256(abi.encode(spoke.getReserveConfig(reserveId))) ==
        keccak256(abi.encode(listing.reserveConfig)),
      'reserve config'
    );
    require(
      keccak256(abi.encode(spoke.getDynamicReserveConfig(reserveId, reserve.dynamicConfigKey))) ==
        keccak256(abi.encode(listing.dynamicConfig)),
      'dynamic reserve config'
    );

    IHub hub = IHub(listing.hub);
    IHub.Asset memory asset = hub.getAsset(reserve.assetId);
    require(asset.underlying == listing.underlying, 'asset underlying');
    require(asset.feeReceiver == feeReceiver, 'asset fee receiver');
    require(asset.liquidityFee == listing.liquidityFee, 'asset liquidity fee');
    require(asset.irStrategy == listing.irStrategy, 'asset ir strategy');
    require(asset.reinvestmentController == address(0), 'asset reinvestment controller');
    require(
      keccak256(
        abi.encode(
          IAssetInterestRateStrategy(listing.irStrategy).getInterestRateData(reserve.assetId)
        )
      ) == keccak256(abi.encode(listing.irData)),
      'asset ir data'
    );

    // the fee receiver added by `addAsset`, the BabylonSpoke when connected and the external spokes
    require(
      hub.getSpokeCount(reserve.assetId) ==
        1 +
          (listing.connected ? 1 : 0) +
          _externalSpokeCount(externalSpokes, listing.hub, listing.underlying),
      'asset spoke count'
    );
    if (listing.connected) {
      require(
        keccak256(abi.encode(hub.getSpokeConfig(reserve.assetId, deployment.babylonSpoke))) ==
          keccak256(abi.encode(listing.spokeConfig)),
        'babylon spoke config'
      );
    } else {
      require(
        !hub.isSpokeListed(reserve.assetId, deployment.babylonSpoke),
        'babylon spoke connected'
      );
    }
    require(
      keccak256(abi.encode(hub.getSpokeConfig(reserve.assetId, feeReceiver))) ==
        keccak256(
          abi.encode(
            IHub.SpokeConfig({
              addCap: type(uint40).max,
              drawCap: 0,
              riskPremiumThreshold: 0,
              active: true,
              halted: false
            })
          )
        ),
      'fee receiver config'
    );
  }

  /// @dev The BabylonSpoke side only. The Hub connects the BabylonSpoke through governance.
  function _verifyExternalReserve(
    AaveV4BabylonConfig.Deployment memory deployment,
    AaveV4BabylonConfig.ExternalReserve memory externalReserve,
    uint256 reserveId
  ) private view {
    ISpoke spoke = ISpoke(deployment.babylonSpoke);
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    require(address(reserve.hub) == externalReserve.hub, 'external reserve hub');
    require(reserve.underlying == externalReserve.underlying, 'external reserve underlying');
    require(
      reserve.assetId == IHub(externalReserve.hub).getAssetId(externalReserve.underlying),
      'external reserve asset id'
    );
    require(
      spoke.getReserveId(externalReserve.hub, reserve.assetId) == reserveId,
      'external reserve id'
    );
    require(
      IAaveOracle(deployment.oracle).getReserveSource(reserveId) == externalReserve.priceSource,
      'external reserve price source'
    );
    require(
      keccak256(abi.encode(spoke.getReserveConfig(reserveId))) ==
        keccak256(abi.encode(externalReserve.reserveConfig)),
      'external reserve config'
    );
    require(
      keccak256(abi.encode(spoke.getDynamicReserveConfig(reserveId, reserve.dynamicConfigKey))) ==
        keccak256(abi.encode(externalReserve.dynamicConfig)),
      'external dynamic reserve config'
    );
  }

  function _isListedReserve(
    AaveV4BabylonConfig.MarketConfig memory marketConfig,
    AaveV4BabylonConfig.TokenizationSpoke memory tokenizationSpoke
  ) private pure returns (bool) {
    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      if (
        marketConfig.reserves[i].hub == tokenizationSpoke.hub &&
        marketConfig.reserves[i].underlying == tokenizationSpoke.underlying
      ) {
        return true;
      }
    }
    return false;
  }

  function _externalSpokeCount(
    AaveV4BabylonConfig.ExternalSpoke[] memory externalSpokes,
    address hub,
    address underlying
  ) private pure returns (uint256 count) {
    for (uint256 i; i < externalSpokes.length; ++i) {
      if (externalSpokes[i].hub == hub && externalSpokes[i].underlying == underlying) {
        ++count;
      }
    }
  }

  function _isExternalSpoke(
    AaveV4BabylonConfig.ExternalSpoke[] memory externalSpokes,
    address hub,
    address spoke
  ) private pure returns (bool) {
    for (uint256 i; i < externalSpokes.length; ++i) {
      if (externalSpokes[i].hub == hub && externalSpokes[i].spoke == spoke) {
        return true;
      }
    }
    return false;
  }

  function _listingCount(
    AaveV4BabylonConfig.MarketConfig memory marketConfig,
    address hub
  ) private pure returns (uint256 count) {
    for (uint256 i; i < marketConfig.reserves.length; ++i) {
      if (marketConfig.reserves[i].hub == hub) {
        ++count;
      }
    }
  }

  function _requireOnlyMember(
    IAccessManagerEnumerable accessManager,
    uint64 role,
    address account
  ) private view {
    (bool isMember, ) = accessManager.hasRole(role, account);
    require(
      isMember && accessManager.getRoleMemberCount(role) == 1,
      string.concat('unexpected role members: ', vm.toString(role))
    );
  }

  function _requireUntouchedTarget(
    IAccessManagerEnumerable authority,
    address target
  ) private view {
    require(!authority.isTargetClosed(target), 'authority target closed');
    require(authority.getTargetAdminDelay(target) == 0, 'authority target admin delay');
  }

  function _requireUnmapped(
    IAccessManagerEnumerable authority,
    address target,
    bytes4[] memory selectors
  ) private view {
    for (uint256 i; i < selectors.length; ++i) {
      require(
        authority.getTargetFunctionRole(target, selectors[i]) == Roles.ACCESS_MANAGER_ADMIN_ROLE,
        'authority target function mapped'
      );
    }
  }

  function _requireNoMembers(IAccessManagerEnumerable accessManager, uint64 role) private view {
    require(
      accessManager.getRoleMemberCount(role) == 0,
      string.concat('unexpected role members: ', vm.toString(role))
    );
  }

  function _requireProxyAdminOwner(address proxy, address owner) private view {
    address proxyAdmin = getProxyAdmin(proxy);
    require(proxyAdmin != address(0), 'not a transparent proxy');
    require(ProxyAdmin(proxyAdmin).owner() == owner, 'proxy admin owner');
  }

  function _requireCode(address target, string memory what) private view {
    require(target.code.length > 0, what);
  }
}
