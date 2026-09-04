// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {AaveV4BaseParameters} from 'scripts/config/AaveV4BaseParameters.sol';
import {AaveV4TokenizationSpokeBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBatch.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title AaveV4BaseConfiguration
/// @author Aave Labs
/// @notice Configures a Base market as the deployer: grants the roles configuration needs, wires
/// every position manager and gateway to every Spoke, lists the configured assets on the Hub and
/// its Spokes, and halts each of them on the Hub.
/// @dev Runs against a deployment made with `grantRoles` false, which leaves the deployer holding
/// the AccessManager admin role and every selector wired to a role that nobody holds yet. The
/// deployer therefore takes the two configurator domain admin roles and passes the configurators
/// the roles they call the Hub and Spokes with, before configuring.
///
/// The asset list is empty until the launch set is decided, in which case this configures the
/// market — roles, liquidation configs and manager wiring — and lists nothing. See
/// `AaveV4BaseParameters` and docs/base-deploy.md.
library AaveV4BaseConfiguration {
  /// @notice Thrown when the AccessManager carries a non-zero delay, which would defer the
  /// deployer's self-granted roles and revert every configuration call that follows.
  error UnexpectedDelay();
  /// @notice Thrown when no owner is given for the tokenization spoke proxy admins.
  error InvalidProxyAdminOwner();
  /// @notice Thrown when a position manager is not owned by the deployer, so `registerSpoke` on it
  /// would revert. The Base deploy script is what arranges that ownership.
  error ManagerNotOwnedByDeployer(address manager, address owner);

  /// @notice Grants the roles configuration needs, applies the per-Spoke liquidation configs, wires
  /// the position managers and gateways, lists every configured asset on the Hub and its Spokes,
  /// deploys each one's tokenization spoke, and halts each asset on the Hub.
  /// @dev The halt comes last per asset so it also reaches that asset's tokenization spoke, which
  /// `haltAsset` only sees once it is registered on the Hub.
  /// @param market The deployed Base market.
  /// @param deployer The address holding the AccessManager admin role.
  /// @param assets The assets to list.
  /// @param proxyAdminOwner The owner of each tokenization spoke's ProxyAdmin.
  /// @return assetIds The Hub asset ids of the listed assets, in the order they were configured.
  function configure(
    AaveV4BaseConfigInputs.Market memory market,
    address deployer,
    AaveV4BaseConfigInputs.Asset[] memory assets,
    address proxyAdminOwner
  ) internal returns (uint256[] memory assetIds) {
    require(proxyAdminOwner != address(0), InvalidProxyAdminOwner());

    requireNoDelays(market);
    grantConfigurationRoles(market, deployer);
    setLiquidationConfigs(market);
    wirePositionManagers(market, deployer);

    assetIds = new uint256[](assets.length);
    for (uint256 i; i < assets.length; ++i) {
      uint256 assetId = listAssetOnHub(market, assets[i].underlying);
      listAssetOnSpokes(market, assetId, assets[i].priceSource);
      if (assets[i].tokenize) {
        deployTokenizationSpoke(market, assets[i], assetId, proxyAdminOwner);
      }
      IHubConfigurator(market.hubConfigurator).haltAsset(market.hub, assetId);

      assetIds[i] = assetId;
    }
  }

  /// @notice Reverts if the AccessManager would defer a role grant or an admin action.
  /// @dev A non-zero role grant delay or target admin delay would make the self-grants take effect
  /// only after the delay, so every configuration call afterwards would revert.
  /// @param market The deployed Base market.
  function requireNoDelays(AaveV4BaseConfigInputs.Market memory market) internal view {
    IAccessManager accessManager = IAccessManager(market.accessManager);

    require(accessManager.getTargetAdminDelay(market.accessManager) == 0, UnexpectedDelay());
    require(
      accessManager.getRoleGrantDelay(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE) == 0,
      UnexpectedDelay()
    );
    require(
      accessManager.getRoleGrantDelay(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE) == 0,
      UnexpectedDelay()
    );
    require(accessManager.getRoleGrantDelay(Roles.HUB_CONFIGURATOR_ROLE) == 0, UnexpectedDelay());
    require(accessManager.getRoleGrantDelay(Roles.SPOKE_CONFIGURATOR_ROLE) == 0, UnexpectedDelay());
  }

  /// @notice Grants the deployer both configurator domain admin roles, and each configurator the
  /// role it calls the Hub or Spokes with.
  /// @dev The two configurator grants are permanent: `grantRoles: false` skips them at deploy time,
  /// and without them a configurator call reverts even when its caller holds the domain admin role.
  /// @param market The deployed Base market.
  /// @param deployer The address holding the AccessManager admin role.
  function grantConfigurationRoles(
    AaveV4BaseConfigInputs.Market memory market,
    address deployer
  ) internal {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: market.accessManager,
      admin: deployer
    });
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: market.accessManager,
      admin: deployer
    });

    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: market.accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: market.hubConfigurator
    });
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: market.accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: market.spokeConfigurator
    });
  }

  /// @notice Applies the launch liquidation config to every Spoke.
  /// @dev Per Spoke rather than per reserve, so this runs once rather than per listed asset.
  /// @param market The deployed Base market.
  function setLiquidationConfigs(AaveV4BaseConfigInputs.Market memory market) internal {
    for (uint256 i; i < market.spokes.length; ++i) {
      ISpokeConfigurator(market.spokeConfigurator).updateLiquidationConfig(
        market.spokes[i],
        AaveV4BaseParameters.liquidationConfig()
      );
    }
  }

  /// @notice Wires every deployed position manager and gateway to every Spoke, both halves.
  /// @dev A manager is inert unless the Spoke has it active and the manager has the Spoke
  /// registered: `Spoke` checks `isPositionManagerActive`, the manager checks `onlyRegisteredSpoke`.
  ///
  /// Both halves run here. `updatePositionManager` needs the SpokeConfigurator domain admin role,
  /// which the deployer holds during configuration; `registerSpoke` is `onlyOwner` on the manager,
  /// which is why `AaveV4DeployBase` gives the deployer initial ownership of the managers and
  /// gateways rather than the Council. Ownership moves to the Council during the handover, leaving
  /// the Council nothing to do here beyond accepting it.
  /// @param market The deployed Base market.
  /// @param deployer The address that owns the managers during configuration.
  function wirePositionManagers(
    AaveV4BaseConfigInputs.Market memory market,
    address deployer
  ) internal {
    address[5] memory managers = [
      market.giverPositionManager,
      market.takerPositionManager,
      market.configPositionManager,
      market.nativeTokenGateway,
      market.signatureGateway
    ];

    for (uint256 i; i < managers.length; ++i) {
      if (managers[i] == address(0)) continue;
      require(
        Ownable(managers[i]).owner() == deployer,
        ManagerNotOwnedByDeployer(managers[i], Ownable(managers[i]).owner())
      );

      for (uint256 j; j < market.spokes.length; ++j) {
        ISpokeConfigurator(market.spokeConfigurator).updatePositionManager({
          spoke: market.spokes[j],
          positionManager: managers[i],
          active: true
        });
        IPositionManagerBase(managers[i]).registerSpoke(market.spokes[j], true);
      }
    }
  }

  /// @notice Lists an asset on the Hub with the launch rate curve and liquidity fee.
  /// @param market The deployed Base market.
  /// @param underlying The underlying asset to list.
  /// @return The Hub asset id of the listed asset.
  function listAssetOnHub(
    AaveV4BaseConfigInputs.Market memory market,
    address underlying
  ) internal returns (uint256) {
    IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: AaveV4BaseParameters.OPTIMAL_USAGE_RATIO,
        baseDrawnRate: AaveV4BaseParameters.BASE_DRAWN_RATE,
        rateGrowthBeforeOptimal: AaveV4BaseParameters.RATE_GROWTH_BEFORE_OPTIMAL,
        rateGrowthAfterOptimal: AaveV4BaseParameters.RATE_GROWTH_AFTER_OPTIMAL
      });

    return
      IHubConfigurator(market.hubConfigurator).addAsset({
        hub: market.hub,
        underlying: underlying,
        feeReceiver: market.treasurySpoke,
        liquidityFee: AaveV4BaseParameters.LIQUIDITY_FEE,
        irStrategy: market.irStrategy,
        irData: abi.encode(irData)
      });
  }

  /// @notice Registers every Spoke for the asset and lists the reserve on each of them.
  /// @param market The deployed Base market.
  /// @param assetId The Hub asset id.
  /// @param priceSource The price feed for the asset.
  function listAssetOnSpokes(
    AaveV4BaseConfigInputs.Market memory market,
    uint256 assetId,
    address priceSource
  ) internal {
    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = assetId;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](1);
    configs[0] = IHub.SpokeConfig({
      addCap: AaveV4BaseParameters.ADD_CAP,
      drawCap: AaveV4BaseParameters.DRAW_CAP,
      riskPremiumThreshold: AaveV4BaseParameters.RISK_PREMIUM_THRESHOLD,
      active: true,
      halted: false
    });

    ISpoke.ReserveConfig memory config = ISpoke.ReserveConfig({
      collateralRisk: AaveV4BaseParameters.COLLATERAL_RISK,
      paused: false,
      frozen: false,
      borrowable: AaveV4BaseParameters.BORROWABLE,
      receiveSharesEnabled: AaveV4BaseParameters.RECEIVE_SHARES_ENABLED
    });
    ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
      collateralFactor: AaveV4BaseParameters.COLLATERAL_FACTOR,
      maxLiquidationBonus: AaveV4BaseParameters.MAX_LIQUIDATION_BONUS,
      liquidationFee: AaveV4BaseParameters.LIQUIDATION_FEE
    });

    for (uint256 i; i < market.spokes.length; ++i) {
      IHubConfigurator(market.hubConfigurator).addSpokeToAssets({
        hub: market.hub,
        spoke: market.spokes[i],
        assetIds: assetIds,
        configs: configs
      });
      ISpokeConfigurator(market.spokeConfigurator).addReserve({
        spoke: market.spokes[i],
        hub: market.hub,
        assetId: assetId,
        priceSource: priceSource,
        config: config,
        dynamicConfig: dynamicConfig
      });
    }
  }

  /// @notice Deploys the asset's tokenization spoke and registers it on the Hub as supply-only.
  /// @dev Must run after `listAssetOnHub`: `TokenizationSpoke`'s constructor resolves the asset id
  /// off the Hub and reverts if the asset is not listed.
  ///
  /// The ProxyAdmin owner is passed explicitly, so it lands on the market's owner rather than on
  /// whoever ran the configuration. The config engine's `TokenizationSpokeDeployer` takes it
  /// explicitly too as of #1321, so either route is safe now; this path uses
  /// `AaveV4TokenizationSpokeBatch` because configuration here runs as direct calls from an EOA
  /// rather than as a delegatecalled payload.
  /// @param market The deployed Base market.
  /// @param asset The asset being tokenized.
  /// @param assetId The Hub asset id of that asset.
  /// @param proxyAdminOwner The owner of the tokenization spoke's ProxyAdmin.
  /// @return The tokenization spoke proxy.
  function deployTokenizationSpoke(
    AaveV4BaseConfigInputs.Market memory market,
    AaveV4BaseConfigInputs.Asset memory asset,
    uint256 assetId,
    address proxyAdminOwner
  ) internal returns (address) {
    string memory assetSymbol = IERC20Metadata(asset.underlying).symbol();

    address proxy = new AaveV4TokenizationSpokeBatch({
      hub_: market.hub,
      underlying_: asset.underlying,
      proxyAdminOwner_: proxyAdminOwner,
      shareName_: AaveV4BaseParameters.tokenizationShareName(assetSymbol),
      shareSymbol_: AaveV4BaseParameters.tokenizationShareSymbol(assetSymbol),
      salt_: keccak256(abi.encode(market.hub, asset.underlying, 'tokenizationSpoke'))
    }).getReport().tokenizationSpokeProxy;

    IHubConfigurator(market.hubConfigurator).addSpoke({
      hub: market.hub,
      spoke: proxy,
      assetId: assetId,
      config: IHub.SpokeConfig({
        addCap: AaveV4BaseParameters.TOKENIZATION_ADD_CAP,
        drawCap: 0,
        riskPremiumThreshold: AaveV4BaseParameters.RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    });

    return proxy;
  }
}
