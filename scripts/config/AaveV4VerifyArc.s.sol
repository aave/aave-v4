// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigEngine} from 'scripts/config/ArcConfigEngine.sol';
import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcParameters} from 'scripts/config/ArcParameters.sol';
import {ArcVerification} from 'scripts/config/ArcVerification.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4VerifyArc
/// @author Aave Labs
/// @notice Asserts that the deployed Arc market matches the deploy inputs and the ARFC parameters.
/// @dev Run last, after the deploy, the configuration and the handover. `run()` is `view`, so it
/// cannot broadcast anything: it either returns having found no discrepancy, or reverts naming the
/// first one. Point it at a market with:
///
///     forge script scripts/config/AaveV4VerifyArc.s.sol --rpc-url arc
///
/// It reads the same inputs the other scripts do, so it verifies against intent rather than against
/// a recorded snapshot of the result.
contract AaveV4VerifyArc is Script {
  /// @notice Reads the inputs and asserts the market matches them.
  function run() external view {
    ArcConfigInputs.Market memory market = ArcConfigInputs.readMarket();
    ArcConfigInputs.Handover memory targets = ArcConfigInputs.readHandover();
    ArcConfigInputs.AssetInput[] memory assets = ArcConfigInputs.readAssets();
    address deployer = ArcConfigInputs.readDeployer();

    ArcVerification.verify(market, targets, assets, deployer);

    console.log('hub', market.hub);
    console.log('configEngine', ArcConfigEngine.predictedAddress());
    for (uint256 i; i < assets.length; ++i) {
      console.log('verified', ArcParameters.symbol(assets[i].key), assets[i].underlying);
    }
    console.log('Arc market verified: deployment, handover and configuration all match');
  }
}
