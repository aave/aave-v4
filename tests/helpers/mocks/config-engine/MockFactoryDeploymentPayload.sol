// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @dev Deploys a Hub, `SPOKE_COUNT` Spokes and a TreasurySpoke through the factory, then wires them in the
/// same payload: target function roles, an asset listing with tokenization on the new Hub (fee receiver is the new
/// TreasurySpoke), and the asset added to and listed on every new Spoke. Later actions use the addresses predicted
/// with `address(this)`, the Executor, as deployer.
contract MockFactoryDeploymentPayload is AaveV4Payload {
  IHubSpokeFactory internal immutable FACTORY;
  IHubConfigurator internal immutable HUB_CONFIGURATOR;
  ISpokeConfigurator internal immutable SPOKE_CONFIGURATOR;
  address internal immutable AUTHORITY;
  address internal immutable UNDERLYING;
  address internal immutable PRICE_SOURCE;
  address internal immutable PROXY_ADMIN_OWNER;
  uint256 internal immutable SPOKE_COUNT;

  bytes32 internal constant HUB_SALT = 'hub';
  bytes32 internal constant TREASURY_SPOKE_SALT = 'treasury-spoke';
  uint16 internal constant MAX_USER_RESERVES_LIMIT = type(uint16).max;

  constructor(
    IAaveV4ConfigEngine configEngine,
    IHubConfigurator hubConfigurator,
    ISpokeConfigurator spokeConfigurator,
    address authority,
    address underlying,
    address priceSource,
    address proxyAdminOwner,
    uint256 spokeCount
  ) AaveV4Payload(configEngine) {
    FACTORY = configEngine.FACTORY();
    HUB_CONFIGURATOR = hubConfigurator;
    SPOKE_CONFIGURATOR = spokeConfigurator;
    AUTHORITY = authority;
    UNDERLYING = underlying;
    PRICE_SOURCE = priceSource;
    PROXY_ADMIN_OWNER = proxyAdminOwner;
    SPOKE_COUNT = spokeCount;
  }

  function predictedHub(
    address deployer
  ) public view returns (IHubSpokeFactory.HubDeployment memory) {
    return FACTORY.predictHub(deployer, HUB_SALT, AUTHORITY, PROXY_ADMIN_OWNER);
  }

  function predictedSpoke(address deployer, uint256 i) public view returns (address) {
    return
      FACTORY
        .predictSpoke(deployer, bytes32(i), AUTHORITY, MAX_USER_RESERVES_LIMIT, PROXY_ADMIN_OWNER)
        .proxy;
  }

  function predictedTreasurySpoke(address deployer) public view returns (address) {
    return
      FACTORY.predictTreasurySpoke(
        deployer,
        TREASURY_SPOKE_SALT,
        PROXY_ADMIN_OWNER,
        PROXY_ADMIN_OWNER
      );
  }

  function hubDeployments()
    public
    view
    override
    returns (IAaveV4ConfigEngine.HubDeployment[] memory deployments)
  {
    deployments = new IAaveV4ConfigEngine.HubDeployment[](1);
    deployments[0] = IAaveV4ConfigEngine.HubDeployment({
      salt: HUB_SALT,
      authority: AUTHORITY,
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });
  }

  function spokeDeployments()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeDeployment[] memory deployments)
  {
    deployments = new IAaveV4ConfigEngine.SpokeDeployment[](SPOKE_COUNT);
    for (uint256 i; i < SPOKE_COUNT; ++i) {
      deployments[i] = IAaveV4ConfigEngine.SpokeDeployment({
        salt: bytes32(i),
        authority: AUTHORITY,
        maxUserReservesLimit: MAX_USER_RESERVES_LIMIT,
        proxyAdminOwner: PROXY_ADMIN_OWNER
      });
    }
  }

  function treasurySpokeDeployments()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TreasurySpokeDeployment[] memory deployments)
  {
    deployments = new IAaveV4ConfigEngine.TreasurySpokeDeployment[](1);
    deployments[0] = IAaveV4ConfigEngine.TreasurySpokeDeployment({
      salt: TREASURY_SPOKE_SALT,
      owner: PROXY_ADMIN_OWNER,
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });
  }

  function accessManagerTargetFunctionRoleUpdates()
    public
    view
    override
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory updates)
  {
    updates = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1 + SPOKE_COUNT);
    updates[0] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
      authority: AUTHORITY,
      target: predictedHub(address(this)).proxy,
      selectors: Roles.getHubConfiguratorRoleSelectors(),
      roleId: Roles.HUB_CONFIGURATOR_ROLE
    });
    for (uint256 i; i < SPOKE_COUNT; ++i) {
      updates[1 + i] = IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
        authority: AUTHORITY,
        target: predictedSpoke(address(this), i),
        selectors: Roles.getSpokeConfiguratorRoleSelectors(),
        roleId: Roles.SPOKE_CONFIGURATOR_ROLE
      });
    }
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory listings)
  {
    IHubSpokeFactory.HubDeployment memory hub = predictedHub(address(this));
    listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4ConfigEngine.AssetListing({
      hubConfigurator: HUB_CONFIGURATOR,
      hub: hub.proxy,
      underlying: UNDERLYING,
      feeReceiver: predictedTreasurySpoke(address(this)),
      liquidityFee: 5_00,
      irStrategy: hub.irStrategy,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00,
        baseDrawnRate: 1_00,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 60_00
      }),
      tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
        addCap: 1000,
        proxyAdminOwner: PROXY_ADMIN_OWNER,
        name: 'Tokenized NEW',
        symbol: 'tNEW'
      })
    });
  }

  function hubSpokeToAssetsAdditions()
    public
    view
    override
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory additions)
  {
    address hub = predictedHub(address(this)).proxy;
    additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](SPOKE_COUNT);
    for (uint256 i; i < SPOKE_COUNT; ++i) {
      IAaveV4ConfigEngine.SpokeAssetConfig[]
        memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](1);
      assets[0] = IAaveV4ConfigEngine.SpokeAssetConfig({
        underlying: UNDERLYING,
        config: IHub.SpokeConfig({
          addCap: type(uint40).max,
          drawCap: type(uint40).max,
          riskPremiumThreshold: 100_00,
          active: true,
          halted: false
        })
      });
      additions[i] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
        hubConfigurator: HUB_CONFIGURATOR,
        hub: hub,
        spoke: predictedSpoke(address(this), i),
        assets: assets
      });
    }
  }

  function spokeReserveListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.ReserveListing[] memory listings)
  {
    address hub = predictedHub(address(this)).proxy;
    listings = new IAaveV4ConfigEngine.ReserveListing[](SPOKE_COUNT);
    for (uint256 i; i < SPOKE_COUNT; ++i) {
      listings[i] = IAaveV4ConfigEngine.ReserveListing({
        spokeConfigurator: SPOKE_CONFIGURATOR,
        spoke: predictedSpoke(address(this), i),
        hub: hub,
        underlying: UNDERLYING,
        priceSource: PRICE_SOURCE,
        config: ISpoke.ReserveConfig({
          collateralRisk: 15_00,
          paused: false,
          frozen: false,
          borrowable: true,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 80_00,
          maxLiquidationBonus: 105_00,
          liquidationFee: 10_00
        })
      });
    }
  }
}
