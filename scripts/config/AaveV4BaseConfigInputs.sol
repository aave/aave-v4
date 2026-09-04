// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';

/// @title AaveV4BaseConfigInputs
/// @author Aave Labs
/// @notice Reads the inputs shared by the Base configuration and handover scripts: the addresses of
/// a deployed Base market, the handover targets, and the assets to list.
library AaveV4BaseConfigInputs {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @dev Deploy inputs, which also carry the handover targets.
  string internal constant DEPLOY_CONFIG_PATH = 'config/base.json';
  /// @dev Configuration inputs.
  string internal constant CONFIG_PATH = 'config/base-config.json';
  /// @dev ERC-1967 admin slot, holding the ProxyAdmin address of a transparent proxy.
  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /// @notice Addresses of a deployed Base market, read back from its deployment report.
  /// @dev spokes Spoke proxies, in the order the spoke labels are declared in the deploy inputs.
  struct Market {
    address accessManager;
    address hubConfigurator;
    address spokeConfigurator;
    address treasurySpoke;
    address hub;
    address irStrategy;
    address[] spokes;
    address nativeTokenGateway;
    address signatureGateway;
    address giverPositionManager;
    address takerPositionManager;
    address configPositionManager;
  }

  /// @notice The addresses the deployer hands the market over to.
  /// @dev `securityCouncil` owns the market and admins the AccessManager. `councilExecutor` holds
  /// the two configurator domain admin roles, so it must be the address that executes configuration
  /// payloads rather than the Safe that owns it. `governanceExecutor` is the DAO's own executor,
  /// which co-holds the AccessManager admin role and the Hub configurator domain admin role.
  struct Handover {
    address securityCouncil;
    address councilExecutor;
    address governanceExecutor;
    address proxyAdminOwner;
    address treasurySpokeOwner;
    address gatewayOwner;
    address positionManagerOwner;
  }

  /// @notice An asset to list, with the price feed its Spoke reserves read it through.
  /// @dev tokenize Whether a tokenization spoke is deployed for the asset and registered on the Hub.
  struct Asset {
    string symbol;
    address underlying;
    address priceSource;
    bool tokenize;
  }

  /// @notice Thrown when the deploy inputs declare anything other than a single Hub.
  error SingleHubExpected();
  /// @notice Thrown when an asset or its price source is left unset in the configuration inputs.
  error AddressNotSet(string symbol, string field);
  /// @notice Thrown when an asset or its price source has no code, which every configuration call
  /// on it would revert on.
  error NotAContract(string symbol, string field);
  /// @notice Thrown when the deployer is not recorded in the configuration inputs.
  error DeployerNotSet();

  /// @notice Reads the deployed market addresses from the report named in the configuration inputs.
  /// @return market The addresses of the deployed Base market.
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

    market.nativeTokenGateway = _optionalAddress(report, '$.nativeTokenGateway');
    market.signatureGateway = _optionalAddress(report, '$.signatureGateway');
    market.giverPositionManager = _optionalAddress(report, '$.giverPositionManager');
    market.takerPositionManager = _optionalAddress(report, '$.takerPositionManager');
    market.configPositionManager = _optionalAddress(report, '$.configPositionManager');
  }

  /// @notice Reads the handover targets from the deploy inputs.
  /// @dev The role fields are unused at deploy time while `grantRoles` is false, and are applied by
  /// the handover script instead. `hubAdmin` and `spokeAdmin` are deliberately not read: the Hub and
  /// Spoke roles they would fill are left unheld, matching the live Ethereum and Avalanche markets.
  /// @return handover The addresses to hand the market over to.
  function readHandover() internal view returns (Handover memory handover) {
    string memory json = vm.readFile(DEPLOY_CONFIG_PATH);

    handover.securityCouncil = vm.parseJsonAddress(json, '.accessManagerAdmin');
    handover.councilExecutor = vm.parseJsonAddress(json, '.hubConfiguratorAdmin');
    handover.governanceExecutor = vm.parseJsonAddress(json, '.governanceExecutor');
    handover.proxyAdminOwner = vm.parseJsonAddress(json, '.proxyAdminOwner');
    handover.treasurySpokeOwner = vm.parseJsonAddress(json, '.treasurySpokeOwner');
    handover.gatewayOwner = vm.parseJsonAddress(json, '.gatewayOwner');
    handover.positionManagerOwner = vm.parseJsonAddress(json, '.positionManagerOwner');
  }

  /// @notice Reads the assets to list.
  /// @dev The list is empty until the launch set and its risk parameters are decided, which
  /// configures the market without listing anything. Filling it in needs no change here.
  /// @return assets The assets, in the order they are declared in the configuration inputs.
  function readAssets() internal view returns (Asset[] memory assets) {
    string memory json = vm.readFile(CONFIG_PATH);

    uint256 count;
    while (vm.keyExistsJson(json, _assetPath(count))) {
      ++count;
    }

    assets = new Asset[](count);
    for (uint256 i; i < count; ++i) {
      string memory path = _assetPath(i);
      assets[i] = Asset({
        symbol: vm.parseJsonString(json, string.concat(path, '.symbol')),
        underlying: vm.parseJsonAddress(json, string.concat(path, '.underlying')),
        priceSource: vm.parseJsonAddress(json, string.concat(path, '.priceSource')),
        tokenize: vm.parseJsonBool(json, string.concat(path, '.tokenize'))
      });
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

  /// @notice Reverts unless every configured asset and price source is a live contract.
  /// @dev `HubConfigurator.addAsset` reads `decimals()` off the underlying, and
  /// `AaveOracle.setReserveSource` checks the price source decimals and reads a price from it.
  ///
  /// It does not validate that the price source is the *right* feed, and nothing here does: a
  /// capped adapter built against the wrong base feed reports 8 decimals like any other. The price
  /// source is verified off-chain, before it reaches this config.
  /// @param assets The assets read from the configuration inputs.
  function requireLiveAssets(Asset[] memory assets) internal view {
    for (uint256 i; i < assets.length; ++i) {
      Asset memory a = assets[i];
      require(a.underlying != address(0), AddressNotSet(a.symbol, 'underlying'));
      require(a.priceSource != address(0), AddressNotSet(a.symbol, 'priceSource'));
      require(a.underlying.code.length > 0, NotAContract(a.symbol, 'underlying'));
      require(a.priceSource.code.length > 0, NotAContract(a.symbol, 'priceSource'));
    }
  }

  /// @notice Returns the ProxyAdmin of a transparent proxy.
  /// @param proxy The proxy to read.
  /// @return The ProxyAdmin address.
  function proxyAdmin(address proxy) internal view returns (address) {
    return address(uint160(uint256(vm.load(proxy, ERC1967_ADMIN_SLOT))));
  }

  function _assetPath(uint256 index) private pure returns (string memory) {
    return string.concat('.assets[', vm.toString(index), ']');
  }

  function _optionalAddress(string memory json, string memory key) private view returns (address) {
    return vm.keyExistsJson(json, key) ? vm.parseJsonAddress(json, key) : address(0);
  }
}
