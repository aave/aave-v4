// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';
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

/// @title ArcConfiguration
/// @author Aave Labs
/// @notice Applies the `ArcParameters` risk parameters to an Arc market, then halts every asset it
/// listed on the Hub.
/// @dev Runs against a deployment made with `grantRoles` false, which leaves the deployer holding
/// the AccessManager admin role and every selector wired to a role that nobody holds yet. The
/// deployer therefore takes the two configurator domain admin roles and passes the configurators
/// the roles they call the Hub and Spokes with, before configuring.
///
/// Only the assets in the launch set are configured, so an asset whose token or price feed does not
/// exist yet is simply left out: see `ArcConfigInputs.readAssets`. The parameters for every asset
/// and spoke pair are in `ArcParameters` regardless of whether it launches.
///
/// Caps are passed in whole token units. The Hub scales them by the underlying's own `decimals()`,
/// so a cap never has to be pre-scaled here and cannot be scaled wrongly.
library ArcConfiguration {
  /// @notice Thrown when the AccessManager carries a non-zero delay, which would defer the
  /// deployer's self-granted roles and revert every configuration call that follows.
  error UnexpectedDelay();
  /// @notice Thrown when the deployed spoke count does not match the parameter tables.
  error SpokeCountMismatch(uint256 deployed, uint256 expected);
  /// @notice Thrown when no owner is given for the tokenization spoke proxy admins.
  error InvalidProxyAdminOwner();
  /// @notice Thrown when a position manager is not owned by the deployer, so `registerSpoke` on it
  /// would revert. The Arc deploy script is what arranges that ownership.
  error ManagerNotOwnedByDeployer(address manager, address owner);
  /// @notice Thrown when an underlying does not have the decimals its asset is expected to have.
  error UnexpectedDecimals(string symbol, uint8 actual, uint8 expected);

  /// @notice Grants the roles configuration needs, applies the per-spoke liquidation configs, lists
  /// every asset in the launch set on the Hub and its spokes, deploys each one's tokenization spoke,
  /// and halts each asset on the Hub.
  /// @dev The halt comes last per asset so it also reaches that asset's tokenization spoke, which
  /// `haltAsset` only sees once it is registered on the Hub.
  /// @param market The deployed Arc market.
  /// @param deployer The address holding the AccessManager admin role.
  /// @param assets The launch set.
  /// @param proxyAdminOwner The owner of each tokenization spoke's ProxyAdmin.
  function configure(
    ArcConfigInputs.Market memory market,
    address deployer,
    ArcConfigInputs.AssetInput[] memory assets,
    address proxyAdminOwner
  ) internal {
    require(
      market.spokes.length == ArcParameters.spokeCount(),
      SpokeCountMismatch(market.spokes.length, ArcParameters.spokeCount())
    );
    require(proxyAdminOwner != address(0), InvalidProxyAdminOwner());

    requireNoDelays(market);
    grantConfigurationRoles(market, deployer);
    setLiquidationConfigs(market);
    wirePositionManagers(market, deployer);

    for (uint256 i; i < assets.length; ++i) {
      requireListable(assets[i]);
      uint256 assetId = listAssetOnHub(market, assets[i]);
      listAssetOnSpokes(market, assets[i], assetId);
      deployTokenizationSpoke(market, assets[i], assetId, proxyAdminOwner);
      IHubConfigurator(market.hubConfigurator).haltAsset(market.hub, assetId);
    }
  }

  /// @notice Deploys the asset's tokenization spoke and registers it on the Hub as supply-only.
  /// @dev Must run after `listAssetOnHub`: `TokenizationSpoke`'s constructor resolves the asset id
  /// off the Hub and reverts if the asset is not listed.
  ///
  /// The ProxyAdmin owner is passed explicitly. The config engine's `TokenizationSpokeDeployer`
  /// takes it explicitly too as of #1321, so either route is safe now, but this path uses
  /// `AaveV4TokenizationSpokeBatch` because configuration here runs as direct calls from an EOA
  /// rather than as a delegatecalled payload.
  /// @param market The deployed Arc market.
  /// @param asset The asset being tokenized.
  /// @param assetId The Hub asset id of that asset.
  /// @param proxyAdminOwner The owner of the tokenization spoke's ProxyAdmin.
  /// @return The tokenization spoke proxy, or the zero address when the asset has no published cap.
  function deployTokenizationSpoke(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId,
    address proxyAdminOwner
  ) internal returns (address) {
    uint40 addCap = ArcParameters.assetParams(asset.key).tokenizationAddCap;
    if (addCap == 0) return address(0);

    // the share token name follows the underlying's own symbol, as on Ethereum and Avalanche
    string memory assetSymbol = IERC20Metadata(asset.underlying).symbol();

    AaveV4TokenizationSpokeBatch batch = new AaveV4TokenizationSpokeBatch({
      hub_: market.hub,
      underlying_: asset.underlying,
      proxyAdminOwner_: proxyAdminOwner,
      shareName_: ArcParameters.tokenizationShareName(assetSymbol),
      shareSymbol_: ArcParameters.tokenizationShareSymbol(assetSymbol),
      salt_: keccak256(abi.encode(market.hub, asset.underlying, 'tokenizationSpoke'))
    });
    address proxy = batch.getReport().tokenizationSpokeProxy;

    IHubConfigurator(market.hubConfigurator).addSpoke({
      hub: market.hub,
      spoke: proxy,
      assetId: assetId,
      config: IHub.SpokeConfig({
        addCap: addCap,
        drawCap: 0,
        riskPremiumThreshold: ArcParameters.RISK_PREMIUM_THRESHOLD,
        active: true,
        halted: false
      })
    });

    return proxy;
  }

  /// @notice Reverts unless the underlying has the decimals the asset is expected to have.
  /// @dev `ArcConfigInputs` already rejects an address with no code, which is what a testnet address
  /// looks like here; this covers a live contract that is not the intended token.
  ///
  /// It does not validate the price source, and nothing here does. `AaveOracle.setReserveSource`
  /// checks its decimals are 8 and that it returns a price, which is all a wrong-but-live feed has
  /// to do to pass: a capped adapter built against the wrong cap or base feed reports 8 decimals
  /// like any other. The price source is verified off-chain, before it reaches this config.
  /// @param asset The asset to check.
  function requireListable(ArcConfigInputs.AssetInput memory asset) internal view {
    uint8 expected = ArcParameters.underlyingDecimals(asset.key);
    uint8 actual = IERC20Metadata(asset.underlying).decimals();

    require(
      actual == expected,
      UnexpectedDecimals(ArcParameters.symbol(asset.key), actual, expected)
    );
  }

  /// @notice Reverts if the AccessManager would defer a role grant or an admin action.
  /// @dev A non-zero role grant delay or target admin delay would make the self-grants take effect
  /// only after the delay, so every configuration call afterwards would revert.
  /// @param market The deployed Arc market.
  function requireNoDelays(ArcConfigInputs.Market memory market) internal view {
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
  /// @param market The deployed Arc market.
  /// @param deployer The address holding the AccessManager admin role.
  function grantConfigurationRoles(
    ArcConfigInputs.Market memory market,
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

  /// @notice Applies each spoke's dynamic liquidation bonus configuration.
  /// @dev Per spoke, not per reserve, so this runs once rather than per listed asset.
  /// @param market The deployed Arc market.
  function setLiquidationConfigs(ArcConfigInputs.Market memory market) internal {
    for (uint256 i; i < market.spokes.length; ++i) {
      ISpokeConfigurator(market.spokeConfigurator).updateLiquidationConfig(
        market.spokes[i],
        ArcParameters.liquidationConfig(ArcParameters.Spoke(i))
      );
    }
  }

  /// @notice Wires every deployed position manager and gateway to every spoke, both halves.
  /// @dev A manager is inert unless the Spoke has it active and the manager has the Spoke
  /// registered: `Spoke` checks `isPositionManagerActive`, the manager checks `onlyRegisteredSpoke`.
  ///
  /// Both halves run here. `updatePositionManager` needs the SpokeConfigurator domain admin role,
  /// which the deployer holds during configuration; `registerSpoke` is `onlyOwner` on the manager,
  /// which is why the Arc deploy script gives the deployer initial ownership of the managers and
  /// gateways rather than the Council. Ownership moves to the Council during the handover, leaving
  /// the Council nothing to do here beyond accepting it.
  /// @param market The deployed Arc market.
  /// @param deployer The address that owns the managers during configuration.
  function wirePositionManagers(ArcConfigInputs.Market memory market, address deployer) internal {
    address[4] memory managers = [
      market.giverPositionManager,
      market.takerPositionManager,
      market.configPositionManager,
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
  /// @param market The deployed Arc market.
  /// @param asset The asset to list.
  /// @return The Hub asset id of the listed asset.
  function listAssetOnHub(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset
  ) internal returns (uint256) {
    ArcParameters.AssetParams memory params = ArcParameters.assetParams(asset.key);

    IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy
      .InterestRateData({
        optimalUsageRatio: params.optimalUsageRatio,
        baseDrawnRate: params.baseDrawnRate,
        rateGrowthBeforeOptimal: params.rateGrowthBeforeOptimal,
        rateGrowthAfterOptimal: params.rateGrowthAfterOptimal
      });

    return
      IHubConfigurator(market.hubConfigurator).addAsset({
        hub: market.hub,
        underlying: asset.underlying,
        feeReceiver: market.treasurySpoke,
        liquidityFee: params.liquidityFee,
        irStrategy: market.irStrategy,
        irData: abi.encode(irData)
      });
  }

  /// @notice Registers the asset on every spoke the parameters list it on, and lists the reserve.
  /// @param market The deployed Arc market.
  /// @param asset The asset being listed.
  /// @param assetId The Hub asset id of that asset.
  function listAssetOnSpokes(
    ArcConfigInputs.Market memory market,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId
  ) internal {
    for (uint256 i; i < market.spokes.length; ++i) {
      ArcParameters.ReserveParams memory params = ArcParameters.reserveParams(
        asset.key,
        ArcParameters.Spoke(i)
      );
      if (!params.listed) continue;

      _addSpokeToAsset(market, market.spokes[i], assetId, params);
      _addReserve(market, market.spokes[i], asset, assetId, params);
    }
  }

  function _addSpokeToAsset(
    ArcConfigInputs.Market memory market,
    address spoke,
    uint256 assetId,
    ArcParameters.ReserveParams memory params
  ) private {
    uint256[] memory assetIds = new uint256[](1);
    assetIds[0] = assetId;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](1);
    configs[0] = IHub.SpokeConfig({
      addCap: params.addCap,
      drawCap: params.drawCap,
      riskPremiumThreshold: ArcParameters.RISK_PREMIUM_THRESHOLD,
      active: true,
      halted: false
    });

    IHubConfigurator(market.hubConfigurator).addSpokeToAssets({
      hub: market.hub,
      spoke: spoke,
      assetIds: assetIds,
      configs: configs
    });
  }

  function _addReserve(
    ArcConfigInputs.Market memory market,
    address spoke,
    ArcConfigInputs.AssetInput memory asset,
    uint256 assetId,
    ArcParameters.ReserveParams memory params
  ) private {
    ISpokeConfigurator(market.spokeConfigurator).addReserve({
      spoke: spoke,
      hub: market.hub,
      assetId: assetId,
      priceSource: asset.priceSource,
      config: ISpoke.ReserveConfig({
        collateralRisk: ArcParameters.COLLATERAL_RISK,
        paused: false,
        frozen: false,
        borrowable: params.borrowable,
        receiveSharesEnabled: ArcParameters.RECEIVE_SHARES_ENABLED
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: params.collateralFactor,
        maxLiquidationBonus: params.maxLiquidationBonus,
        liquidationFee: params.liquidationFee
      })
    });
  }
}
