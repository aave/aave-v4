// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {TestTypes} from 'tests/utils/TestTypes.sol';
import {TestnetERC20} from 'tests/helpers/mocks/TestnetERC20.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {ConfigData} from 'tests/utils/ConfigData.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {HubSpokeFactory} from 'src/deployments/factory/HubSpokeFactory.sol';
import {IHubSpokeFactory} from 'src/deployments/factory/interfaces/IHubSpokeFactory.sol';
import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
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

    // Deploy Access Batch
    report.accessManager = AaveV4DeployBase
      .deployAuthorityBatch({admin: admin, salt: salt})
      .accessManager;

    // Deploy canonical implementations and the HubSpokeFactory bound to them
    IHubSpokeFactory factory = _deployTestEnvFactory(hubBytecode, spokeBytecode, salt);

    // Deploy TreasurySpoke (single instance for all hubs)
    report.treasurySpoke = factory.deployTreasurySpoke({
      salt: keccak256(abi.encodePacked(salt, 'treasurySpoke')),
      owner: treasuryAdmin,
      proxyAdminOwner: treasuryAdmin
    });

    // Deploy Hubs and Spokes
    report.hubReports = _deployTestEnvHubs(factory, report.accessManager, admin, hubCount, salt);
    report.spokeReports = _deployTestEnvSpokes(
      factory,
      report.accessManager,
      admin,
      spokeCount,
      salt
    );

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

  function _deployTestEnvFactory(
    bytes memory hubBytecode,
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (IHubSpokeFactory) {
    return
      IHubSpokeFactory(
        AaveV4DeployBase
          .deployHubSpokeFactoryBatch({
            hubImplementation: AaveV4DeployBase
              .deployHubImplementationBatch({hubBytecode: hubBytecode, salt: salt})
              .hubImplementation,
            spokeImplementation: AaveV4DeployBase
              .deploySpokeImplementationBatch({spokeBytecode: spokeBytecode, salt: salt})
              .spokeImplementation,
            tokenizationSpokeImplementation: AaveV4DeployBase
              .deployTokenizationSpokeImplementationBatch({salt: salt})
              .tokenizationSpokeImplementation,
            salt: salt
          })
          .hubSpokeFactory
      );
  }

  function _deployTestEnvHubs(
    IHubSpokeFactory factory,
    address accessManager,
    address admin,
    uint256 hubCount,
    bytes32 salt
  ) internal returns (TestTypes.TestHubReport[] memory hubReports) {
    hubReports = new TestTypes.TestHubReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      IHubSpokeFactory.HubDeployment memory hubDeployment = factory.deployHub({
        salt: keccak256(abi.encodePacked(salt, 'hub-', string(abi.encode(i)))),
        authority: accessManager,
        proxyAdminOwner: admin
      });
      hubReports[i].hub = hubDeployment.proxy;
      hubReports[i].irStrategy = hubDeployment.irStrategy;
    }
  }

  function _deployTestEnvSpokes(
    IHubSpokeFactory factory,
    address accessManager,
    address admin,
    uint256 spokeCount,
    bytes32 salt
  ) internal returns (TestTypes.TestSpokeReport[] memory spokeReports) {
    spokeReports = new TestTypes.TestSpokeReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      IHubSpokeFactory.SpokeDeployment memory spokeDeployment = factory.deploySpoke({
        salt: keccak256(abi.encodePacked(salt, 'spoke-', string(abi.encode(i)))),
        authority: accessManager,
        proxyAdminOwner: admin
      });
      spokeReports[i].spoke = spokeDeployment.proxy;
      spokeReports[i].aaveOracle = spokeDeployment.oracle;
    }
  }

  function deployTestHub(
    address proxyAdminOwner,
    address accessManager,
    string memory label,
    bytes32 salt
  ) external returns (TestTypes.TestHubReport memory report) {
    IHubSpokeFactory.HubDeployment memory hubDeployment = deployTestFactory().deployHub({
      salt: keccak256(abi.encodePacked(salt, 'hub-', label)),
      authority: accessManager,
      proxyAdminOwner: proxyAdminOwner
    });
    report.hub = hubDeployment.proxy;
    report.irStrategy = hubDeployment.irStrategy;
  }

  function deployTestSpoke(
    address proxyAdminOwner,
    address accessManager,
    bytes32 salt
  ) external returns (TestTypes.TestSpokeReport memory report) {
    IHubSpokeFactory.SpokeDeployment memory spokeDeployment = deployTestFactory().deploySpoke({
      salt: salt,
      authority: accessManager,
      proxyAdminOwner: proxyAdminOwner
    });
    report.spoke = spokeDeployment.proxy;
    report.aaveOracle = spokeDeployment.oracle;
  }

  function deployTestTreasurySpoke(
    address owner,
    bytes32 salt
  ) external returns (address treasurySpoke) {
    return
      deployTestFactory().deployTreasurySpoke({salt: salt, owner: owner, proxyAdminOwner: owner});
  }

  /// @dev Deploys, or returns when already deployed, a HubSpokeFactory bound to the canonical implementations.
  function deployTestFactory() internal returns (IHubSpokeFactory) {
    return
      IHubSpokeFactory(
        _create2Deploy(
          '',
          abi.encodePacked(
            type(HubSpokeFactory).creationCode,
            abi.encode(
              deployHubImplementation(),
              deploySpokeImplementation(),
              _create2Deploy('', type(TreasurySpokeInstance).creationCode),
              _create2Deploy('', type(TokenizationSpokeInstance).creationCode)
            )
          )
        )
      );
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

  function deploySpokeImplementation() internal returns (ISpokeInstance) {
    return deploySpokeImplementation('');
  }

  function deploySpokeImplementation(bytes32 salt) internal returns (ISpokeInstance) {
    return
      ISpokeInstance(
        _create2Deploy(salt, vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'))
      );
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
