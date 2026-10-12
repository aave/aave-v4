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

  uint256 internal constant SEPOLIA_CHAIN_ID = 11155111;

  /// @dev salt The user-provided deploy salt.
  /// @dev hubLabels The labels of the Babylon Hubs.
  /// @dev babylonSpokeLabel The label of the BabylonSpoke.
  /// @dev liquidationManager The only address allowed to liquidate on the BabylonSpoke.
  /// @dev managedCollateralReserveId The identifier of the only reserve usable as collateral.
  /// @dev admin The address receiving every role and ownership at handover.
  /// @dev report The deployment report written by the deploy script.
  struct Config {
    bytes32 salt;
    string[] hubLabels;
    string babylonSpokeLabel;
    address liquidationManager;
    uint256 managedCollateralReserveId;
    address admin;
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

  /// @dev reserves The reserves in BabylonSpoke reserve identifier order.
  /// @dev liquidationConfig The BabylonSpoke liquidation config.
  struct MarketConfig {
    ReserveListing[] reserves;
    ISpoke.LiquidationConfig liquidationConfig;
  }

  /// @notice Returns the config file path for the current chain.
  function path() internal view returns (string memory) {
    if (block.chainid == SEPOLIA_CHAIN_ID) {
      return 'scripts/markets/babylon/sepolia.json';
    }
    revert('unsupported chain');
  }

  /// @notice Reads the config for the current chain.
  function read() internal view returns (Config memory) {
    return parse(vm.readFile(path()));
  }

  /// @notice Parses a config JSON.
  /// @param json The config JSON.
  function parse(string memory json) internal pure returns (Config memory) {
    return
      Config({
        salt: vm.parseJsonBytes32(json, '.salt'),
        hubLabels: vm.parseJsonStringArray(json, '.hubLabels'),
        babylonSpokeLabel: vm.parseJsonString(json, '.babylonSpokeLabel'),
        liquidationManager: vm.parseJsonAddress(json, '.liquidationManager'),
        managedCollateralReserveId: vm.parseJsonUint(json, '.managedCollateralReserveId'),
        admin: vm.parseJsonAddress(json, '.admin'),
        report: vm.parseJsonString(json, '.report')
      });
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
        spokeConfig: IHub.SpokeConfig({
          addCap: _uint(json, key, '.spokeConfig.addCap').toUint40(),
          drawCap: _uint(json, key, '.spokeConfig.drawCap').toUint40(),
          riskPremiumThreshold: _uint(json, key, '.spokeConfig.riskPremiumThreshold').toUint24(),
          active: _bool(json, key, '.spokeConfig.active'),
          halted: _bool(json, key, '.spokeConfig.halted')
        }),
        reserveConfig: ISpoke.ReserveConfig({
          collateralRisk: _uint(json, key, '.reserveConfig.collateralRisk').toUint24(),
          paused: _bool(json, key, '.reserveConfig.paused'),
          frozen: _bool(json, key, '.reserveConfig.frozen'),
          borrowable: _bool(json, key, '.reserveConfig.borrowable'),
          receiveSharesEnabled: _bool(json, key, '.reserveConfig.receiveSharesEnabled')
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: _uint(json, key, '.dynamicConfig.collateralFactor').toUint16(),
          maxLiquidationBonus: _uint(json, key, '.dynamicConfig.maxLiquidationBonus').toUint32(),
          liquidationFee: _uint(json, key, '.dynamicConfig.liquidationFee').toUint16()
        })
      });
    }
    return
      MarketConfig({
        reserves: reserves,
        liquidationConfig: ISpoke.LiquidationConfig({
          targetHealthFactor: _uint(json, '.liquidationConfig', '.targetHealthFactor').toUint128(),
          healthFactorForMaxBonus: _uint(json, '.liquidationConfig', '.healthFactorForMaxBonus')
            .toUint64(),
          liquidationBonusFactor: _uint(json, '.liquidationConfig', '.liquidationBonusFactor')
            .toUint16()
        })
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
