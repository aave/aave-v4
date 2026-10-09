// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraConfiguration} from 'scripts/config/AaveV4SentoraConfiguration.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4ConfigureSentora
/// @author Aave Labs
/// @notice Configures the Sentora market from config/sentora-config.json, then halts every asset it
/// listed on the Hub.
/// @dev Run after the deploy script and before `AaveV4RelinquishSentora`. An empty asset list grants
/// the roles, applies the liquidation configs and wires the position managers without listing
/// anything. See `AaveV4SentoraParameters` and docs/sentora-deploy.md.
contract AaveV4ConfigureSentora is Script {
  /// @notice Reads the inputs and configures the market as the broadcasting deployer.
  function run() external {
    AaveV4SentoraConfigInputs.Market memory market = AaveV4SentoraConfigInputs.readMarket();
    AaveV4SentoraConfigInputs.Handover memory targets = AaveV4SentoraConfigInputs.readHandover();
    AaveV4SentoraConfigInputs.Asset[] memory assets = AaveV4SentoraConfigInputs.readAssets();
    AaveV4SentoraConfigInputs.Reserve[] memory reserves = AaveV4SentoraConfigInputs.readReserves(
      assets
    );
    AaveV4SentoraConfigInputs.requireLiveAssets(assets);

    if (assets.length == 0) {
      console.log('no assets configured: listing nothing');
    }
    for (uint256 i; i < assets.length; ++i) {
      console.log('listing', assets[i].symbol, assets[i].underlying);
    }
    for (uint256 i; i < reserves.length; ++i) {
      console.log('  on spoke', reserves[i].spoke, reserves[i].asset);
    }

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4SentoraConfiguration.configure(
      market,
      deployer,
      assets,
      reserves,
      targets.proxyAdminOwner
    );
    vm.stopBroadcast();
  }
}
