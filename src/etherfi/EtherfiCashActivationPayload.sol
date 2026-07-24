// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4EtherfiCash, AaveV4EtherfiCashHubs} from 'src/etherfi/AaveV4EtherfiCash.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title EtherfiCashActivationPayload
/// @author ether.fi
/// - Discussion: https://governance.aave.com/t/arfc-deploy-a-dedicated-aave-v4-whitelabel-instance-fully-managed-by-etherfi-on-op-mainnet-to-power-ether-fi-cash/25314
/// @notice PHASE 2 of the two-phase launch: activates every (asset, spoke) pair on the Cash
/// Hub after the dormant configuration (EtherfiCashLaunchPayload) has been verified on-chain.
/// Same enumeration pattern as the Aave V4 Avalanche activation (proposal 504) — no hardcoded
/// asset list, so it activates exactly what is configured. All addresses come from the
/// AaveV4EtherfiCash address-book libraries; no constructor arguments.
///
/// Executed by the OWNER Safe via a delegatecall Safe transaction; the Safe holds
/// HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, which owns the updateSpokeActive selector.
///
/// SAFE-DELEGATECALL SAFETY: constants only, no storage writes.
contract EtherfiCashActivationPayload {
  function execute() external {
    IHub hub = IHub(AaveV4EtherfiCashHubs.CASH_HUB);
    uint256 assetCount = hub.getAssetCount();
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      uint256 spokeCount = hub.getSpokeCount(assetId);
      for (uint256 spokeId; spokeId < spokeCount; ++spokeId) {
        address spoke = hub.getSpokeAddress({assetId: assetId, index: spokeId});
        IHubConfigurator(AaveV4EtherfiCash.HUB_CONFIGURATOR).updateSpokeActive({
          hub: address(hub),
          assetId: assetId,
          spoke: spoke,
          active: true
        });
      }
    }
  }
}
