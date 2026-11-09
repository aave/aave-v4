// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4BabylonConfig
/// @author Aave Labs
/// @notice Reads the Babylon market config and the deployment report it points to.
library AaveV4BabylonConfig {
  using SafeCast for uint256;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  string internal constant CONFIG_DIR = 'scripts/markets/babylon/config/';

  /// @dev chainId The chain the config is for.
  /// @dev salt The user-provided deploy salt.
  /// @dev librarySalt The CREATE2 salt of LiquidationLogic and BabylonLiquidationLogic.
  /// @dev deployer The account every step broadcasts from. Deployed addresses depend on it.
  /// @dev hubLabels The labels of the Babylon Hubs.
  /// @dev babylonSpokeLabel The label of the BabylonSpoke.
  /// @dev liquidationManager The only address allowed to liquidate on the BabylonSpoke.
  /// @dev liquidationManagerDeployer The CreateX deployer of the liquidation manager, zero if it is not
  /// checked.
  /// @dev liquidationManagerSalt The global salt the liquidation manager is deployed with through CreateX.
  /// @dev managedCollateralReserveId The identifier of the only reserve usable as collateral.
  /// @dev admin The address receiving every ownership at handover, and every role unless `authority` is set.
  /// @dev authority The AccessManager the Hubs and the BabylonSpoke move to at handover, zero to keep the
  /// deployed one.
  /// @dev feeReceiver The fee receiver of every listed asset, zero for the deployed TreasurySpoke.
  /// @dev report The deployment report written by the deploy script.
  struct Config {
    uint256 chainId;
    bytes32 salt;
    bytes32 librarySalt;
    address deployer;
    string[] hubLabels;
    string babylonSpokeLabel;
    address liquidationManager;
    address liquidationManagerDeployer;
    bytes32 liquidationManagerSalt;
    uint256 managedCollateralReserveId;
    address admin;
    address authority;
    address feeReceiver;
    string report;
  }

  /// @dev Addresses of the deployed Babylon market read from the deployment report.
  struct Deployment {
    address accessManager;
    address hubConfigurator;
    address spokeConfigurator;
    address treasurySpoke;
    address[] hubs;
    address[] hubImplementations;
    address[] irStrategies;
    address babylonSpoke;
    address babylonSpokeImplementation;
    address oracle;
  }

  /// @dev An asset listed on a Hub, connected to the BabylonSpoke and added as a BabylonSpoke reserve.
  /// @dev hub The Hub listing the asset.
  /// @dev irStrategy The interest rate strategy of the Hub.
  /// @dev underlying The underlying asset.
  /// @dev priceSource The price source of the reserve.
  /// @dev liquidityFee The liquidity fee of the asset, expressed in BPS.
  struct ReserveListing {
    address hub;
    address irStrategy;
    address underlying;
    address priceSource;
    uint16 liquidityFee;
    IAssetInterestRateStrategy.InterestRateData irData;
    IHub.SpokeConfig spokeConfig;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @dev A spoke deployed outside this market, connected to an asset a reserve listed on `hub`.
  /// @dev hub The Hub listing the asset.
  /// @dev underlying The underlying asset.
  /// @dev spoke The connected spoke.
  /// @dev spokeConfig The spoke config on the Hub asset.
  struct ExternalSpoke {
    address hub;
    address underlying;
    address spoke;
    IHub.SpokeConfig spokeConfig;
  }

  /// @dev A BabylonSpoke reserve on an asset of a Hub outside this market, added without connecting the
  /// BabylonSpoke on that Hub.
  /// @dev hub The Hub listing the asset.
  /// @dev underlying The underlying asset.
  /// @dev priceSource The price source of the reserve.
  struct ExternalReserve {
    address hub;
    address underlying;
    address priceSource;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @dev reserves The reserves on the market's Hubs, in BabylonSpoke reserve identifier order.
  /// @dev externalReserves The reserves on Hubs outside the market, in reserve identifier order after
  /// `reserves`.
  /// @dev externalSpokes The spokes connected to listed assets besides the BabylonSpoke.
  /// @dev liquidationConfig The BabylonSpoke liquidation config.
  struct MarketConfig {
    ReserveListing[] reserves;
    ExternalReserve[] externalReserves;
    ExternalSpoke[] externalSpokes;
    ISpoke.LiquidationConfig liquidationConfig;
  }

  /// @notice Returns the path of the config named by the `BABYLON_CONFIG` env variable.
  function path() internal view returns (string memory) {
    return path(vm.envString('BABYLON_CONFIG'));
  }

  /// @notice Returns the path of the config named `name`.
  function path(string memory name) internal pure returns (string memory) {
    return string.concat(CONFIG_DIR, name, '.json');
  }

  /// @notice Reads the config named by the `BABYLON_CONFIG` env variable.
  function read() internal view returns (Config memory) {
    return read(vm.envString('BABYLON_CONFIG'));
  }

  /// @notice Reads the config named `name`.
  /// @dev Reverts unless the config is for the current chain.
  function read(string memory name) internal view returns (Config memory) {
    Config memory config = parse(vm.readFile(path(name)));
    require(config.chainId == block.chainid, 'config chain id mismatch');
    return config;
  }

  /// @notice Parses a config JSON.
  /// @param json The config JSON.
  function parse(string memory json) internal pure returns (Config memory) {
    return
      Config({
        chainId: vm.parseJsonUint(json, '.chainId'),
        salt: vm.parseJsonBytes32(json, '.salt'),
        librarySalt: vm.parseJsonBytes32(json, '.librarySalt'),
        deployer: vm.parseJsonAddress(json, '.deployer'),
        hubLabels: vm.parseJsonStringArray(json, '.hubLabels'),
        babylonSpokeLabel: vm.parseJsonString(json, '.babylonSpokeLabel'),
        liquidationManager: vm.parseJsonAddress(json, '.liquidationManager'),
        liquidationManagerDeployer: vm.parseJsonAddress(json, '.liquidationManagerDeployer'),
        liquidationManagerSalt: vm.parseJsonBytes32(json, '.liquidationManagerSalt'),
        managedCollateralReserveId: vm.parseJsonUint(json, '.managedCollateralReserveId'),
        admin: vm.parseJsonAddress(json, '.admin'),
        authority: vm.parseJsonAddress(json, '.authority'),
        feeReceiver: vm.parseJsonAddress(json, '.feeReceiver'),
        report: vm.parseJsonString(json, '.report')
      });
  }

  /// @notice Reverts unless `broadcaster` is the config's deployer.
  /// @param config The Babylon market config.
  /// @param broadcaster The account the script broadcasts from.
  function requireDeployer(Config memory config, address broadcaster) internal pure {
    require(broadcaster == config.deployer, 'broadcaster is not the config deployer');
  }

  /// @notice Returns the fee receiver of every listed asset.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function feeReceiver(
    Config memory config,
    Deployment memory deployment
  ) internal pure returns (address) {
    return config.feeReceiver == address(0) ? deployment.treasurySpoke : config.feeReceiver;
  }

  /// @notice Returns the owner of the deployed TreasurySpoke and its ProxyAdmin after the handover.
  /// @dev With a configured fee receiver the deployed TreasurySpoke is unused and stays with the deployer.
  /// @param config The Babylon market config.
  function treasurySpokeOwner(Config memory config) internal pure returns (address) {
    return config.feeReceiver == address(0) ? config.admin : config.deployer;
  }

  /// @notice Returns the AccessManager of the Hubs and the BabylonSpoke after the handover.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function finalAuthority(
    Config memory config,
    Deployment memory deployment
  ) internal pure returns (address) {
    return config.authority == address(0) ? deployment.accessManager : config.authority;
  }

  /// @notice Builds the deploy inputs: the Hubs and one BabylonSpoke, roles deferred to the handover.
  /// @param config The Babylon market config.
  function deployInputs(
    Config memory config
  ) internal pure returns (InputUtils.FullDeployInputs memory) {
    string[] memory babylonSpokeLabels = new string[](1);
    babylonSpokeLabels[0] = config.babylonSpokeLabel;
    address[] memory babylonLiquidationManagers = new address[](1);
    babylonLiquidationManagers[0] = config.liquidationManager;
    uint256[] memory babylonManagedCollateralReserveIds = new uint256[](1);
    babylonManagedCollateralReserveIds[0] = config.managedCollateralReserveId;

    return
      InputUtils.FullDeployInputs({
        accessManagerAdmin: address(0),
        proxyAdminOwner: address(0),
        hubAdmin: address(0),
        hubConfiguratorAdmin: address(0),
        treasurySpokeOwner: address(0),
        spokeAdmin: address(0),
        spokeConfiguratorAdmin: address(0),
        gatewayOwner: address(0),
        positionManagerOwner: address(0),
        nativeWrapper: address(0),
        deployNativeTokenGateway: false,
        deploySignatureGateway: false,
        deployPositionManagers: false,
        grantRoles: false,
        hubLabels: config.hubLabels,
        spokeLabels: new string[](0),
        spokeMaxReservesLimits: new uint16[](0),
        babylonSpokeLabels: babylonSpokeLabels,
        babylonLiquidationManagers: babylonLiquidationManagers,
        babylonManagedCollateralReserveIds: babylonManagedCollateralReserveIds,
        salt: config.salt
      });
  }

  /// @notice Reads the deployed addresses from the deployment report.
  /// @param config The Babylon market config.
  function readDeployment(Config memory config) internal view returns (Deployment memory) {
    string memory json = vm.readFile(config.report);
    address[] memory hubs = new address[](config.hubLabels.length);
    address[] memory hubImplementations = new address[](config.hubLabels.length);
    address[] memory irStrategies = new address[](config.hubLabels.length);
    for (uint256 i; i < hubs.length; ++i) {
      hubs[i] = vm.parseJsonAddress(json, string.concat('.hub.', config.hubLabels[i]));
      hubImplementations[i] = vm.parseJsonAddress(
        json,
        string.concat('.hubImplementation.', config.hubLabels[i])
      );
      irStrategies[i] = vm.parseJsonAddress(
        json,
        string.concat('.irStrategy.', config.hubLabels[i])
      );
    }
    return
      Deployment({
        accessManager: vm.parseJsonAddress(json, '.accessManager'),
        hubConfigurator: vm.parseJsonAddress(json, '.hubConfigurator'),
        spokeConfigurator: vm.parseJsonAddress(json, '.spokeConfigurator'),
        treasurySpoke: vm.parseJsonAddress(json, '.treasurySpoke'),
        hubs: hubs,
        hubImplementations: hubImplementations,
        irStrategies: irStrategies,
        babylonSpoke: vm.parseJsonAddress(
          json,
          string.concat('.babylonSpoke.', config.babylonSpokeLabel)
        ),
        babylonSpokeImplementation: vm.parseJsonAddress(
          json,
          string.concat('.babylonSpokeImplementation.', config.babylonSpokeLabel)
        ),
        oracle: vm.parseJsonAddress(json, string.concat('.oracle.', config.babylonSpokeLabel))
      });
  }

  /// @notice Reads the market config for the current chain.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function readMarketConfig(
    Config memory config,
    Deployment memory deployment
  ) internal view returns (MarketConfig memory) {
    return parseMarketConfig({json: vm.readFile(path()), config: config, deployment: deployment});
  }

  /// @notice Reads the external spokes of the config named by the `BABYLON_CONFIG` env variable.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function readExternalSpokes(
    Config memory config,
    Deployment memory deployment
  ) internal view returns (ExternalSpoke[] memory) {
    return parseExternalSpokes({json: vm.readFile(path()), config: config, deployment: deployment});
  }

  /// @notice Parses the optional `externalSpokes` of a config JSON.
  /// @param json The config JSON.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function parseExternalSpokes(
    string memory json,
    Config memory config,
    Deployment memory deployment
  ) internal view returns (ExternalSpoke[] memory) {
    uint256 count;
    while (vm.keyExistsJson(json, string.concat('.externalSpokes[', vm.toString(count), ']'))) {
      ++count;
    }
    ExternalSpoke[] memory externalSpokes = new ExternalSpoke[](count);
    for (uint256 i; i < count; ++i) {
      string memory key = string.concat('.externalSpokes[', vm.toString(i), ']');
      externalSpokes[i] = ExternalSpoke({
        hub: deployment.hubs[
          _hubIndex(config, vm.parseJsonString(json, string.concat(key, '.hub')))
        ],
        underlying: vm.parseJsonAddress(json, string.concat(key, '.underlying')),
        spoke: vm.parseJsonAddress(json, string.concat(key, '.spoke')),
        spokeConfig: _spokeConfig(json, key)
      });
      require(
        externalSpokes[i].underlying != address(0) && externalSpokes[i].spoke != address(0),
        'external spoke address unset'
      );
    }
    return externalSpokes;
  }

  /// @notice Parses the market config from a config JSON, resolving Hub labels against the deployment.
  /// @param json The config JSON.
  /// @param config The Babylon market config.
  /// @param deployment The deployed Babylon market.
  function parseMarketConfig(
    string memory json,
    Config memory config,
    Deployment memory deployment
  ) internal view returns (MarketConfig memory) {
    uint256 count;
    while (vm.keyExistsJson(json, string.concat('.reserves[', vm.toString(count), ']'))) {
      ++count;
    }
    ReserveListing[] memory reserves = new ReserveListing[](count);
    for (uint256 i; i < count; ++i) {
      string memory key = string.concat('.reserves[', vm.toString(i), ']');
      uint256 hubIndex = _hubIndex(config, vm.parseJsonString(json, string.concat(key, '.hub')));
      reserves[i] = ReserveListing({
        hub: deployment.hubs[hubIndex],
        irStrategy: deployment.irStrategies[hubIndex],
        underlying: vm.parseJsonAddress(json, string.concat(key, '.underlying')),
        priceSource: vm.parseJsonAddress(json, string.concat(key, '.priceSource')),
        liquidityFee: _uint(json, key, '.liquidityFee').toUint16(),
        irData: IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: _uint(json, key, '.irData.optimalUsageRatio').toUint16(),
          baseDrawnRate: _uint(json, key, '.irData.baseDrawnRate').toUint32(),
          rateGrowthBeforeOptimal: _uint(json, key, '.irData.rateGrowthBeforeOptimal').toUint32(),
          rateGrowthAfterOptimal: _uint(json, key, '.irData.rateGrowthAfterOptimal').toUint32()
        }),
        spokeConfig: _spokeConfig(json, key),
        reserveConfig: _reserveConfig(json, key),
        dynamicConfig: _dynamicConfig(json, key)
      });
      require(
        reserves[i].underlying != address(0) && reserves[i].priceSource != address(0),
        'reserve address unset'
      );
    }
    return
      MarketConfig({
        reserves: reserves,
        externalReserves: parseExternalReserves(json),
        externalSpokes: parseExternalSpokes({json: json, config: config, deployment: deployment}),
        liquidationConfig: ISpoke.LiquidationConfig({
          targetHealthFactor: _uint(json, '.liquidationConfig', '.targetHealthFactor').toUint128(),
          healthFactorForMaxBonus: _uint(json, '.liquidationConfig', '.healthFactorForMaxBonus')
            .toUint64(),
          liquidationBonusFactor: _uint(json, '.liquidationConfig', '.liquidationBonusFactor')
            .toUint16()
        })
      });
  }

  /// @notice Parses the optional `externalReserves` of a config JSON.
  /// @param json The config JSON.
  function parseExternalReserves(
    string memory json
  ) internal view returns (ExternalReserve[] memory) {
    uint256 count;
    while (vm.keyExistsJson(json, string.concat('.externalReserves[', vm.toString(count), ']'))) {
      ++count;
    }
    ExternalReserve[] memory externalReserves = new ExternalReserve[](count);
    for (uint256 i; i < count; ++i) {
      string memory key = string.concat('.externalReserves[', vm.toString(i), ']');
      externalReserves[i] = ExternalReserve({
        hub: vm.parseJsonAddress(json, string.concat(key, '.hub')),
        underlying: vm.parseJsonAddress(json, string.concat(key, '.underlying')),
        priceSource: vm.parseJsonAddress(json, string.concat(key, '.priceSource')),
        reserveConfig: _reserveConfig(json, key),
        dynamicConfig: _dynamicConfig(json, key)
      });
      require(
        externalReserves[i].hub != address(0) &&
          externalReserves[i].underlying != address(0) &&
          externalReserves[i].priceSource != address(0),
        'external reserve address unset'
      );
    }
    return externalReserves;
  }

  function _reserveConfig(
    string memory json,
    string memory key
  ) private pure returns (ISpoke.ReserveConfig memory) {
    return
      ISpoke.ReserveConfig({
        collateralRisk: _uint(json, key, '.reserveConfig.collateralRisk').toUint24(),
        paused: _bool(json, key, '.reserveConfig.paused'),
        frozen: _bool(json, key, '.reserveConfig.frozen'),
        borrowable: _bool(json, key, '.reserveConfig.borrowable'),
        receiveSharesEnabled: _bool(json, key, '.reserveConfig.receiveSharesEnabled')
      });
  }

  function _dynamicConfig(
    string memory json,
    string memory key
  ) private pure returns (ISpoke.DynamicReserveConfig memory) {
    return
      ISpoke.DynamicReserveConfig({
        collateralFactor: _uint(json, key, '.dynamicConfig.collateralFactor').toUint16(),
        maxLiquidationBonus: _uint(json, key, '.dynamicConfig.maxLiquidationBonus').toUint32(),
        liquidationFee: _uint(json, key, '.dynamicConfig.liquidationFee').toUint16()
      });
  }

  function _spokeConfig(
    string memory json,
    string memory key
  ) private pure returns (IHub.SpokeConfig memory) {
    return
      IHub.SpokeConfig({
        addCap: _uint(json, key, '.spokeConfig.addCap').toUint40(),
        drawCap: _uint(json, key, '.spokeConfig.drawCap').toUint40(),
        riskPremiumThreshold: _uint(json, key, '.spokeConfig.riskPremiumThreshold').toUint24(),
        active: _bool(json, key, '.spokeConfig.active'),
        halted: _bool(json, key, '.spokeConfig.halted')
      });
  }

  function _hubIndex(Config memory config, string memory label) private pure returns (uint256) {
    for (uint256 i; i < config.hubLabels.length; ++i) {
      if (keccak256(bytes(config.hubLabels[i])) == keccak256(bytes(label))) {
        return i;
      }
    }
    revert(string.concat('unknown hub label: ', label));
  }

  function _uint(
    string memory json,
    string memory key,
    string memory field
  ) private pure returns (uint256) {
    return vm.parseJsonUint(json, string.concat(key, field));
  }

  function _bool(
    string memory json,
    string memory key,
    string memory field
  ) private pure returns (bool) {
    return vm.parseJsonBool(json, string.concat(key, field));
  }
}
