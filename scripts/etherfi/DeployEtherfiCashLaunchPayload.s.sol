// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {console2} from 'forge-std/console2.sol';

import {EtherfiCashLaunchPayload} from 'src/etherfi/EtherfiCashLaunchPayload.sol';
import {EtherfiCashActivationPayload} from 'src/etherfi/EtherfiCashActivationPayload.sol';
import {EtherfiCashScriptBase} from 'scripts/etherfi/EtherfiCashScriptBase.s.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title DeployEtherfiCashLaunchPayload
/// @notice Deploys both payloads of the two-phase launch on OP Mainnet at deterministic
/// CREATE2 addresses — reviewers diff the verified on-chain bytecode against this source.
///
/// Usage:
///   dry run:   forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol --rpc-url optimism
///   broadcast: forge script scripts/etherfi/DeployEtherfiCashLaunchPayload.s.sol --rpc-url optimism \
///              --account <keystore> --broadcast --verify
///
/// The script refuses to run while any instance address resolves to zero, and prints the
/// included/skipped asset roster so nothing is listed (or dropped) silently.
contract DeployEtherfiCashLaunchPayloadScript is EtherfiCashScriptBase {
  /// @dev CREATE2 salt; bump the suffix if a new payload version must be deployed.
  bytes32 internal constant SALT = keccak256('ETHERFI_CASH_AAVE_V4_LAUNCH_V1');

  function run() external returns (address payloadAddress, address activationAddress) {
    _requireOpMainnet();

    EtherfiCashLaunchPayload.InstanceAddresses memory instance = _instanceAddresses();
    EtherfiCashLaunchPayload.AssetAddresses memory assets = _assetAddresses();

    vm.startBroadcast();
    EtherfiCashLaunchPayload payload = new EtherfiCashLaunchPayload{salt: SALT}(instance, assets);
    EtherfiCashActivationPayload activation = new EtherfiCashActivationPayload{salt: SALT}(
      IHub(instance.hub),
      IHubConfigurator(instance.hubConfigurator)
    );
    vm.stopBroadcast();

    payloadAddress = address(payload);
    activationAddress = address(activation);
    console2.log('EtherfiCashLaunchPayload (phase 1, dormant config) deployed at:', payloadAddress);
    console2.log('EtherfiCashActivationPayload (phase 2) deployed at:', activationAddress);
    _logRoster(payload);
  }

  function _logRoster(EtherfiCashLaunchPayload payload) internal view {
    EtherfiCashLaunchPayload.AssetSpec[] memory specs = payload.getAssetSpecs();
    console2.log('assets included in this payload:', specs.length, 'of 19');
    for (uint256 i; i < specs.length; i++) {
      console2.log(
        string.concat(
          '  ',
          vm.toString(specs[i].underlying),
          specs[i].borrowable ? '  borrowable' : '  collateral-only',
          '  CF(bps):',
          vm.toString(specs[i].collateralFactor),
          '  addCap:',
          vm.toString(specs[i].addCap),
          '  drawCap:',
          vm.toString(specs[i].drawCap)
        )
      );
    }
    if (specs.length < 19) {
      console2.log(
        'WARNING: assets skipped (underlying or feed unset) - they will need a follow-up payload'
      );
    }
  }
}
