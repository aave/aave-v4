// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

import {Vm} from 'forge-std/Vm.sol';

/// @title AaveV4BaseConfigInputs
/// @author Aave Labs
/// @notice Reads the inputs shared by the Base configuration and handover scripts: the addresses of
/// a deployed Base market, the handover targets, and the assets to list with their risk parameters.
library AaveV4BaseConfigInputs {
  using SafeCast for uint256;

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

  /// @notice An asset to list, with the price feed its Spoke reserves read it through and the risk
  /// parameters it is listed with.
  /// @dev symbol The underlying's symbol, used for error reporting and logging only.
  /// @dev priceSource The price feed of the asset, which must report 8 decimals.
  /// @dev decimals The underlying's own decimals, declared rather than read off the token. The
  /// Coinbase equities are handled natively by the Base client and carry a single `0xef` code byte,
  /// which the EVM cannot execute, so `decimals()` on them reverts under any local or forked run —
  /// including the simulation `forge script` does before it broadcasts.
  /// @dev liquidityFee The protocol fee on drawn and premium liquidity growth, in BPS.
  /// @dev optimalUsageRatio The usage ratio the rate curve kinks at, in BPS.
  /// @dev baseDrawnRate The drawn rate at zero usage, in BPS.
  /// @dev rateGrowthBeforeOptimal The rate added between zero and optimal usage, in BPS.
  /// @dev rateGrowthAfterOptimal The rate added between optimal and full usage, in BPS.
  /// @dev addCap The most the Spoke can add, in whole assets.
  /// @dev drawCap The most the Spoke can draw, in whole assets.
  /// @dev riskPremiumThreshold The highest ratio of premium to drawn shares the Spoke can reach, in
  /// BPS.
  /// @dev collateralFactor The share of the asset's value usable as collateral, in BPS.
  /// @dev maxLiquidationBonus The largest bonus a liquidator is paid, in BPS, where 100_00 is 0.00%.
  /// @dev liquidationFee The protocol's cut of that bonus, in BPS.
  /// @dev borrowable Whether the reserve can be drawn from.
  /// @dev receiveSharesEnabled Whether a liquidator can take collateral as shares.
  /// @dev tokenize Whether a tokenization spoke is deployed for the asset and registered on the Hub.
  /// @dev tokenizationAddCap The most that tokenization spoke can add, in whole assets.
  struct Asset {
    string symbol;
    address underlying;
    address priceSource;
    uint8 decimals;
    uint16 liquidityFee;
    uint16 optimalUsageRatio;
    uint32 baseDrawnRate;
    uint32 rateGrowthBeforeOptimal;
    uint32 rateGrowthAfterOptimal;
    uint40 addCap;
    uint40 drawCap;
    uint24 riskPremiumThreshold;
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
    uint16 liquidationFee;
    bool borrowable;
    bool receiveSharesEnabled;
    bool tokenize;
    uint40 tokenizationAddCap;
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

  /// @notice Reads the assets to list, with their risk parameters.
  /// @dev An empty list configures the market without listing anything, which is a valid run.
  /// @return assets The assets, in the order they are declared in the configuration inputs.
  function readAssets() internal view returns (Asset[] memory assets) {
    string memory json = vm.readFile(CONFIG_PATH);

    uint256 count;
    while (vm.keyExistsJson(json, _assetPath(count))) {
      ++count;
    }

    assets = new Asset[](count);
    for (uint256 i; i < count; ++i) {
      assets[i] = _readAsset(json, _assetPath(i));
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

  /// @dev Assigns field by field rather than building a struct literal, so that each cheatcode call
  /// writes straight into the returned struct.
  function _readAsset(
    string memory json,
    string memory path
  ) private pure returns (Asset memory asset) {
    asset.symbol = vm.parseJsonString(json, string.concat(path, '.symbol'));
    asset.underlying = vm.parseJsonAddress(json, string.concat(path, '.underlying'));
    asset.priceSource = vm.parseJsonAddress(json, string.concat(path, '.priceSource'));
    asset.decimals = _uint(json, path, 'decimals').toUint8();

    asset.liquidityFee = _uint(json, path, 'liquidityFee').toUint16();
    asset.optimalUsageRatio = _uint(json, path, 'optimalUsageRatio').toUint16();
    asset.baseDrawnRate = _uint(json, path, 'baseDrawnRate').toUint32();
    asset.rateGrowthBeforeOptimal = _uint(json, path, 'rateGrowthBeforeOptimal').toUint32();
    asset.rateGrowthAfterOptimal = _uint(json, path, 'rateGrowthAfterOptimal').toUint32();

    asset.addCap = _uint(json, path, 'addCap').toUint40();
    asset.drawCap = _uint(json, path, 'drawCap').toUint40();
    asset.riskPremiumThreshold = _uint(json, path, 'riskPremiumThreshold').toUint24();

    asset.collateralFactor = _uint(json, path, 'collateralFactor').toUint16();
    asset.maxLiquidationBonus = _uint(json, path, 'maxLiquidationBonus').toUint32();
    asset.liquidationFee = _uint(json, path, 'liquidationFee').toUint16();
    asset.borrowable = _bool(json, path, 'borrowable');
    asset.receiveSharesEnabled = _bool(json, path, 'receiveSharesEnabled');

    asset.tokenize = _bool(json, path, 'tokenize');
    asset.tokenizationAddCap = _uint(json, path, 'tokenizationAddCap').toUint40();
  }

  function _uint(
    string memory json,
    string memory path,
    string memory field
  ) private pure returns (uint256) {
    return vm.parseJsonUint(json, string.concat(path, '.', field));
  }

  function _bool(
    string memory json,
    string memory path,
    string memory field
  ) private pure returns (bool) {
    return vm.parseJsonBool(json, string.concat(path, '.', field));
  }

  function _assetPath(uint256 index) private pure returns (string memory) {
    return string.concat('.assets[', vm.toString(index), ']');
  }

  function _optionalAddress(string memory json, string memory key) private view returns (address) {
    return vm.keyExistsJson(json, key) ? vm.parseJsonAddress(json, key) : address(0);
  }
}
