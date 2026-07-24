// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

/// @title EtherfiCashActivationPayload
/// @author ether.fi
/// - Discussion: https://governance.aave.com/t/arfc-deploy-a-dedicated-aave-v4-whitelabel-instance-fully-managed-by-etherfi-on-op-mainnet-to-power-ether-fi-cash/25314
/// @notice PHASE 2 of the two-phase launch: activates every (asset, spoke) pair on the Cash
/// Hub after the dormant configuration (EtherfiCashLaunchPayload) has been verified on-chain.
/// Same enumeration pattern as the Aave V4 Avalanche activation (proposal 504) — no hardcoded
/// asset list, so it activates exactly what is configured.
///
/// Executed by the OWNER Safe via a delegatecall Safe transaction; the Safe holds
/// HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, which owns the updateSpokeActive selector.
///
/// SAFE-DELEGATECALL SAFETY: immutables only, no storage writes.
contract EtherfiCashActivationPayload {
  IHub public immutable HUB;
  IHubConfigurator public immutable HUB_CONFIGURATOR;

  error MissingAddress();

  constructor(IHub hub, IHubConfigurator hubConfigurator) {
    require(address(hub) != address(0) && address(hubConfigurator) != address(0), MissingAddress());
    HUB = hub;
    HUB_CONFIGURATOR = hubConfigurator;
  }

  function execute() external {
    uint256 assetCount = HUB.getAssetCount();
    for (uint256 assetId; assetId < assetCount; ++assetId) {
      uint256 spokeCount = HUB.getSpokeCount(assetId);
      for (uint256 spokeId; spokeId < spokeCount; ++spokeId) {
        address spoke = HUB.getSpokeAddress({assetId: assetId, index: spokeId});
        HUB_CONFIGURATOR.updateSpokeActive({
          hub: address(HUB),
          assetId: assetId,
          spoke: spoke,
          active: true
        });
      }
    }
  }
}
