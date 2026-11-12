// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4AccessManagerEnumerableDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';
import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';
import {AaveV4ConfigPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4ConfigPositionManagerDeployProcedure.sol';
import {AaveV4GiverPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4GiverPositionManagerDeployProcedure.sol';
import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';
import {AaveV4TakerPositionManagerDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4TakerPositionManagerDeployProcedure.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';
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
  /// @return report The full deployment report containing all deployed addresses.
  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs,
    bytes memory hubBytecode,
    bytes memory spokeBytecode
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    bytes32 salt = _deriveSalt({deployer: deployer, salt: deployInputs.salt});
    report.salt = deployInputs.salt;

    // Deploy AccessManager
    // initialize with deployer as access manager admin
    address initialAdmin = deployer;
    report.accessManager = _deployAuthority({
      logger: logger,
      accessManagerAdmin: initialAdmin,
      salt: salt
    });

    address accessManager = report.accessManager;

    // Label all protocol roles
    logger.logHeader1('labeling roles');
    AaveV4AccessManagerRolesProcedure.labelAllRoles(accessManager);

    // Deploy Configurators with AccessManager as authority
    (report.hubConfigurator, report.spokeConfigurator) = _deployConfigurators({
      logger: logger,
      hubConfiguratorAuthority: accessManager,
      spokeConfiguratorAuthority: accessManager,
      salt: salt
    });

    // Setup Configurator Roles
    _setupConfiguratorRoles({logger: logger, report: report});

    // Deploy TreasurySpoke (single instance for all hubs)
    report.treasurySpoke = _deployTreasurySpoke({
      logger: logger,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      salt: salt
    });

    // Validate label uniqueness (duplicate labels produce identical CREATE2 salts)
    InputUtils.validateUniqueLabels(deployInputs.hubLabels, 'hub');
    InputUtils.validateUniqueLabels(deployInputs.spokeLabels, 'spoke');

    // Deploy Hubs
    report.hubs = _deployHubs({
      logger: logger,
      proxyAdminOwner: deployInputs.proxyAdminOwner,
      authority: accessManager,
      hubLabels: deployInputs.hubLabels,
      hubBytecode: hubBytecode,
      salt: salt
    });

    // Deploy Spokes
    report.spokes = _deploySpokes({
      logger: logger,
      deployer: deployer,
      authority: accessManager,
      inputs: deployInputs,
      spokeBytecode: spokeBytecode,
      salt: salt
    });

    // Deploy Gateways if either gateway flag is enabled
    if (deployInputs.deployNativeTokenGateway || deployInputs.deploySignatureGateway) {
      (report.signatureGateway, report.nativeGateway) = _deployGateways({
        logger: logger,
        gatewayOwner: deployInputs.gatewayOwner,
        nativeWrapper: deployInputs.nativeWrapper,
        deployNativeTokenGateway: deployInputs.deployNativeTokenGateway,
        deploySignatureGateway: deployInputs.deploySignatureGateway,
        salt: salt
      });
    }

    // Deploy Position Managers if flag is enabled
    if (deployInputs.deployPositionManagers) {
      (
        report.giverPositionManager,
        report.takerPositionManager,
        report.configPositionManager
      ) = _deployPositionManagers({
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

  function _deployHubs(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    string[] memory hubLabels,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubReports) {
    uint256 hubCount = hubLabels.length;
    hubReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'hub', hubLabels[i]);
      hubReports[i] = _deployHub({
        logger: logger,
        proxyAdminOwner: proxyAdminOwner,
        authority: authority,
        label: hubLabels[i],
        hubBytecode: hubBytecode,
        salt: childSalt
      });
    }
    logger.logNewLine();
    return hubReports;
  }

  function _deployHub(
    Logger logger,
    address proxyAdminOwner,
    address authority,
    string memory label,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport memory report) {
    report.label = label;
    logger.logHeader1('deploying Hub');
    (report.hubProxy, report.hubImplementation) = AaveV4HubDeployProcedure
      .deployUpgradeableHubInstance({
        proxyAdminOwner: proxyAdminOwner,
        authority: authority,
        hubBytecode: hubBytecode,
        salt: salt
      });
    logger.logHeader1('deploying InterestRateStrategy');
    report.irStrategy = AaveV4InterestRateStrategyDeployProcedure.deployInterestRateStrategy({
      hub: report.hubProxy,
      salt: salt
    });

    _logHubReport({logger: logger, report: report});
    _setupHubRoles({logger: logger, hub: report.hubProxy, accessManager: authority});

    return report;
  }

  function _deploySpokes(
    Logger logger,
    address deployer,
    address authority,
    InputUtils.FullDeployInputs memory inputs,
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeReports) {
    uint256 spokeCount = inputs.spokeLabels.length;
    uint256 limitsLen = inputs.spokeMaxReservesLimits.length;
    require(limitsLen == spokeCount || limitsLen == 0, 'spoke labels/limits length mismatch');
    spokeReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'spoke', inputs.spokeLabels[i]);
      spokeReports[i] = _deploySpoke({
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
    return spokeReports;
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
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory report) {
    report.label = label;
    // The Spoke implementation takes the oracle in its constructor, and only the oracle's deployer can
    // call `AaveOracle.setSpoke`, so the oracle comes first through an AaveV4AaveOracleDeployer owned by
    // the deployer, and is bound once the Spoke proxy exists.
    logger.logHeader1('deploying AaveOracle');
    address aaveOracleDeployer;
    (aaveOracleDeployer, report.aaveOracle) = AaveV4AaveOracleDeployProcedure.deployAaveOracle({
      owner: deployer,
      decimals: oracleDecimals,
      salt: salt
    });
    logger.logHeader1('deploying Spoke');
    (report.spokeProxy, report.spokeImplementation) = AaveV4SpokeDeployProcedure
      .deployUpgradeableSpokeInstance({
        proxyAdminOwner: proxyAdminOwner,
        authority: authority,
        oracle: report.aaveOracle,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: maxUserReservesLimit,
        salt: salt
      });
    logger.logHeader1('setting AaveOracle spoke');
    AaveV4AaveOracleDeployProcedure.setAaveOracleSpoke({
      aaveOracleDeployer: aaveOracleDeployer,
      spoke: report.spokeProxy
    });

    _logSpokeReport({logger: logger, report: report});
    _setupSpokeRoles({logger: logger, spoke: report.spokeProxy, accessManager: authority});

    return report;
  }

  function _deployAuthority(
    Logger logger,
    address accessManagerAdmin,
    bytes32 salt
  ) internal returns (address accessManager) {
    logger.logHeader1('deploying AccessManager');

    accessManager = AaveV4AccessManagerEnumerableDeployProcedure.deployAccessManagerEnumerable({
      admin: accessManagerAdmin,
      salt: salt
    });

    logger.log('AccessManager', accessManager);
    logger.logNewLine();
    return accessManager;
  }

  function _deployConfigurators(
    Logger logger,
    address hubConfiguratorAuthority,
    address spokeConfiguratorAuthority,
    bytes32 salt
  ) internal returns (address hubConfigurator, address spokeConfigurator) {
    logger.logHeader1('deploying HubConfigurator');
    hubConfigurator = AaveV4HubConfiguratorDeployProcedure.deployHubConfigurator({
      authority: hubConfiguratorAuthority,
      salt: salt
    });
    logger.logHeader1('deploying SpokeConfigurator');
    spokeConfigurator = AaveV4SpokeConfiguratorDeployProcedure.deploySpokeConfigurator({
      authority: spokeConfiguratorAuthority,
      salt: salt
    });

    logger.log('HubConfigurator', hubConfigurator);
    logger.log('SpokeConfigurator', spokeConfigurator);
    logger.logNewLine();
    return (hubConfigurator, spokeConfigurator);
  }

  function _deployTreasurySpoke(
    Logger logger,
    address treasurySpokeOwner,
    bytes32 salt
  ) internal returns (address treasurySpoke) {
    logger.logHeader1('deploying TreasurySpoke');
    treasurySpoke = AaveV4TreasurySpokeDeployProcedure.deployTreasurySpoke({
      owner: treasurySpokeOwner,
      salt: salt
    });
    logger.log('TreasurySpoke', treasurySpoke);
    logger.logNewLine();
    return treasurySpoke;
  }

  function _deployGateways(
    Logger logger,
    address gatewayOwner,
    address nativeWrapper,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway,
    bytes32 salt
  ) internal returns (address signatureGateway, address nativeGateway) {
    if (deployNativeTokenGateway) {
      logger.logHeader1('deploying NativeTokenGateway');
      nativeGateway = AaveV4NativeTokenGatewayDeployProcedure.deployNativeTokenGateway({
        nativeWrapper: nativeWrapper,
        owner: gatewayOwner,
        salt: salt
      });
      logger.log('NativeTokenGateway', nativeGateway);
    }
    if (deploySignatureGateway) {
      logger.logHeader1('deploying SignatureGateway');
      signatureGateway = AaveV4SignatureGatewayDeployProcedure.deploySignatureGateway({
        owner: gatewayOwner,
        salt: salt
      });
      logger.log('SignatureGateway', signatureGateway);
    }
    return (signatureGateway, nativeGateway);
  }

  function _deployPositionManagers(
    Logger logger,
    address positionManagerOwner,
    bytes32 salt
  )
    internal
    returns (
      address giverPositionManager,
      address takerPositionManager,
      address configPositionManager
    )
  {
    logger.logHeader1('deploying PositionManagers');
    giverPositionManager = AaveV4GiverPositionManagerDeployProcedure.deployGiverPositionManager({
      owner: positionManagerOwner,
      salt: salt
    });
    takerPositionManager = AaveV4TakerPositionManagerDeployProcedure.deployTakerPositionManager({
      owner: positionManagerOwner,
      salt: salt
    });
    configPositionManager = AaveV4ConfigPositionManagerDeployProcedure.deployConfigPositionManager({
      owner: positionManagerOwner,
      salt: salt
    });
    logger.logDetail('GiverPositionManager', giverPositionManager);
    logger.logDetail('TakerPositionManager', takerPositionManager);
    logger.logDetail('ConfigPositionManager', configPositionManager);
    return (giverPositionManager, takerPositionManager, configPositionManager);
  }

  /// @dev Setup roles for the hub and spoke configurators.
  function _setupConfiguratorRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report
  ) internal {
    logger.logHeader1('setting HubConfigurator roles');
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles({
      accessManager: report.accessManager,
      hubConfigurator: report.hubConfigurator
    });

    logger.logHeader1('setting SpokeConfigurator roles');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles({
      accessManager: report.accessManager,
      spokeConfigurator: report.spokeConfigurator
    });
  }

  function _setupSpokeRoles(Logger logger, address spoke, address accessManager) internal {
    logger.logHeader1('setting Spoke roles');
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles({accessManager: accessManager, spoke: spoke});
  }

  function _setupHubRoles(Logger logger, address hub, address accessManager) internal {
    logger.logHeader1('setting Hub roles');
    AaveV4HubRolesProcedure.setupHubAllRoles({accessManager: accessManager, hub: hub});
  }

  function _grantHubRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address hubAdmin,
    address hubConfiguratorAdmin
  ) internal {
    address accessManager = report.accessManager;

    logger.logHeader1('granting Hub Admin role to', hubAdmin);
    AaveV4HubRolesProcedure.grantHubAllRoles({accessManager: accessManager, admin: hubAdmin});

    logger.logHeader1('granting Hub Configurator roles to', report.hubConfigurator);
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: report.hubConfigurator
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
    address accessManager = report.accessManager;

    logger.logHeader1('granting Spoke Admin role to', spokeAdmin);
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles({accessManager: accessManager, admin: spokeAdmin});

    logger.logHeader1('granting Spoke Configurator roles to', report.spokeConfigurator);
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: report.spokeConfigurator
    });

    logger.logHeader1('granting SpokeConfigurator Admin roles to', spokeConfiguratorAdmin);
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: spokeConfiguratorAdmin
    });
  }

  function _logHubReport(
    Logger logger,
    OrchestrationReports.HubDeploymentReport memory report
  ) internal pure {
    logger.log(report.label);
    logger.logDetail('Hub', report.hubProxy);
    logger.logDetail('HubImpl', report.hubImplementation);
    logger.logDetail('InterestRateStrategy', report.irStrategy);
  }

  function _logSpokeReport(
    Logger logger,
    OrchestrationReports.SpokeDeploymentReport memory report
  ) internal pure {
    logger.log(report.label);
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
