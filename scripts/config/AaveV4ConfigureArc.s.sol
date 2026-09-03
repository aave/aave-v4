// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcConfiguration} from 'scripts/config/ArcConfiguration.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4ConfigureArc
/// @author Aave Labs
/// @notice Configures the Arc market with the ARFC risk parameters, then halts every asset it
/// listed on the Hub.
/// @dev Run after the deploy script and before `AaveV4RelinquishArc`. The launch set is whichever
/// assets have both addresses filled in in config/arc-config.json; the rest are skipped. See
/// `ArcParameters` and docs/arc-deploy.md.
contract AaveV4ConfigureArc is Script {
  /// @notice Reads the inputs and configures the market as the broadcasting deployer.
  function run() external {
    ArcConfigInputs.Market memory market = ArcConfigInputs.readMarket();
    ArcConfigInputs.AssetInput[] memory assets = ArcConfigInputs.readAssets();
    ArcConfigInputs.Handover memory targets = ArcConfigInputs.readHandover();

    for (uint256 i; i < assets.length; ++i) {
      console.log('listing', ArcParameters.symbol(assets[i].key), assets[i].underlying);
    }
    console.log('tokenization spoke proxy admin owner', targets.proxyAdminOwner);

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    ArcConfiguration.configure(market, deployer, assets, targets.proxyAdminOwner);
    vm.stopBroadcast();
  }
}
