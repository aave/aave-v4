// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {BytecodeHelper} from 'src/deployments/utils/libraries/BytecodeHelper.sol';
import {
  AaveV4EtherfiCash,
  AaveV4EtherfiCashHubs,
  AaveV4EtherfiCashSpokes,
  AaveV4EtherfiCashAssets
} from 'src/etherfi/AaveV4EtherfiCash.sol';

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
  string internal constant HUB_LABEL = 'CASH_HUB';
  string internal constant SPOKE_LABEL = 'CASH_SPOKE';
  /// @dev 19 launch reserves + room for stocks and future listings.
  uint16 internal constant SPOKE_MAX_RESERVES_LIMIT = 64;

  /// @dev Thrown when a deployment report entry differs from the expected address.
  error ReportMismatch(string name, address actual, address expected);

  constructor() AaveV4DeployBatchBaseScript('etherfi-cash-op') {}

  /// @notice Same flow as {AaveV4DeployBatchBaseScript.run}, with ONE substitution: the spoke
  /// implementation deployed for CASH_SPOKE is {EtherFiSpokeInstance} (borrow gated to ether.fi
  /// Cash Safes via the EtherFiDataProvider) instead of the stock SpokeInstance. The body is a
  /// verbatim copy of the base run() — copied rather than hooking the base script so the Aave
  /// deployment framework stays byte-for-byte untouched; the framework appends the same
  /// (oracle, maxUserReservesLimit) constructor args, which EtherFiSpokeInstance keeps.
  function run() external override {
    _validateChainId();
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    InputUtils.FullDeployInputs memory inputs = _getDeployInputs();

    vm.startBroadcast();
    (, address deployer, ) = vm.readCallers();
    inputs = _loadWarningsAndSanitizeInputs(inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.log('deployer', deployer);
    logger.logHeader1('starting Aave V4 batch deployment');

    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(
        logger,
        deployer,
        inputs,
        BytecodeHelper.getHubBytecode(),
        BytecodeHelper.getEtherFiSpokeBytecode()
      );
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    _logDeploySummary(logger);
    logger.logHeader1('batch deployment completed');
    logger.logHeader1('saving logs');
    logger.save({fileName: _outputFileName, withTimestamp: true});

    // after the report is persisted: every deployed address must match the pinned registry,
    // so a misconfiguration is caught here rather than at payload execution
    _assertReportMatchesRegistry(report);
  }

  /// @dev Reverts if any address in the deployment report differs from the AaveV4EtherfiCash
  /// registry. Runs after the report JSON is saved so the actual addresses remain inspectable
  /// on a mismatch.
  function _assertReportMatchesRegistry(
    OrchestrationReports.FullDeploymentReport memory report
  ) internal pure {
    _assertReportEntry(
      'accessManager',
      report.authorityBatchReport.accessManager,
      AaveV4EtherfiCash.ACCESS_MANAGER
    );
    _assertReportEntry(
      'hubConfigurator',
      report.configuratorBatchReport.hubConfigurator,
      AaveV4EtherfiCash.HUB_CONFIGURATOR
    );
    _assertReportEntry(
      'spokeConfigurator',
      report.configuratorBatchReport.spokeConfigurator,
      AaveV4EtherfiCash.SPOKE_CONFIGURATOR
    );
    _assertReportEntry(
      'treasurySpoke',
      report.treasurySpokeBatchReport.treasurySpoke,
      AaveV4EtherfiCashSpokes.TREASURY_SPOKE
    );
    _assertReportEntry(
      'hub.CASH_HUB',
      report.hubInstanceBatchReports[0].report.hubProxy,
      AaveV4EtherfiCashHubs.CASH_HUB
    );
    _assertReportEntry(
      'irStrategy.CASH_HUB',
      report.hubInstanceBatchReports[0].report.irStrategy,
      AaveV4EtherfiCashHubs.CASH_HUB_IR_STRATEGY
    );
    _assertReportEntry(
      'spoke.CASH_SPOKE',
      report.spokeInstanceBatchReports[0].report.spokeProxy,
      AaveV4EtherfiCashSpokes.CASH_SPOKE
    );
    _assertReportEntry(
      'spokeImplementation.CASH_SPOKE',
      report.spokeInstanceBatchReports[0].report.spokeImplementation,
      AaveV4EtherfiCashSpokes.CASH_SPOKE_IMPLEMENTATION
    );

    // must-not-exist set: deploySignatureGateway/deployPositionManagers are false, and the
    // TakerPositionManager in particular must never exist on this instance (see the SECURITY
    // INVARIANT note above deployPositionManagers)
    _assertReportEntry('signatureGateway', report.gatewaysBatchReport.signatureGateway, address(0));
    _assertReportEntry(
      'giverPositionManager',
      report.positionManagerBatchReport.giverPositionManager,
      address(0)
    );
    _assertReportEntry(
      'takerPositionManager',
      report.positionManagerBatchReport.takerPositionManager,
      address(0)
    );
    _assertReportEntry(
      'configPositionManager',
      report.positionManagerBatchReport.configPositionManager,
      address(0)
    );
  }

  function _assertReportEntry(string memory name, address actual, address expected) internal pure {
    require(actual == expected, ReportMismatch(name, actual, expected));
  }

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
    hubLabels[0] = HUB_LABEL;

    string[] memory spokeLabels = new string[](1);
    spokeLabels[0] = SPOKE_LABEL;

    uint16[] memory spokeMaxReservesLimits = new uint16[](1);
    spokeMaxReservesLimits[0] = SPOKE_MAX_RESERVES_LIMIT;

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
        // The stock position managers (Giver/Taker/Config) are deliberately NOT deployed: the
        // cash-v3 LendGateway is the only position manager that may ever be activated on
        // CASH_SPOKE. In particular the TakerPositionManager must never exist on this instance:
        // its borrowOnBehalfOf forwards borrowed funds to the delegated spender, so a
        // safe-signed credit delegation would move borrow proceeds outside the Cash flow while
        // the debt sits on the safe — sidestepping the EtherFiSpokeInstance borrow gate's
        // purpose. See the SECURITY INVARIANT note in EtherFiSpokeInstance and the matching
        // invariant in cash-v3's LendGateway natspec.
        deployPositionManagers: false,
        grantRoles: true,
        hubLabels: hubLabels,
        spokeLabels: spokeLabels,
        spokeMaxReservesLimits: spokeMaxReservesLimits,
        salt: keccak256('ETHERFI_CASH_AAVE_V4_OP_V1')
      });
  }
}
