// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraParameters} from 'scripts/config/AaveV4SentoraParameters.sol';
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

/// @title AaveV4SentoraConfiguration
/// @author Aave Labs
/// @notice Configures a Sentora market as the deployer: grants the roles configuration needs, wires
/// every position manager and gateway to every Spoke, lists the configured assets on the Hub and
/// each configured reserve on its Spoke, and halts every asset on the Hub.
/// @dev Runs against a deployment made with `grantRoles` false, which leaves the deployer holding
/// the AccessManager admin role and every selector wired to a role that nobody holds yet. The
/// deployer therefore takes the two configurator domain admin roles and passes the configurators
/// the roles they call the Hub and Spokes with, before configuring.
///
/// Each asset is listed with the rate curve carried in config/sentora-config.json, and each reserve
/// only on the Spoke it names, with that Spoke's caps and risk parameters. Every asset is then
/// halted on the Hub, which is what keeps the market closed until it is opened. An empty asset list
/// configures the market — roles, liquidation configs and manager wiring — and lists nothing. See
/// `AaveV4SentoraParameters` and docs/sentora-deploy.md.
library AaveV4SentoraConfiguration {
  /// @notice Thrown when the AccessManager carries a non-zero delay, which would defer the
  /// deployer's self-granted roles and revert every configuration call that follows.
  error UnexpectedDelay();
  /// @notice Thrown when no owner is given for the tokenization spoke proxy admins.
  error InvalidProxyAdminOwner();
  /// @notice Thrown when a position manager is not owned by the deployer, so `registerSpoke` on it
  /// would revert. The Sentora deploy script is what arranges that ownership.
  error ManagerNotOwnedByDeployer(address manager, address owner);

  /// @notice Grants the roles configuration needs, applies the per-Spoke liquidation configs, wires
  /// the position managers and gateways, lists every configured asset on the Hub and every
  /// configured reserve on its Spoke, deploys the tokenization spokes, and halts each asset on the
  /// Hub.
  /// @dev The halts come last so they also reach every Spoke and tokenization spoke of an asset,
  /// which `haltAsset` only sees once they are registered on the Hub.
  /// @param market The deployed Sentora market.
  /// @param deployer The address holding the AccessManager admin role.
  /// @param assets The assets to list on the Hub.
  /// @param reserves The reserves to list on the Spokes, each naming one of `assets`.
  /// @param proxyAdminOwner The owner of each tokenization spoke's ProxyAdmin.
  /// @return assetIds The Hub asset ids of the listed assets, in the order they were configured.
  function configure(
    AaveV4SentoraConfigInputs.Market memory market,
    address deployer,
    AaveV4SentoraConfigInputs.Asset[] memory assets,
    AaveV4SentoraConfigInputs.Reserve[] memory reserves,
    address proxyAdminOwner
  ) internal returns (uint256[] memory assetIds) {
    require(proxyAdminOwner != address(0), InvalidProxyAdminOwner());

    requireNoDelays(market);
    grantConfigurationRoles(market, deployer);
    setLiquidationConfigs(market);
    wirePositionManagers(market, deployer);

    assetIds = new uint256[](assets.length);
    for (uint256 i; i < assets.length; ++i) {
      assetIds[i] = listAssetOnHub(market, assets[i]);
    }

    for (uint256 i; i < reserves.length; ++i) {
      listReserve(
        market,
        assetIds[reserves[i].assetIndex],
        assets[reserves[i].assetIndex],
        reserves[i]
      );
    }

    for (uint256 i; i < assets.length; ++i) {
      if (assets[i].tokenize) {
        deployTokenizationSpoke(market, assets[i], assetIds[i], proxyAdminOwner);
      }
      IHubConfigurator(market.hubConfigurator).haltAsset(market.hub, assetIds[i]);
    }
  }

  /// @notice Reverts if the AccessManager would defer a role grant or an admin action.
  /// @dev A non-zero role grant delay or target admin delay would make the self-grants take effect
  /// only after the delay, so every configuration call afterwards would revert.
  /// @param market The deployed Sentora market.
  function requireNoDelays(AaveV4SentoraConfigInputs.Market memory market) internal view {
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
  /// @param market The deployed Sentora market.
  /// @param deployer The address holding the AccessManager admin role.
  function grantConfigurationRoles(
    AaveV4SentoraConfigInputs.Market memory market,
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
  /// @param market The deployed Sentora market.
  function setLiquidationConfigs(AaveV4SentoraConfigInputs.Market memory market) internal {
    for (uint256 i; i < market.spokes.length; ++i) {
      ISpokeConfigurator(market.spokeConfigurator).updateLiquidationConfig(
        market.spokes[i],
        AaveV4SentoraParameters.liquidationConfig()
      );
    }
  }

  /// @notice Wires every deployed position manager and gateway to every Spoke, both halves.
  /// @dev A manager is inert unless the Spoke has it active and the manager has the Spoke
  /// registered: `Spoke` checks `isPositionManagerActive`, the manager checks `onlyRegisteredSpoke`.
  ///
  /// Both halves run here. `updatePositionManager` needs the SpokeConfigurator domain admin role,
  /// which the deployer holds during configuration; `registerSpoke` is `onlyOwner` on the manager,
  /// which is why `AaveV4DeploySentora` gives the deployer initial ownership of the managers and
  /// gateways rather than the admin. Ownership moves to the admin during the handover, leaving the
  /// admin nothing to do here beyond accepting it.
  /// @param market The deployed Sentora market.
  /// @param deployer The address that owns the managers during configuration.
  function wirePositionManagers(
    AaveV4SentoraConfigInputs.Market memory market,
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

  /// @notice Lists an asset on the Hub with its rate curve and liquidity fee.
  /// @param market The deployed Sentora market.
  /// @param asset The asset to list.
  /// @return The Hub asset id of the listed asset.
  function listAssetOnHub(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Asset memory asset
  ) internal returns (uint256) {
    IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: asset.optimalUsageRatio,
        baseDrawnRate: asset.baseDrawnRate,
        rateGrowthBeforeOptimal: asset.rateGrowthBeforeOptimal,
        rateGrowthAfterOptimal: asset.rateGrowthAfterOptimal
      });

    return
      IHubConfigurator(market.hubConfigurator).addAsset({
        hub: market.hub,
        underlying: asset.underlying,
        feeReceiver: market.treasurySpoke,
        liquidityFee: asset.liquidityFee,
        irStrategy: market.irStrategy,
        irData: abi.encode(irData)
      });
  }

  /// @notice Registers the reserve's Spoke for the asset on the Hub and lists the reserve on it.
  /// @param market The deployed Sentora market.
  /// @param assetId The Hub asset id of the reserve's asset.
  /// @param asset The reserve's asset, which carries the price source.
  /// @param reserve The reserve being listed.
  function listReserve(
    AaveV4SentoraConfigInputs.Market memory market,
    uint256 assetId,
    AaveV4SentoraConfigInputs.Asset memory asset,
    AaveV4SentoraConfigInputs.Reserve memory reserve
  ) internal {
    address spoke = market.spokes[reserve.spokeIndex];

    IHubConfigurator(market.hubConfigurator).addSpoke({
      hub: market.hub,
      spoke: spoke,
      assetId: assetId,
      config: IHub.SpokeConfig({
        addCap: reserve.addCap,
        drawCap: reserve.drawCap,
        riskPremiumThreshold: reserve.riskPremiumThreshold,
        active: true,
        halted: false
      })
    });
    ISpokeConfigurator(market.spokeConfigurator).addReserve({
      spoke: spoke,
      hub: market.hub,
      assetId: assetId,
      priceSource: asset.priceSource,
      config: ISpoke.ReserveConfig({
        collateralRisk: reserve.collateralRisk,
        paused: false,
        frozen: false,
        borrowable: reserve.borrowable,
        receiveSharesEnabled: reserve.receiveSharesEnabled
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: reserve.collateralFactor,
        maxLiquidationBonus: reserve.maxLiquidationBonus,
        liquidationFee: reserve.liquidationFee
      })
    });
  }

  /// @notice Deploys the asset's tokenization spoke and registers it on the Hub as supply-only, with
  /// no draw and hence no risk premium to bound.
  /// @dev Must run after `listAssetOnHub`: `TokenizationSpoke`'s constructor resolves the asset id
  /// off the Hub and reverts if the asset is not listed.
  ///
  /// The ProxyAdmin owner is passed explicitly, so it lands on the market's owner rather than on
  /// whoever ran the configuration. The config engine's `TokenizationSpokeDeployer` takes it
  /// explicitly too as of #1321, so either route is safe now; this path uses
  /// `AaveV4TokenizationSpokeBatch` because configuration here runs as direct calls from an EOA
  /// rather than as a delegatecalled payload.
  /// @param market The deployed Sentora market.
  /// @param asset The asset being tokenized.
  /// @param assetId The Hub asset id of that asset.
  /// @param proxyAdminOwner The owner of the tokenization spoke's ProxyAdmin.
  /// @return The tokenization spoke proxy.
  function deployTokenizationSpoke(
    AaveV4SentoraConfigInputs.Market memory market,
    AaveV4SentoraConfigInputs.Asset memory asset,
    uint256 assetId,
    address proxyAdminOwner
  ) internal returns (address) {
    string memory assetSymbol = IERC20Metadata(asset.underlying).symbol();

    address proxy = new AaveV4TokenizationSpokeBatch({
      hub_: market.hub,
      underlying_: asset.underlying,
      proxyAdminOwner_: proxyAdminOwner,
      shareName_: AaveV4SentoraParameters.tokenizationShareName(assetSymbol),
      shareSymbol_: AaveV4SentoraParameters.tokenizationShareSymbol(assetSymbol),
      salt_: keccak256(abi.encode(market.hub, asset.underlying, 'tokenizationSpoke'))
    }).getReport().tokenizationSpokeProxy;

    IHubConfigurator(market.hubConfigurator).addSpoke({
      hub: market.hub,
      spoke: proxy,
      assetId: assetId,
      config: IHub.SpokeConfig({
        addCap: asset.tokenizationAddCap,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    });

    return proxy;
  }
}
