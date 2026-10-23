// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4HubImplementationDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubImplementationDeployProcedure.sol';
import {AaveV4SpokeImplementationDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeImplementationDeployProcedure.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

/// @title AaveV4DeployOrchestration Library
/// @author Aave Labs
/// @notice Main orchestrator that deploys all Aave V4 contracts in order and configures roles.
library AaveV4DeployOrchestration {
  bytes32 public constant SALT = keccak256('AAVE_V4');

  /// @notice Deploys all Aave V4 contracts, configures roles, and returns the full deployment report.
  /// @param logger The logger instance used for console and JSON output.
  /// @param deployer The address executing the deployment.
  /// @param deployInputs The full set of deployment configuration inputs.
  /// @param hubBytecode The creation bytecode of the HubInstance contract.
  /// @param spokeBytecode The creation bytecode of the SpokeInstance contract.
  /// @return report The full deployment report containing all batch sub-reports.
  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs,
    bytes memory hubBytecode,
    bytes memory spokeBytecode
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    bytes32 salt = _deriveSalt({deployer: deployer, salt: deployInputs.salt});
    report.salt = deployInputs.salt;

    // Deploy Access Batch
    // initialize with deployer as access manager admin
    address initialAdmin = deployer;
    report.authorityBatchReport = _deployAuthorityBatch({
      logger: logger,
      accessManagerAdmin: initialAdmin,
      salt: salt
    });

    address accessManager = report.authorityBatchReport.accessManager;

    // Label all protocol roles
    logger.logHeader1('labeling roles');
    AaveV4AccessManagerRolesProcedure.labelAllRoles(accessManager);

    // Deploy Configurator Batches with AccessManager as authority
    report.hubConfiguratorBatchReport = _deployHubConfiguratorBatch({
      logger: logger,
      authority: accessManager,
      salt: salt
    });
    report.spokeConfiguratorBatchReport = _deploySpokeConfiguratorBatch({
      logger: logger,
      authority: accessManager,
      salt: salt
    });

    // Setup Configurator Roles
    _setupConfiguratorRoles({logger: logger, report: report});

    // Deploy TreasurySpoke Batch (single instance for all hubs)
    report.treasurySpokeBatchReport = _deployTreasurySpokeBatch({
      logger: logger,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      salt: salt
    });

    // Validate label uniqueness (duplicate labels produce identical CREATE2 salts)
    InputUtils.validateUniqueLabels(deployInputs.hubLabels, 'hub');
    InputUtils.validateUniqueLabels(deployInputs.spokeLabels, 'spoke');

    // Deploy Hub Batches
    report.hubInstanceBatchReports = _deployHubs({
      logger: logger,
      proxyAdminOwner: deployInputs.proxyAdminOwner,
      authority: accessManager,
      hubLabels: deployInputs.hubLabels,
      hubBytecode: hubBytecode,
      salt: salt
    });

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes({
      logger: logger,
      deployer: deployer,
      authority: accessManager,
      inputs: deployInputs,
      spokeBytecode: spokeBytecode,
      salt: salt
    });

    // Deploy Gateways Batch if either gateway flag is enabled
    if (deployInputs.deployNativeTokenGateway || deployInputs.deploySignatureGateway) {
      report.gatewaysBatchReport = _deployGatewayBatch({
        logger: logger,
        gatewayOwner: deployInputs.gatewayOwner,
        nativeWrapper: deployInputs.nativeWrapper,
        deployNativeTokenGateway: deployInputs.deployNativeTokenGateway,
        deploySignatureGateway: deployInputs.deploySignatureGateway,
        salt: salt
      });
    }

    // Deploy Position Manager Batches if flag is enabled
    if (deployInputs.deployPositionManagers) {
      report.giverPositionManagerBatchReport = _deployGiverPositionManagerBatch({
        logger: logger,
        owner: deployInputs.positionManagerOwner,
        salt: salt
      });
      report.takerPositionManagerBatchReport = _deployTakerPositionManagerBatch({
        logger: logger,
        owner: deployInputs.positionManagerOwner,
        salt: salt
      });
      report.configPositionManagerBatchReport = _deployConfigPositionManagerBatch({
        logger: logger,
        owner: deployInputs.positionManagerOwner,
        salt: salt
      });
    }

    // Set Roles if needed
    if (deployInputs.grantRoles) {
      if (deployInputs.hubLabels.length > 0) {
        _grantHubRoles({
          logger: logger,
          report: report,
          hubAdmin: deployInputs.hubAdmin,
          hubConfiguratorAdmin: deployInputs.hubConfiguratorAdmin
        });
      }
      if (deployInputs.spokeLabels.length > 0) {
        _grantSpokeRoles({
          logger: logger,
          report: report,
          spokeAdmin: deployInputs.spokeAdmin,
          spokeConfiguratorAdmin: deployInputs.spokeConfiguratorAdmin
        });
      }

      if (deployInputs.accessManagerAdmin != initialAdmin) {
        logger.logHeader1(
          'granting AccessManager Root Admin role to',
          deployInputs.accessManagerAdmin
        );
        AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
          accessManager: accessManager,
          adminToAdd: deployInputs.accessManagerAdmin,
          adminToRemove: initialAdmin
        });
      }
    }

    return report;
  }

  function _deployHubs(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    string[] memory hubLabels,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubInstanceBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubInstanceBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'hub', hubLabels[i]);
      hubInstanceBatchReports[i] = _deployHub({
        logger: logger,
        proxyAdminOwner: proxyAdminOwner,
        authority: authority,
        label: hubLabels[i],
        hubBytecode: hubBytecode,
        salt: childSalt
      });
    }
    logger.logNewLine();
    return hubInstanceBatchReports;
  }

  function _deployHub(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    string memory label,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    address hubImplementation = _deployHubImplementation({
      logger: logger,
      hubBytecode: hubBytecode,
      salt: salt
    });
    hubReport.report = _deployHubInstanceBatch({
      logger: logger,
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      hubImplementation: hubImplementation,
      hubInitCodeHash: keccak256(hubBytecode),
      salt: salt
    });

    _logHubReport({logger: logger, report: hubReport.report, label: label});
    _setupHubRoles({logger: logger, report: hubReport.report, accessManager: authority});

    return hubReport;
  }

  function _deploySpokes(
    Logger logger,
    address deployer,
    address authority,
    InputUtils.FullDeployInputs memory inputs,
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = inputs.spokeLabels.length;
    uint256 limitsLen = inputs.spokeMaxReservesLimits.length;
    require(limitsLen == spokeCount || limitsLen == 0, 'spoke labels/limits length mismatch');
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'spoke', inputs.spokeLabels[i]);
      spokeBatchReports[i] = _deploySpoke({
        logger: logger,
        deployer: deployer,
        proxyAdminOwner: inputs.proxyAdminOwner,
        authority: authority,
        label: inputs.spokeLabels[i],
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: limitsLen > 0
          ? inputs.spokeMaxReservesLimits[i]
          : DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        oracleDecimals: DeployConstants.ORACLE_DECIMALS,
        salt: childSalt
      });
    }
    logger.logNewLine();
    return spokeBatchReports;
  }

  function _deploySpoke(
    Logger logger,
    address deployer,
    address proxyAdminOwner,
    address authority,
    string memory label,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    uint8 oracleDecimals,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    BatchReports.AaveOracleBatchReport memory aaveOracleReport = _deployAaveOracleBatch({
      logger: logger,
      owner: deployer,
      oracleDecimals: oracleDecimals,
      salt: salt
    });
    address spokeImplementation = _deploySpokeImplementation({
      logger: logger,
      aaveOracle: aaveOracleReport.aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
    spokeReport.report = _deploySpokeInstanceBatch({
      logger: logger,
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      spokeImplementation: spokeImplementation,
      salt: salt
    });
    _setAaveOracleSpoke({
      logger: logger,
      aaveOracleBatch: aaveOracleReport.aaveOracleBatch,
      spoke: spokeReport.report.spokeProxy
    });
    _logSpokeReport({logger: logger, report: spokeReport.report, label: label});
    _setupSpokeRoles({logger: logger, report: spokeReport.report, accessManager: authority});

    return spokeReport;
  }

  function _deployHubImplementation(
    Logger logger,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address) {
    logger.logHeader1('deploying Hub implementation');
    return
      AaveV4HubImplementationDeployProcedure.deployHubImplementation({
        hubBytecode: hubBytecode,
        salt: salt
      });
  }

  function _deployHubInstanceBatch(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    bytes32 hubInitCodeHash,
    bytes32 salt
  ) internal returns (BatchReports.HubInstanceBatchReport memory report) {
    logger.logHeader1('deploying HubBatch');
    report = AaveV4DeployBase.deployHubInstanceBatch({
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      hubImplementation: hubImplementation,
      hubInitCodeHash: hubInitCodeHash,
      salt: salt
    });
    return report;
  }

  function _deployAuthorityBatch(
    Logger logger,
    address accessManagerAdmin,
    bytes32 salt
  ) internal returns (BatchReports.AuthorityBatchReport memory report) {
    logger.logHeader1('deploying AuthorityBatch');

    report = AaveV4DeployBase.deployAuthorityBatch({admin: accessManagerAdmin, salt: salt});

    logger.log('AccessManager', report.accessManager);
    logger.logNewLine();
    return report;
  }

  function _deployHubConfiguratorBatch(
    Logger logger,
    address authority,
    bytes32 salt
  ) internal returns (BatchReports.HubConfiguratorBatchReport memory report) {
    logger.logHeader1('deploying HubConfiguratorBatch');
    report = AaveV4DeployBase.deployHubConfiguratorBatch({authority: authority, salt: salt});
    logger.log('HubConfigurator', report.hubConfigurator);
    logger.logNewLine();
    return report;
  }

  function _deploySpokeConfiguratorBatch(
    Logger logger,
    address authority,
    bytes32 salt
  ) internal returns (BatchReports.SpokeConfiguratorBatchReport memory report) {
    logger.logHeader1('deploying SpokeConfiguratorBatch');
    report = AaveV4DeployBase.deploySpokeConfiguratorBatch({authority: authority, salt: salt});
    logger.log('SpokeConfigurator', report.spokeConfigurator);
    logger.logNewLine();
    return report;
  }

  function _deployAaveOracleBatch(
    Logger logger,
    address owner,
    uint8 oracleDecimals,
    bytes32 salt
  ) internal returns (BatchReports.AaveOracleBatchReport memory) {
    logger.logHeader1('deploying AaveOracleBatch');
    return
      AaveV4DeployBase.deployAaveOracleBatch({
        owner: owner,
        oracleDecimals: oracleDecimals,
        salt: salt
      });
  }

  function _setAaveOracleSpoke(Logger logger, address aaveOracleBatch, address spoke) internal {
    logger.logHeader1('setting AaveOracle spoke');
    AaveV4DeployBase.setAaveOracleSpoke({aaveOracleBatch: aaveOracleBatch, spoke: spoke});
  }

  function _deploySpokeImplementation(
    Logger logger,
    address aaveOracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address) {
    logger.logHeader1('deploying Spoke implementation');
    return
      AaveV4SpokeImplementationDeployProcedure.deploySpokeImplementation({
        oracle: aaveOracle,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: maxUserReservesLimit,
        salt: salt
      });
  }

  function _deploySpokeInstanceBatch(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    address spokeImplementation,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.logHeader1('deploying AaveV4SpokeInstanceBatch');
    report = AaveV4DeployBase.deploySpokeInstanceBatch({
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      spokeImplementation: spokeImplementation,
      salt: salt
    });
    return report;
  }

  function _deployTreasurySpokeBatch(
    Logger logger,
    address treasurySpokeOwner,
    bytes32 salt
  ) internal returns (BatchReports.TreasurySpokeBatchReport memory report) {
    logger.logHeader1('deploying TreasurySpokeBatch');
    report = AaveV4DeployBase.deployTreasurySpokeBatch({owner: treasurySpokeOwner, salt: salt});
    logger.log('TreasurySpoke', report.treasurySpoke);
    logger.logNewLine();
    return report;
  }

  function _deployGatewayBatch(
    Logger logger,
    address gatewayOwner,
    address nativeWrapper,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway,
    bytes32 salt
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.logHeader1('deploying GatewayBatch');
    report = AaveV4DeployBase.deployGatewaysBatch({
      owner: gatewayOwner,
      nativeWrapper: nativeWrapper,
      deployNativeTokenGateway: deployNativeTokenGateway,
      deploySignatureGateway: deploySignatureGateway,
      salt: salt
    });
    if (deployNativeTokenGateway) {
      logger.log('NativeTokenGateway', report.nativeGateway);
    }
    if (deploySignatureGateway) {
      logger.log('SignatureGateway', report.signatureGateway);
    }
    return report;
  }

  function _deployGiverPositionManagerBatch(
    Logger logger,
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.GiverPositionManagerBatchReport memory report) {
    logger.logHeader1('deploying GiverPositionManagerBatch');
    report = AaveV4DeployBase.deployGiverPositionManagerBatch({owner: owner, salt: salt});
    logger.logDetail('GiverPositionManager', report.giverPositionManager);
    return report;
  }

  function _deployTakerPositionManagerBatch(
    Logger logger,
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.TakerPositionManagerBatchReport memory report) {
    logger.logHeader1('deploying TakerPositionManagerBatch');
    report = AaveV4DeployBase.deployTakerPositionManagerBatch({owner: owner, salt: salt});
    logger.logDetail('TakerPositionManager', report.takerPositionManager);
    return report;
  }

  function _deployConfigPositionManagerBatch(
    Logger logger,
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.ConfigPositionManagerBatchReport memory report) {
    logger.logHeader1('deploying ConfigPositionManagerBatch');
    report = AaveV4DeployBase.deployConfigPositionManagerBatch({owner: owner, salt: salt});
    logger.logDetail('ConfigPositionManager', report.configPositionManager);
    return report;
  }

  /// @dev Setup roles for the hub and spoke configurators.
  function _setupConfiguratorRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report
  ) internal {
    logger.logHeader1('setting HubConfigurator roles');
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles({
      accessManager: report.authorityBatchReport.accessManager,
      hubConfigurator: report.hubConfiguratorBatchReport.hubConfigurator
    });

    logger.logHeader1('setting SpokeConfigurator roles');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles({
      accessManager: report.authorityBatchReport.accessManager,
      spokeConfigurator: report.spokeConfiguratorBatchReport.spokeConfigurator
    });
  }

  function _setupSpokeRoles(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    address accessManager
  ) internal {
    logger.logHeader1('setting Spoke roles');
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles({
      accessManager: accessManager,
      spoke: report.spokeProxy
    });
  }

  function _setupHubRoles(
    Logger logger,
    BatchReports.HubInstanceBatchReport memory report,
    address accessManager
  ) internal {
    logger.logHeader1('setting Hub roles');
    AaveV4HubRolesProcedure.setupHubAllRoles({accessManager: accessManager, hub: report.hubProxy});
  }

  function _grantHubRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address hubAdmin,
    address hubConfiguratorAdmin
  ) internal {
    address accessManager = report.authorityBatchReport.accessManager;

    logger.logHeader1('granting Hub Admin role to', hubAdmin);
    AaveV4HubRolesProcedure.grantHubAllRoles({accessManager: accessManager, admin: hubAdmin});

    logger.logHeader1(
      'granting Hub Configurator roles to',
      report.hubConfiguratorBatchReport.hubConfigurator
    );
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: report.hubConfiguratorBatchReport.hubConfigurator
    });

    logger.logHeader1('granting HubConfigurator Admin roles to', hubConfiguratorAdmin);
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: accessManager,
      admin: hubConfiguratorAdmin
    });
  }

  function _grantSpokeRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address spokeAdmin,
    address spokeConfiguratorAdmin
  ) internal {
    address accessManager = report.authorityBatchReport.accessManager;

    logger.logHeader1('granting Spoke Admin role to', spokeAdmin);
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles({accessManager: accessManager, admin: spokeAdmin});

    logger.logHeader1(
      'granting Spoke Configurator roles to',
      report.spokeConfiguratorBatchReport.spokeConfigurator
    );
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: report.spokeConfiguratorBatchReport.spokeConfigurator
    });

    logger.logHeader1('granting SpokeConfigurator Admin roles to', spokeConfiguratorAdmin);
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: spokeConfiguratorAdmin
    });
  }

  function _logHubReport(
    Logger logger,
    BatchReports.HubInstanceBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.logDetail('Hub', report.hubProxy);
    logger.logDetail('HubImpl', report.hubImplementation);
    logger.logDetail('InterestRateStrategy', report.irStrategy);
  }

  function _logSpokeReport(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.logDetail('Spoke', report.spokeProxy);
    logger.logDetail('SpokeImpl', report.spokeImplementation);
    logger.logDetail('AaveOracle', report.aaveOracle);
  }

  /// @dev Derives the root salt with deployer address in the first 160 bits
  ///      and the remaining 96 bits from the user-provided salt.
  ///      Layout: [deployer (160 bits) | truncated_hash (96 bits)].
  function _deriveSalt(address deployer, bytes32 salt) internal pure returns (bytes32) {
    return bytes32(bytes20(deployer)) | (keccak256(abi.encode(SALT, salt)) >> 160);
  }

  /// @dev Derives a child salt from a base salt, contract type, and label.
  /// @param baseSalt The base salt to derive the child salt from.
  /// @param contractType The type of the contract (e.g. 'hub', 'spoke').
  /// @param label The label of the contract to be deployed.
  /// @return The derived child salt.
  function _deriveChildSalt(
    bytes32 baseSalt,
    string memory contractType,
    string memory label
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(baseSalt, contractType, label));
  }
}
