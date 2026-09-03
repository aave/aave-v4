// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ArcConfigInputs} from 'scripts/config/ArcConfigInputs.sol';
import {ArcHandover} from 'scripts/config/ArcHandover.sol';

import {Script} from 'forge-std/Script.sol';

/// @title AaveV4RelinquishArc
/// @author Aave Labs
/// @notice Hands the Arc market over to the Security Council and verifies the deployer holds
/// nothing afterwards.
/// @dev Run last, after `AaveV4ConfigureArc`. The verification reverts the whole broadcast if any
/// role or ownership is left behind, so a successful run is the proof of a complete handover.
contract AaveV4RelinquishArc is Script {
  /// @notice Reads the inputs, hands the market over as the broadcasting deployer, then verifies.
  function run() external {
    ArcConfigInputs.Market memory market = ArcConfigInputs.readMarket();
    ArcConfigInputs.Handover memory targets = ArcConfigInputs.readHandover();

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    ArcHandover.relinquish(market, targets, deployer);
    ArcHandover.verify(market, targets, deployer);
    vm.stopBroadcast();
  }
}
