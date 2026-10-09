// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

import {Vm} from 'forge-std/Vm.sol';

/// @title AaveV4SentoraConfigInputs
/// @author Aave Labs
/// @notice Reads the inputs shared by the Sentora configuration and handover scripts: the addresses
/// of a deployed Sentora market, the handover targets, the assets to list on the Hub, and the
/// reserves to list on each Spoke with their risk parameters.
library AaveV4SentoraConfigInputs {
  using SafeCast for uint256;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @dev Deploy inputs, which also carry the handover targets.
  string internal constant DEPLOY_CONFIG_PATH = 'config/sentora.json';
  /// @dev Configuration inputs.
  string internal constant CONFIG_PATH = 'config/sentora-config.json';
  /// @dev Stands in for the Sentora Executor, the timelocked contract that owns the market's
  /// contracts and holds the configurator admin roles, until it is known.
  address internal constant SENTORA_EXECUTOR_PLACEHOLDER =
    0x1111111111111111111111111111111111111111;
  /// @dev Stands in for the Sentora Risk Steward, which is not deployed yet.
  address internal constant RISK_STEWARD_PLACEHOLDER = 0x2222222222222222222222222222222222222222;
  /// @dev Ethereum, the only chain the placeholders are rejected on.
  uint256 internal constant ETHEREUM_CHAIN_ID = 1;
  /// @dev ERC-1967 admin slot, holding the ProxyAdmin address of a transparent proxy.
  bytes32 internal constant ERC1967_ADMIN_SLOT =
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

  /// @notice Addresses of a deployed Sentora market, read back from its deployment report.
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
  /// @dev `admin` admins the AccessManager. `sentoraExecutor`, `riskSteward` and
  /// `emergencyOperator` hold the roles that reach the configurators, as set out in
  /// `AaveV4SentoraRoles`, and `admin` also holds the emergency role.
  struct Handover {
    address admin;
    address proxyAdminOwner;
    address treasurySpokeOwner;
    address gatewayOwner;
    address positionManagerOwner;
    address sentoraExecutor;
    address riskSteward;
    address emergencyOperator;
  }

  /// @notice An asset to list on the Hub, with its rate curve and the price feed every Spoke
  /// reserve of it reads it through.
  /// @dev symbol The underlying's symbol, which reserves refer to the asset by.
  /// @dev priceSource The price feed of the asset, which must report 8 decimals.
  /// @dev liquidityFee The protocol fee on drawn and premium liquidity growth, in BPS.
  /// @dev optimalUsageRatio The usage ratio the rate curve kinks at, in BPS.
  /// @dev baseDrawnRate The drawn rate at zero usage, in BPS.
  /// @dev rateGrowthBeforeOptimal The rate added between zero and optimal usage, in BPS.
  /// @dev rateGrowthAfterOptimal The rate added between optimal and full usage, in BPS.
  /// @dev tokenize Whether a tokenization spoke is deployed for the asset and registered on the Hub.
  /// @dev tokenizationAddCap The most that tokenization spoke can add, in whole assets.
  struct Asset {
    string symbol;
    address underlying;
    address priceSource;
    uint16 liquidityFee;
    uint16 optimalUsageRatio;
    uint32 baseDrawnRate;
    uint32 rateGrowthBeforeOptimal;
    uint32 rateGrowthAfterOptimal;
    bool tokenize;
    uint40 tokenizationAddCap;
  }

  /// @notice An asset listed on one Spoke, with the caps and risk parameters it is listed with there.
  /// @dev spoke The Spoke's label, as declared in the deploy inputs.
  /// @dev asset The symbol of the asset, as declared in the configuration inputs.
  /// @dev spokeIndex The position of `spoke` in the deploy inputs' spoke labels.
  /// @dev assetIndex The position of `asset` in the configuration inputs' assets.
  /// @dev addCap The most the Spoke can add, in whole assets.
  /// @dev drawCap The most the Spoke can draw, in whole assets.
  /// @dev riskPremiumThreshold The highest ratio of premium to drawn shares the Spoke can reach, in
  /// BPS.
  /// @dev collateralRisk The risk premium the asset adds to a position using it as collateral, in
  /// BPS.
  /// @dev collateralFactor The share of the asset's value usable as collateral, in BPS.
  /// @dev maxLiquidationBonus The largest bonus a liquidator is paid, in BPS, where 100_00 is 0.00%.
  /// @dev liquidationFee The protocol's cut of that bonus, in BPS.
  /// @dev borrowable Whether the reserve can be drawn from.
  /// @dev receiveSharesEnabled Whether a liquidator can take collateral as shares.
  struct Reserve {
    string spoke;
    string asset;
    uint256 spokeIndex;
    uint256 assetIndex;
    uint40 addCap;
    uint40 drawCap;
    uint24 riskPremiumThreshold;
    uint24 collateralRisk;
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
    uint16 liquidationFee;
    bool borrowable;
    bool receiveSharesEnabled;
  }

  /// @notice Thrown when the deploy inputs declare anything other than a single Hub.
  error SingleHubExpected();
  /// @notice Thrown when a handover target is still a placeholder on Ethereum.
  error PlaceholderAddress(string field);
  /// @notice Thrown when a reserve names a Spoke label the deploy inputs do not declare.
  error UnknownSpoke(string label);
  /// @notice Thrown when a reserve names an asset symbol the configuration inputs do not declare.
  error UnknownAsset(string symbol);
  /// @notice Thrown when an asset or its price source is left unset in the configuration inputs.
  error AddressNotSet(string symbol, string field);
  /// @notice Thrown when an asset or its price source has no code, which every configuration call
  /// on it would revert on.
  error NotAContract(string symbol, string field);

  /// @notice Reads the deployed market addresses from the report named in the configuration inputs.
  /// @return market The addresses of the deployed Sentora market.
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
  /// @dev `hubAdmin`, `spokeAdmin`, `hubConfiguratorAdmin` and `spokeConfiguratorAdmin` are
  /// deliberately not read: the Hub and Spoke roles are left unheld as on the live Ethereum and
  /// Avalanche markets, and the configurator roles go to the handover targets read here.
  ///
  /// Reverts on Ethereum while any target is still a placeholder. Local runs are exempt, which is
  /// what lets the tests hand over from the unresolved config.
  /// @return handover The addresses to hand the market over to.
  function readHandover() internal view returns (Handover memory handover) {
    string memory json = vm.readFile(DEPLOY_CONFIG_PATH);

    handover.admin = _target(json, 'accessManagerAdmin');
    handover.proxyAdminOwner = _target(json, 'proxyAdminOwner');
    handover.treasurySpokeOwner = _target(json, 'treasurySpokeOwner');
    handover.gatewayOwner = _target(json, 'gatewayOwner');
    handover.positionManagerOwner = _target(json, 'positionManagerOwner');
    handover.sentoraExecutor = _target(json, 'sentoraExecutor');
    handover.riskSteward = _target(json, 'riskSteward');
    handover.emergencyOperator = _target(json, 'emergencyOperator');
  }

  /// @notice Reads the assets to list on the Hub, with their rate curves.
  /// @dev An empty list configures the market without listing anything, which is a valid run.
  /// @return assets The assets, in the order they are declared in the configuration inputs.
  function readAssets() internal view returns (Asset[] memory assets) {
    string memory json = vm.readFile(CONFIG_PATH);

    assets = new Asset[](_count(json, '.assets'));
    for (uint256 i; i < assets.length; ++i) {
      assets[i] = _readAsset(json, _path('.assets', i));
    }
  }

  /// @notice Reads the reserves to list on each Spoke, with their caps and risk parameters, and
  /// resolves the Spoke and asset each one names.
  /// @param assets The assets read from the configuration inputs.
  /// @return reserves The reserves, in the order they are declared in the configuration inputs.
  function readReserves(Asset[] memory assets) internal view returns (Reserve[] memory reserves) {
    string memory json = vm.readFile(CONFIG_PATH);
    string[] memory spokeLabels = vm.parseJsonStringArray(
      vm.readFile(DEPLOY_CONFIG_PATH),
      '.spokeLabels'
    );

    reserves = new Reserve[](_count(json, '.reserves'));
    for (uint256 i; i < reserves.length; ++i) {
      reserves[i] = _readReserve(json, _path('.reserves', i));
      reserves[i].spokeIndex = _spokeIndex(spokeLabels, reserves[i].spoke);
      reserves[i].assetIndex = _assetIndex(assets, reserves[i].asset);
    }
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

    asset.liquidityFee = _uint(json, path, 'liquidityFee').toUint16();
    asset.optimalUsageRatio = _uint(json, path, 'optimalUsageRatio').toUint16();
    asset.baseDrawnRate = _uint(json, path, 'baseDrawnRate').toUint32();
    asset.rateGrowthBeforeOptimal = _uint(json, path, 'rateGrowthBeforeOptimal').toUint32();
    asset.rateGrowthAfterOptimal = _uint(json, path, 'rateGrowthAfterOptimal').toUint32();

    asset.tokenize = _bool(json, path, 'tokenize');
    asset.tokenizationAddCap = _uint(json, path, 'tokenizationAddCap').toUint40();
  }

  /// @dev Leaves `spokeIndex` and `assetIndex` unset, for `readReserves` to resolve.
  function _readReserve(
    string memory json,
    string memory path
  ) private pure returns (Reserve memory reserve) {
    reserve.spoke = vm.parseJsonString(json, string.concat(path, '.spoke'));
    reserve.asset = vm.parseJsonString(json, string.concat(path, '.asset'));

    reserve.addCap = _uint(json, path, 'addCap').toUint40();
    reserve.drawCap = _uint(json, path, 'drawCap').toUint40();
    reserve.riskPremiumThreshold = _uint(json, path, 'riskPremiumThreshold').toUint24();

    reserve.collateralRisk = _uint(json, path, 'collateralRisk').toUint24();
    reserve.collateralFactor = _uint(json, path, 'collateralFactor').toUint16();
    reserve.maxLiquidationBonus = _uint(json, path, 'maxLiquidationBonus').toUint32();
    reserve.liquidationFee = _uint(json, path, 'liquidationFee').toUint16();
    reserve.borrowable = _bool(json, path, 'borrowable');
    reserve.receiveSharesEnabled = _bool(json, path, 'receiveSharesEnabled');
  }

  /// @dev Reads a handover target, rejecting any placeholder on Ethereum.
  function _target(string memory json, string memory field) private view returns (address target) {
    target = vm.parseJsonAddress(json, string.concat('.', field));

    if (block.chainid == ETHEREUM_CHAIN_ID) {
      require(
        target != SENTORA_EXECUTOR_PLACEHOLDER && target != RISK_STEWARD_PLACEHOLDER,
        PlaceholderAddress(field)
      );
    }
  }

  function _spokeIndex(
    string[] memory spokeLabels,
    string memory label
  ) private pure returns (uint256) {
    for (uint256 i; i < spokeLabels.length; ++i) {
      if (keccak256(bytes(spokeLabels[i])) == keccak256(bytes(label))) return i;
    }
    revert UnknownSpoke(label);
  }

  function _assetIndex(Asset[] memory assets, string memory symbol) private pure returns (uint256) {
    for (uint256 i; i < assets.length; ++i) {
      if (keccak256(bytes(assets[i].symbol)) == keccak256(bytes(symbol))) return i;
    }
    revert UnknownAsset(symbol);
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

  function _count(string memory json, string memory key) private view returns (uint256 count) {
    while (vm.keyExistsJson(json, _path(key, count))) {
      ++count;
    }
  }

  function _path(string memory key, uint256 index) private pure returns (string memory) {
    return string.concat(key, '[', vm.toString(index), ']');
  }

  function _optionalAddress(string memory json, string memory key) private view returns (address) {
    return vm.keyExistsJson(json, key) ? vm.parseJsonAddress(json, key) : address(0);
  }
}
