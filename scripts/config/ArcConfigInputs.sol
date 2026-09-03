// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcParameters} from 'scripts/config/ArcParameters.sol';

import {Vm} from 'forge-std/Vm.sol';

/// @title ArcConfigInputs
/// @author Aave Labs
/// @notice Reads the inputs shared by the Arc configuration and handover scripts: the addresses of
/// a deployed Arc market, the handover targets, and the asset to configure.
library ArcConfigInputs {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @dev Deploy inputs, which also carry the handover targets.
  string internal constant DEPLOY_CONFIG_PATH = 'scripts/config/arc.json';
  /// @dev Configuration inputs.
  string internal constant CONFIG_PATH = 'scripts/config/arc-config.json';
  /// @dev ERC-1967 admin slot, holding the ProxyAdmin address of a transparent proxy.
  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /// @notice Addresses of a deployed Arc market, read back from its deployment report.
  /// @dev spokes Spoke proxies, in the order the spoke labels are declared in the deploy inputs.
  struct Market {
    address accessManager;
    address hubConfigurator;
    address spokeConfigurator;
    address treasurySpoke;
    address hub;
    address irStrategy;
    address[] spokes;
    address signatureGateway;
    address giverPositionManager;
    address takerPositionManager;
    address configPositionManager;
  }

  /// @notice The addresses the deployer hands the market over to.
  /// @dev hubConfiguratorAdmin and spokeConfiguratorAdmin hold the domain admin roles, so they must
  /// be the address that executes configuration payloads, not the Safe that owns it.
  struct Handover {
    address accessManagerAdmin;
    address hubAdmin;
    address hubConfiguratorAdmin;
    address spokeAdmin;
    address spokeConfiguratorAdmin;
    address proxyAdminOwner;
    address treasurySpokeOwner;
    address gatewayOwner;
    address positionManagerOwner;
  }

  /// @notice An asset in the launch set, with the two addresses configuration needs.
  /// @dev key Selects the asset's row in `ArcParameters`.
  /// @dev underlying The underlying token.
  /// @dev priceSource The price feed.
  struct AssetInput {
    ArcParameters.Asset key;
    address underlying;
    address priceSource;
  }

  /// @notice Thrown when the deploy inputs declare anything other than a single Hub.
  error SingleHubExpected();
  /// @notice Thrown when an address has no code, which every configuration call on it would
  /// revert on.
  error NotAContract(string field);
  /// @notice Thrown when no asset has both addresses resolved, leaving nothing to configure.
  error EmptyLaunchSet();
  /// @notice Thrown when the deployer is not recorded in the configuration inputs.
  error DeployerNotSet();

  /// @notice Reads the deployed market addresses from the report named in the configuration inputs.
  /// @return market The addresses of the deployed Arc market.
  function readMarket() internal view returns (Market memory market) {
    string memory deployJson = vm.readFile(DEPLOY_CONFIG_PATH);
    string memory report = vm.readFile(vm.parseJsonString(vm.readFile(CONFIG_PATH), '.report'));

    string[] memory hubLabels = vm.parseJsonStringArray(deployJson, '.hubLabels');
    require(hubLabels.length == 1, SingleHubExpected());
    string[] memory spokeLabels = vm.parseJsonStringArray(deployJson, '.spokeLabels');

    market.accessManager = vm.parseJsonAddress(report, '$.accessManager');
    market.hubConfigurator = vm.parseJsonAddress(report, '$.hubConfigurator');
    market.spokeConfigurator = vm.parseJsonAddress(report, '$.spokeConfigurator');
    market.treasurySpoke = vm.parseJsonAddress(report, '$.treasurySpoke');
    market.hub = vm.parseJsonAddress(report, string.concat('$.hub.', hubLabels[0]));
    market.irStrategy = vm.parseJsonAddress(report, string.concat('$.irStrategy.', hubLabels[0]));

    market.spokes = new address[](spokeLabels.length);
    for (uint256 i; i < spokeLabels.length; ++i) {
      market.spokes[i] = vm.parseJsonAddress(report, string.concat('$.spoke.', spokeLabels[i]));
    }

    market.signatureGateway = _optionalAddress(report, '$.signatureGateway');
    market.giverPositionManager = _optionalAddress(report, '$.giverPositionManager');
    market.takerPositionManager = _optionalAddress(report, '$.takerPositionManager');
    market.configPositionManager = _optionalAddress(report, '$.configPositionManager');
  }

  /// @notice Reads the handover targets from the deploy inputs.
  /// @dev These fields are unused at deploy time while `grantRoles` is false, and are applied by
  /// the handover script instead.
  /// @return handover The addresses to hand the market over to.
  function readHandover() internal view returns (Handover memory handover) {
    string memory json = vm.readFile(DEPLOY_CONFIG_PATH);

    handover.accessManagerAdmin = vm.parseJsonAddress(json, '.accessManagerAdmin');
    handover.hubAdmin = vm.parseJsonAddress(json, '.hubAdmin');
    handover.hubConfiguratorAdmin = vm.parseJsonAddress(json, '.hubConfiguratorAdmin');
    handover.spokeAdmin = vm.parseJsonAddress(json, '.spokeAdmin');
    handover.spokeConfiguratorAdmin = vm.parseJsonAddress(json, '.spokeConfiguratorAdmin');
    handover.proxyAdminOwner = vm.parseJsonAddress(json, '.proxyAdminOwner');
    handover.treasurySpokeOwner = vm.parseJsonAddress(json, '.treasurySpokeOwner');
    handover.gatewayOwner = vm.parseJsonAddress(json, '.gatewayOwner');
    handover.positionManagerOwner = vm.parseJsonAddress(json, '.positionManagerOwner');
  }

  /// @notice Reads the launch set: every asset in `ArcParameters` whose underlying and price source
  /// are both filled in.
  /// @dev An asset with either address left at zero is skipped, so the launch set is whatever the
  /// operator has resolved rather than an assumption baked into the scripts. Both addresses must be
  /// live contracts: `HubConfigurator.addAsset` reads `decimals()` off the underlying, and
  /// `AaveOracle.setReserveSource` checks the price source decimals and reads a price from it.
  /// @return assets The assets to configure.
  function readAssets() internal view returns (AssetInput[] memory assets) {
    string memory json = vm.readFile(CONFIG_PATH);

    uint256 count;
    AssetInput[] memory resolved = new AssetInput[](ArcParameters.assetCount());

    for (uint256 i; i < ArcParameters.assetCount(); ++i) {
      ArcParameters.Asset key = ArcParameters.Asset(i);
      string memory path = string.concat('.assets.', ArcParameters.symbol(key));

      address underlying = vm.parseJsonAddress(json, string.concat(path, '.underlying'));
      address priceSource = vm.parseJsonAddress(json, string.concat(path, '.priceSource'));
      if (underlying == address(0) || priceSource == address(0)) continue;

      require(
        underlying.code.length > 0,
        NotAContract(string.concat(ArcParameters.symbol(key), ' underlying'))
      );
      require(
        priceSource.code.length > 0,
        NotAContract(string.concat(ArcParameters.symbol(key), ' price source'))
      );

      resolved[count++] = AssetInput({key: key, underlying: underlying, priceSource: priceSource});
    }

    require(count > 0, EmptyLaunchSet());

    assets = new AssetInput[](count);
    for (uint256 i; i < count; ++i) {
      assets[i] = resolved[i];
    }
  }

  /// @notice Reads the address that ran the deployment and configuration.
  /// @dev Needed to assert it holds nothing after the handover. The deployment report does not
  /// record it, so it is configured explicitly.
  /// @return deployer The deploying address.
  function readDeployer() internal view returns (address deployer) {
    deployer = vm.parseJsonAddress(vm.readFile(CONFIG_PATH), '.deployer');
    require(deployer != address(0), DeployerNotSet());
  }

  /// @notice Returns the ProxyAdmin of a transparent proxy.
  /// @param proxy The proxy to read.
  /// @return The ProxyAdmin address.
  function proxyAdmin(address proxy) internal view returns (address) {
    return address(uint160(uint256(vm.load(proxy, ERC1967_ADMIN_SLOT))));
  }

  function _optionalAddress(string memory json, string memory key) private view returns (address) {
    return vm.keyExistsJson(json, key) ? vm.parseJsonAddress(json, key) : address(0);
  }
}
