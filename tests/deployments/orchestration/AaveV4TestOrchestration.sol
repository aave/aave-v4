// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {TestTypes} from 'tests/utils/TestTypes.sol';
import {Constants} from 'tests/Constants.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4TreasurySpokeBatch} from 'src/deployments/batches/AaveV4TreasurySpokeBatch.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {AaveV4HubInstanceBatch} from 'src/deployments/batches/AaveV4HubInstanceBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {TestTokensBatch} from 'tests/deployments/batches/TestTokensBatch.sol';
import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

library AaveV4TestOrchestration {
  bool public constant IS_TEST = true;
  bytes internal constant CREATE2_FACTORY_BYTECODE =
    hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  error Create2DeploymentFailed();

  function deployTestTokens(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) external returns (TestTypes.TokenList memory) {
    TestTypes.TestTokensReport memory tokensReport = _deployTestTokensBatch(tokenInputs);

    TestTypes.TokenList memory tokenList;
    tokenList.weth = WETH9(payable(tokensReport.weth));
    tokenList.usdx = TestnetERC20(tokensReport.testTokens[0]);
    tokenList.dai = TestnetERC20(tokensReport.testTokens[1]);
    tokenList.wbtc = TestnetERC20(tokensReport.testTokens[2]);
    tokenList.usdy = TestnetERC20(tokensReport.testTokens[3]);
    tokenList.usdz = TestnetERC20(tokensReport.testTokens[4]);
    return tokenList;
  }

  function deployTestEnv(
    address admin,
    address treasuryAdmin,
    uint256 hubCount,
    uint256 spokeCount,
    address nativeWrapper,
    bytes memory hubBytecode,
    bytes memory spokeBytecode,
    bytes32 salt
  ) external returns (TestTypes.TestEnvReport memory) {
    TestTypes.TestEnvReport memory report;

    report.hubReports = new TestTypes.TestHubReport[](hubCount);
    report.spokeReports = new TestTypes.TestSpokeReport[](spokeCount);

    // Deploy Access Batch
    report.accessManager = AaveV4DeployBase
      .deployAuthorityBatch({admin: admin, salt: salt})
      .accessManager;

    // Deploy TreasurySpoke Batch (single instance for all hubs)
    report.treasurySpoke = AaveV4DeployBase
      .deployTreasurySpokeBatch({
        owner: treasuryAdmin,
        salt: keccak256(abi.encodePacked(salt, 'treasurySpoke'))
      })
      .treasurySpoke;

    // Deploy Hub Batches
    for (uint256 i; i < hubCount; ++i) {
      BatchReports.HubInstanceBatchReport memory hubReport = AaveV4DeployBase
        .deployHubInstanceBatch({
          hubProxyAdminOwner: admin,
          authority: report.accessManager,
          hubBytecode: hubBytecode,
          salt: keccak256(abi.encodePacked(salt, 'hub-', string(abi.encode(i))))
        });
      report.hubReports[i].hub = hubReport.hubProxy;
      report.hubReports[i].irStrategy = hubReport.irStrategy;
    }

    // Deploy Spoke Instance Batches
    for (uint256 i; i < spokeCount; ++i) {
      BatchReports.SpokeInstanceBatchReport memory spokeReport = AaveV4DeployBase
        .deploySpokeInstanceBatch({
          spokeProxyAdminOwner: admin,
          authority: report.accessManager,
          spokeBytecode: spokeBytecode,
          oracleDecimals: Constants.ORACLE_DECIMALS,
          maxUserReservesLimit: Constants.MAX_ALLOWED_USER_RESERVES_LIMIT,
          salt: keccak256(abi.encodePacked(salt, 'spoke-', string(abi.encode(i))))
        });
      report.spokeReports[i].spoke = spokeReport.spokeProxy;
      report.spokeReports[i].aaveOracle = spokeReport.aaveOracle;
    }

    // Deploy Configurator Batches with AccessManager as authority
    BatchReports.ConfiguratorBatchReport memory configuratorReport = AaveV4DeployBase
      .deployConfiguratorBatch({
        hubConfiguratorAuthority: report.accessManager,
        spokeConfiguratorAuthority: report.accessManager,
        salt: keccak256(abi.encodePacked(salt, 'configurator'))
      });
    report.configuratorReport.hubConfigurator = configuratorReport.hubConfigurator;
    report.configuratorReport.spokeConfigurator = configuratorReport.spokeConfigurator;

    // Deploy Gateways Batch
    BatchReports.GatewaysBatchReport memory gatewaysReport = AaveV4DeployBase.deployGatewaysBatch({
      owner: admin,
      nativeWrapper: nativeWrapper,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      salt: keccak256(abi.encodePacked(salt, 'gateways'))
    });
    report.gatewaysReport.signatureGateway = gatewaysReport.signatureGateway;
    report.gatewaysReport.nativeGateway = gatewaysReport.nativeGateway;

    return report;
  }

  function deployTestHub(
    address hubProxyAdminOwner,
    address accessManager,
    bytes memory hubBytecode,
    string memory label,
    bytes32 salt
  ) external returns (TestTypes.TestHubReport memory) {
    TestTypes.TestHubReport memory report;
    BatchReports.HubInstanceBatchReport memory hubReport = AaveV4DeployBase.deployHubInstanceBatch({
      hubProxyAdminOwner: hubProxyAdminOwner,
      authority: accessManager,
      hubBytecode: hubBytecode,
      salt: keccak256(abi.encodePacked(salt, 'hub-', label))
    });
    report.hub = hubReport.hubProxy;
    report.irStrategy = hubReport.irStrategy;

    return report;
  }

  function deployTestSpoke(
    address spokeProxyAdminOwner,
    address accessManager,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (TestTypes.TestSpokeReport memory) {
    TestTypes.TestSpokeReport memory report;
    BatchReports.SpokeInstanceBatchReport memory spokeReport = AaveV4DeployBase
      .deploySpokeInstanceBatch({
        spokeProxyAdminOwner: spokeProxyAdminOwner,
        authority: accessManager,
        spokeBytecode: spokeBytecode,
        oracleDecimals: Constants.ORACLE_DECIMALS,
        maxUserReservesLimit: maxUserReservesLimit,
        salt: salt
      });
    report.spoke = spokeReport.spokeProxy;
    report.aaveOracle = spokeReport.aaveOracle;
    return report;
  }

  function deployTestTokenizationSpoke(
    address hub,
    address underlying,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address tokenizationSpokeProxy) {
    BatchReports.TokenizationSpokeBatchReport memory report = AaveV4DeployBase
      .deployTokenizationSpokeBatch({
        hub: hub,
        underlying: underlying,
        spokeProxyAdminOwner: spokeProxyAdminOwner,
        shareName: shareName,
        shareSymbol: shareSymbol,
        salt: salt
      });
    return report.tokenizationSpokeProxy;
  }

  function deployTestTreasurySpoke(
    address owner,
    bytes32 salt
  ) external returns (address treasurySpoke) {
    return AaveV4DeployBase.deployTreasurySpokeBatch({owner: owner, salt: salt}).treasurySpoke;
  }

  function configureHubsSpokes(ConfigData.AddSpokeParams[] memory paramsList) external {
    for (uint256 i; i < paramsList.length; ++i) {
      IHub(paramsList[i].hub).addSpoke({
        assetId: paramsList[i].assetId,
        spoke: paramsList[i].spoke,
        params: paramsList[i].config
      });
    }
  }

  function configureSpokes(
    ConfigData.UpdateLiquidationConfigParams[] memory liquidationParamsList,
    ConfigData.AddReserveParams[] memory reserveParamsList
  ) external returns (TestTypes.SpokeReserveId[] memory) {
    for (uint256 i; i < liquidationParamsList.length; ++i) {
      ISpoke(liquidationParamsList[i].spoke).updateLiquidationConfig(
        liquidationParamsList[i].config
      );
    }
    TestTypes.SpokeReserveId[] memory spokeReserveIds = new TestTypes.SpokeReserveId[](
      reserveParamsList.length
    );
    for (uint256 i; i < reserveParamsList.length; ++i) {
      spokeReserveIds[i] = TestTypes.SpokeReserveId({
        spoke: reserveParamsList[i].spoke,
        reserveId: ISpoke(reserveParamsList[i].spoke).addReserve({
          hub: reserveParamsList[i].hub,
          assetId: reserveParamsList[i].assetId,
          priceSource: reserveParamsList[i].priceSource,
          config: reserveParamsList[i].config,
          dynamicConfig: reserveParamsList[i].dynamicConfig
        })
      });
    }
    return spokeReserveIds;
  }

  function setRolesTestEnv(TestTypes.TestEnvReport memory report) public {
    // Set Hub Roles
    for (uint256 i; i < report.hubReports.length; ++i) {
      AaveV4HubRolesProcedure.setupHubAllRoles(report.accessManager, report.hubReports[i].hub);
    }

    // Set Spoke Roles
    for (uint256 i; i < report.spokeReports.length; ++i) {
      AaveV4SpokeRolesProcedure.setupSpokeAllRoles(
        report.accessManager,
        report.spokeReports[i].spoke
      );
    }

    // Set Configurator Roles
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles(
      report.accessManager,
      report.configuratorReport.hubConfigurator
    );
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles(
      report.accessManager,
      report.configuratorReport.spokeConfigurator
    );
  }

  function setupHubRolesTestEnv(
    TestTypes.TestHubReport memory report,
    address accessManager
  ) public {
    AaveV4HubRolesProcedure.setupHubAllRoles(accessManager, report.hub);
  }

  function grantRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address hubAdmin,
    address spokeAdmin
  ) public {
    grantHubRolesTestEnv(report, admin, hubAdmin);
    grantSpokeRolesTestEnv(report, admin, spokeAdmin);
  }

  function grantHubRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address hubAdmin
  ) public {
    // grant Hub Admin roles
    AaveV4HubRolesProcedure.grantHubAllRoles(report.accessManager, admin);
    AaveV4HubRolesProcedure.grantHubAllRoles(report.accessManager, hubAdmin);

    // grant Hub Configurator role
    AaveV4HubRolesProcedure.grantHubRole(
      report.accessManager,
      Roles.HUB_CONFIGURATOR_ROLE,
      report.configuratorReport.hubConfigurator
    );

    // grant HubConfigurator Admin roles (allows admin to call HubConfigurator functions)
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(report.accessManager, admin);
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(
      report.accessManager,
      hubAdmin
    );
  }

  function grantSpokeRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address spokeAdmin
  ) public {
    // grant Spoke roles
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles(report.accessManager, admin);
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles(report.accessManager, spokeAdmin);

    // grant Spoke Configurator roles (allows SpokeConfigurator to call Spoke functions)
    AaveV4SpokeRolesProcedure.grantSpokeRole(
      report.accessManager,
      Roles.SPOKE_CONFIGURATOR_ROLE,
      report.configuratorReport.spokeConfigurator
    );

    // grant SpokeConfigurator Admin roles (allows admin to call SpokeConfigurator functions)
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      report.accessManager,
      admin
    );
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      report.accessManager,
      spokeAdmin
    );
  }

  function configureHubsAssets(
    ConfigData.AddAssetParams[] memory paramsList
  ) public returns (uint256[] memory) {
    uint256[] memory assetIds = new uint256[](paramsList.length);
    for (uint256 i; i < paramsList.length; ++i) {
      assetIds[i] = IHub(paramsList[i].hub).addAsset({
        underlying: paramsList[i].underlying,
        decimals: paramsList[i].decimals,
        feeReceiver: paramsList[i].feeReceiver,
        irStrategy: paramsList[i].irStrategy,
        irData: paramsList[i].irData
      });
      if (paramsList[i].liquidityFee > 0 || paramsList[i].reinvestmentController != address(0)) {
        IHub(paramsList[i].hub).updateAssetConfig({
          assetId: assetIds[i],
          config: IHub.AssetConfig({
            liquidityFee: paramsList[i].liquidityFee,
            feeReceiver: paramsList[i].feeReceiver,
            irStrategy: paramsList[i].irStrategy,
            reinvestmentController: paramsList[i].reinvestmentController
          }),
          irData: bytes('')
        });
      }
    }
    return assetIds;
  }

  function configureHubsAssetsViaConfigurator(
    ConfigData.AddAssetParams[] memory paramsList,
    address hubConfigurator
  ) public returns (uint256[] memory) {
    uint256[] memory assetIds = new uint256[](paramsList.length);
    for (uint256 i; i < paramsList.length; ++i) {
      assetIds[i] = IHubConfigurator(hubConfigurator).addAssetWithDecimals({
        hub: paramsList[i].hub,
        underlying: paramsList[i].underlying,
        decimals: paramsList[i].decimals,
        feeReceiver: paramsList[i].feeReceiver,
        liquidityFee: paramsList[i].liquidityFee,
        irStrategy: paramsList[i].irStrategy,
        irData: paramsList[i].irData
      });
    }
    return assetIds;
  }

  function _deployTestTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensReport memory) {
    TestTypes.TestTokensReport memory report;

    report.testTokens = new address[](tokenInputs.length);

    // Deploy Test Tokens Batch
    TestTypes.TestTokensBatchReport memory tokensReport = _deployTokensBatch(tokenInputs);
    report.weth = tokensReport.weth;
    report.testTokens = tokensReport.tokens;

    return report;
  }

  function _deployTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensBatchReport memory) {
    TestTokensBatch tokensBatch = new TestTokensBatch(tokenInputs);
    return tokensBatch.getReport();
  }

  function loadCreate2Factory() internal {
    if (Create2Utils.isContractDeployed(Create2Utils.CREATE2_FACTORY)) return;
    vm.etch(Create2Utils.CREATE2_FACTORY, CREATE2_FACTORY_BYTECODE);
  }

  function _create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    loadCreate2Factory();
    address computed = Create2Utils.computeCreate2Address(salt, bytecode);
    if (Create2Utils.isContractDeployed(computed)) return computed;

    bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
    (, bytes memory returnData) = Create2Utils.CREATE2_FACTORY.call(creationBytecode);
    address deployedAt = address(uint160(bytes20(returnData)));
    require(deployedAt == computed, Create2DeploymentFailed());
    return deployedAt;
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal returns (ISpokeInstance) {
    return deploySpokeImplementation(oracle, maxUserReservesLimit, '');
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (ISpokeInstance) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle, maxUserReservesLimit)
    );
    return ISpokeInstance(_create2Deploy(salt, initCode));
  }

  function deployHubImplementation() internal returns (IHubInstance) {
    return deployHubImplementation('');
  }

  function deployHubImplementation(bytes32 salt) internal returns (IHubInstance) {
    bytes memory initCode = vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
    return IHubInstance(_create2Deploy(salt, initCode));
  }
  function deployHub(address authority, address proxyAdminOwner) internal returns (IHub) {
    return
      IHub(
        proxify(
          address(deployHubImplementation()),
          proxyAdminOwner,
          abi.encodeCall(IHubInstance.initialize, (authority))
        )
      );
  }

  function proxify(
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    return address(new TransparentUpgradeableProxy(impl, proxyAdminOwner, initData));
  }
}
