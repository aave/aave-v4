// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {AaveV4EtherfiCash} from 'src/etherfi/AaveV4EtherfiCash.sol';
import {AaveV4EtherfiCashAssets} from 'src/etherfi/AaveV4EtherfiCash.sol';

/// @title DeployEtherfiCashInstance
/// @notice Deploys the ether.fi Cash Aave V4 instance on OP Mainnet (whitelabel): one hub
/// ("CASH_HUB") and one spoke ("CASH_SPOKE"), with every admin/owner seat pointed at the
/// Owner Safe. The config engine is deployed separately (it is stateless) or reused if one
/// already exists on OP.
///
/// Two-step, per the deployment framework (LiquidationLogic must be pre-deployed and linked):
///   1. make deploy-precompile chain=optimism account=<keystore>
///   2. forge script scripts/etherfi/DeployEtherfiCashInstance.s.sol --rpc-url optimism \
///        --account <keystore> --broadcast --verify
/// The deployment report (all addresses for AaveV4EtherfiCash.sol) lands in
/// output/reports/deployments/.
///
/// After this run the Owner Safe holds: AccessManager DEFAULT_ADMIN (role 0), hub + spoke
/// configurator domain admin roles (200/400), hub/spoke admin roles, TreasurySpoke ownership,
/// and proxy admin ownership — everything the launch payload's delegatecall execution needs.
contract DeployEtherfiCashInstanceScript is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('etherfi-cash-op') {}

  function _expectedChainId() internal pure override returns (uint256) {
    return 10;
  }

  /// @dev SKIP_PROMPT=true bypasses the interactive confirmation for non-interactive runs
  /// (fork simulations, CI). The deployment summary is still logged.
  function _executeUserPrompt() internal override {
    if (vm.envOr('SKIP_PROMPT', false)) return;
    super._executeUserPrompt();
  }

  function _getDeployInputs() internal view override returns (InputUtils.FullDeployInputs memory) {
    address ownerSafe = AaveV4EtherfiCash.OWNER_SAFE;

    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'CASH_HUB';

    string[] memory spokeLabels = new string[](1);
    spokeLabels[0] = 'CASH_SPOKE';

    uint16[] memory spokeMaxReservesLimits = new uint16[](1);
    spokeMaxReservesLimits[0] = 64; // 19 launch reserves + room for stocks and future listings

    return
      InputUtils.FullDeployInputs({
        accessManagerAdmin: ownerSafe,
        proxyAdminOwner: ownerSafe,
        hubAdmin: ownerSafe,
        hubConfiguratorAdmin: ownerSafe,
        treasurySpokeOwner: ownerSafe,
        spokeAdmin: ownerSafe,
        spokeConfiguratorAdmin: ownerSafe,
        gatewayOwner: ownerSafe,
        positionManagerOwner: ownerSafe,
        nativeWrapper: AaveV4EtherfiCashAssets.WETH_UNDERLYING,
        deployNativeTokenGateway: true,
        deploySignatureGateway: false,
        deployPositionManagers: true,
        grantRoles: true,
        hubLabels: hubLabels,
        spokeLabels: spokeLabels,
        spokeMaxReservesLimits: spokeMaxReservesLimits,
        salt: keccak256('ETHERFI_CASH_AAVE_V4_OP_V1')
      });
  }
}
