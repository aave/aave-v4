// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4BaseConfigInputs} from 'scripts/config/AaveV4BaseConfigInputs.sol';
import {AaveV4BaseHandover} from 'scripts/config/AaveV4BaseHandover.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4RelinquishBase
/// @author Aave Labs
/// @notice Hands the Base market over to the V4 Security Council and the DAO's governance executor,
/// and verifies the deployer holds nothing afterwards.
/// @dev Run last, after `AaveV4ConfigureBase`. The verification reverts the whole broadcast if any
/// role or ownership is left behind, so a successful run is the proof of a complete handover.
///
/// One step is left for the Council: the position managers and gateways are `Ownable2Step`, so this
/// records it as their pending owner and the Council completes each with `acceptOwnership`.
contract AaveV4RelinquishBase is Script {
  /// @notice Reads the inputs, hands the market over as the broadcasting deployer, then verifies.
  function run() external {
    AaveV4BaseConfigInputs.Market memory market = AaveV4BaseConfigInputs.readMarket();
    AaveV4BaseConfigInputs.Handover memory targets = AaveV4BaseConfigInputs.readHandover();

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4BaseHandover.relinquish(market, targets, deployer);
    AaveV4BaseHandover.verify(market, targets, deployer);
    vm.stopBroadcast();

    console.log('handed over to security council', targets.securityCouncil);
    console.log(
      'council executor holds the configurator domain admin roles',
      targets.councilExecutor
    );
    console.log('awaiting acceptOwnership from the council on:');
    _logPending(market.nativeTokenGateway, 'nativeTokenGateway');
    _logPending(market.signatureGateway, 'signatureGateway');
    _logPending(market.giverPositionManager, 'giverPositionManager');
    _logPending(market.takerPositionManager, 'takerPositionManager');
    _logPending(market.configPositionManager, 'configPositionManager');
  }

  function _logPending(address target, string memory name) private pure {
    if (target != address(0)) console.log('  ', name, target);
  }
}
