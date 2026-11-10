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
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';
import {IHubSpokeFactory} from 'src/factory/interfaces/IHubSpokeFactory.sol';

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

    // Deploy Configurator Batch with AccessManager as authority
    report.configuratorBatchReport = _deployConfiguratorBatch({
      logger: logger,
      hubConfiguratorAuthority: accessManager,
      spokeConfiguratorAuthority: accessManager,
      salt: salt
    });

    // Setup Configurator Roles
    _setupConfiguratorRoles({logger: logger, report: report});

    // Deploy canonical implementations and the HubSpokeFactory bound to them
    _deployHubSpokeFactory({
      logger: logger,
      report: report,
      proxyAdminOwner: deployInputs.proxyAdminOwner,
      authority: accessManager,
      hubBytecode: hubBytecode,
      spokeBytecode: spokeBytecode,
      salt: salt
    });
    IHubSpokeFactory factory = IHubSpokeFactory(report.hubSpokeFactoryBatchReport.hubSpokeFactory);

    // Deploy TreasurySpoke (single instance for all hubs)
    report.treasurySpokeBatchReport = _deployTreasurySpoke({
      logger: logger,
      factory: factory,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      salt: salt
    });

    // Validate label uniqueness (duplicate labels produce identical CREATE2 salts)
    InputUtils.validateUniqueLabels(deployInputs.hubLabels, 'hub');
    InputUtils.validateUniqueLabels(deployInputs.spokeLabels, 'spoke');

    // Deploy Hubs
    report.hubInstanceBatchReports = _deployHubs({
      logger: logger,
      factory: factory,
      proxyAdminOwner: deployInputs.proxyAdminOwner,
      authority: accessManager,
      hubLabels: deployInputs.hubLabels,
      salt: salt
    });

    // Deploy Spokes
    report.spokeInstanceBatchReports = _deploySpokes({
      logger: logger,
      factory: factory,
      proxyAdminOwner: deployInputs.proxyAdminOwner,
      authority: accessManager,
      spokeLabels: deployInputs.spokeLabels,
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

    // Deploy Position Managers Batch if flag is enabled
    if (deployInputs.deployPositionManagers) {
      report.positionManagerBatchReport = _deployPositionManagerBatch({
        logger: logger,
        positionManagerOwner: deployInputs.positionManagerOwner,
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

  function _deployHubSpokeFactory(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address proxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal {
    logger.logHeader1('deploying HubImplementationBatch');
    report.hubImplementationBatchReport = AaveV4DeployBase.deployHubImplementationBatch({
      hubBytecode: hubBytecode,
      salt: salt
    });
    logger.log('HubImplementation', report.hubImplementationBatchReport.hubImplementation);

    logger.logHeader1('deploying SpokeImplementationBatch');
    report.spokeImplementationBatchReport = AaveV4DeployBase.deploySpokeImplementationBatch({
      spokeBytecode: spokeBytecode,
      salt: salt
    });
    logger.log('SpokeImplementation', report.spokeImplementationBatchReport.spokeImplementation);

    logger.logHeader1('deploying TokenizationSpokeImplementationBatch');
    report.tokenizationSpokeImplementationBatchReport = AaveV4DeployBase
      .deployTokenizationSpokeImplementationBatch({salt: salt});
    logger.log(
      'TokenizationSpokeImplementation',
      report.tokenizationSpokeImplementationBatchReport.tokenizationSpokeImplementation
    );

    logger.logHeader1('deploying HubSpokeFactoryBatch');
    report.hubSpokeFactoryBatchReport = AaveV4DeployBase.deployHubSpokeFactoryBatch({
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      hubImplementation: report.hubImplementationBatchReport.hubImplementation,
      spokeImplementation: report.spokeImplementationBatchReport.spokeImplementation,
      tokenizationSpokeImplementation: report
        .tokenizationSpokeImplementationBatchReport
        .tokenizationSpokeImplementation,
      salt: salt
    });
    logger.log(
      'TreasurySpokeImplementation',
      report.hubSpokeFactoryBatchReport.treasurySpokeImplementation
    );
    logger.log('HubSpokeFactory', report.hubSpokeFactoryBatchReport.hubSpokeFactory);
    logger.log(
      'HubSpokeFactoryImplementation',
      report.hubSpokeFactoryBatchReport.hubSpokeFactoryImplementation
    );
    logger.logNewLine();
  }

  function _deployTreasurySpoke(
    Logger logger,
    IHubSpokeFactory factory,
    address treasurySpokeOwner,
    bytes32 salt
  ) internal returns (BatchReports.TreasurySpokeBatchReport memory report) {
    require(treasurySpokeOwner != address(0), 'invalid owner');
    logger.logHeader1('deploying TreasurySpoke');
    report.treasurySpoke = factory.deployTreasurySpoke({
      salt: salt,
      owner: treasurySpokeOwner,
      proxyAdminOwner: treasurySpokeOwner
    });
    logger.log('TreasurySpoke', report.treasurySpoke);
    logger.logNewLine();
  }

  function _deployHubs(
    Logger logger,
    IHubSpokeFactory factory,
    address proxyAdminOwner,
    address authority,
    string[] memory hubLabels,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubReports) {
    uint256 hubCount = hubLabels.length;
    hubReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
      logger.logHeader1('deploying Hub');
      IHubSpokeFactory.HubDeployment memory deployment = factory.deployHub({
        salt: _deriveChildSalt(salt, 'hub', hubLabels[i]),
        authority: authority,
        proxyAdminOwner: proxyAdminOwner
      });
      hubReports[i].label = hubLabels[i];
      hubReports[i].report = BatchReports.HubInstanceBatchReport({
        hubProxy: deployment.proxy,
        hubImplementation: factory.getImplementation(IHubSpokeFactory.InstanceType.Hub),
        irStrategy: deployment.irStrategy
      });

      _logHubReport({logger: logger, report: hubReports[i].report, label: hubLabels[i]});
      _setupHubRoles({logger: logger, report: hubReports[i].report, accessManager: authority});
    }
    logger.logNewLine();
  }

  function _deploySpokes(
    Logger logger,
    IHubSpokeFactory factory,
    address proxyAdminOwner,
    address authority,
    string[] memory spokeLabels,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
      logger.logHeader1('deploying Spoke');
      IHubSpokeFactory.SpokeDeployment memory deployment = factory.deploySpoke({
        salt: _deriveChildSalt(salt, 'spoke', spokeLabels[i]),
        authority: authority,
        maxUserReservesLimit: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        proxyAdminOwner: proxyAdminOwner
      });
      spokeReports[i].label = spokeLabels[i];
      spokeReports[i].report = BatchReports.SpokeInstanceBatchReport({
        spokeProxy: deployment.proxy,
        spokeImplementation: factory.getImplementation(IHubSpokeFactory.InstanceType.Spoke),
        aaveOracle: deployment.oracle
      });

      _logSpokeReport({logger: logger, report: spokeReports[i].report, label: spokeLabels[i]});
      _setupSpokeRoles({logger: logger, report: spokeReports[i].report, accessManager: authority});
    }
    logger.logNewLine();
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

  function _deployConfiguratorBatch(
    Logger logger,
    address hubConfiguratorAuthority,
    address spokeConfiguratorAuthority,
    bytes32 salt
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.logHeader1('deploying ConfiguratorBatch');

    report = AaveV4DeployBase.deployConfiguratorBatch({
      hubConfiguratorAuthority: hubConfiguratorAuthority,
      spokeConfiguratorAuthority: spokeConfiguratorAuthority,
      salt: salt
    });

    logger.log('HubConfigurator', report.hubConfigurator);
    logger.log('SpokeConfigurator', report.spokeConfigurator);
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

  function _deployPositionManagerBatch(
    Logger logger,
    address positionManagerOwner,
    bytes32 salt
  ) internal returns (BatchReports.PositionManagerBatchReport memory report) {
    logger.logHeader1('deploying PositionManagerBatch');
    report = AaveV4DeployBase.deployPositionManagerBatch({owner: positionManagerOwner, salt: salt});
    logger.logDetail('GiverPositionManager', report.giverPositionManager);
    logger.logDetail('TakerPositionManager', report.takerPositionManager);
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
      hubConfigurator: report.configuratorBatchReport.hubConfigurator
    });

    logger.logHeader1('setting SpokeConfigurator roles');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles({
      accessManager: report.authorityBatchReport.accessManager,
      spokeConfigurator: report.configuratorBatchReport.spokeConfigurator
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
      report.configuratorBatchReport.hubConfigurator
    );
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: report.configuratorBatchReport.hubConfigurator
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
      report.configuratorBatchReport.spokeConfigurator
    );
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: report.configuratorBatchReport.spokeConfigurator
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
