// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {AaveV4SentoraConfigInputs} from 'scripts/config/AaveV4SentoraConfigInputs.sol';
import {AaveV4SentoraHandover} from 'scripts/config/AaveV4SentoraHandover.sol';

import {Script} from 'forge-std/Script.sol';
import {console2 as console} from 'forge-std/console2.sol';

/// @title AaveV4RelinquishSentora
/// @author Aave Labs
/// @notice Hands the Sentora market over to the V4 Security Council, the Sentora Executor, the Risk
/// Steward and the Emergency Operator, and verifies the deployer holds nothing afterwards.
/// @dev Run last, after `AaveV4ConfigureSentora`. The verification reverts the whole broadcast if any
/// role or ownership is left behind, so a successful run is the proof of a complete handover.
///
/// One step is left for the new owners: the TreasurySpoke, position managers and gateways are
/// `Ownable2Step`, so this records them as pending owners and each owner completes it with
/// `acceptOwnership`.
contract AaveV4RelinquishSentora is Script {
  /// @notice Reads the inputs, hands the market over as the broadcasting deployer, then verifies.
  function run() external {
    AaveV4SentoraConfigInputs.Market memory market = AaveV4SentoraConfigInputs.readMarket();
    AaveV4SentoraConfigInputs.Handover memory targets = AaveV4SentoraConfigInputs.readHandover();

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    AaveV4SentoraHandover.relinquish(market, targets, deployer);
    AaveV4SentoraHandover.verify(market, targets, deployer);
    vm.stopBroadcast();

    console.log('handed over to admin', targets.admin);
    console.log('sentora executor', targets.sentoraExecutor);
    console.log('risk steward', targets.riskSteward);
    console.log('emergency operator', targets.emergencyOperator);
    console.log('awaiting acceptOwnership on:');
    _logPending(market.treasurySpoke, 'treasurySpoke');
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
