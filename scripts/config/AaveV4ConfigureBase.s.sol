// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {AaveV4BaseConfiguration} from 'scripts/config/AaveV4BaseConfiguration.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4ConfigureBase
/// @author Aave Labs
/// @notice Configures the Base market from config/base-config.json, then halts every asset it
/// listed on the Hub.
/// @dev Run after the deploy script and before `AaveV4RelinquishBase`. The asset list is empty until
/// the launch set is decided, in which case this grants the roles, applies the liquidation configs
/// and wires the position managers without listing anything. See `AaveV4BaseParameters` and
/// docs/base-deploy.md.
contract AaveV4ConfigureBase is Script {
  /// @notice Reads the inputs and configures the market as the broadcasting deployer.
  function run() external {
    AaveV4BaseConfigInputs.Market memory market = AaveV4BaseConfigInputs.readMarket();
    AaveV4BaseConfigInputs.Handover memory targets = AaveV4BaseConfigInputs.readHandover();
    AaveV4BaseConfigInputs.Asset[] memory assets = AaveV4BaseConfigInputs.readAssets();
    AaveV4BaseConfigInputs.requireLiveAssets(assets);

    if (assets.length == 0) {
      console.log('no assets configured: listing nothing');
    }
    for (uint256 i; i < assets.length; ++i) {
      console.log('listing', assets[i].symbol, assets[i].underlying);
    }

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4BaseConfiguration.configure(market, deployer, assets, targets.proxyAdminOwner);
    vm.stopBroadcast();
  }
}
