// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {TestTypes} from 'tests/utils/TestTypes.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';
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
import {TestTokensBatch} from 'tests/deployments/batches/TestTokensBatch.sol';
import {AaveV4AccessManagerEnumerableDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';
import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';
import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';
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

    // Deploy AccessManager
    report.accessManager = AaveV4AccessManagerEnumerableDeployProcedure
      .deployAccessManagerEnumerable({admin: admin, salt: salt});

    // Deploy TreasurySpoke (single instance for all hubs)
    report.treasurySpoke = AaveV4TreasurySpokeDeployProcedure.deployTreasurySpoke({
      owner: treasuryAdmin,
      salt: keccak256(abi.encodePacked(salt, 'treasurySpoke'))
    });

    // Deploy Hubs
    for (uint256 i; i < hubCount; ++i) {
      report.hubReports[i] = _deployHub({
        proxyAdminOwner: admin,
        authority: report.accessManager,
        hubBytecode: hubBytecode,
        salt: keccak256(abi.encodePacked(salt, 'hub-', string(abi.encode(i))))
      });
    }

    // Deploy Spokes
    for (uint256 i; i < spokeCount; ++i) {
      report.spokeReports[i] = _deploySpoke({
        proxyAdminOwner: admin,
        authority: report.accessManager,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
        salt: keccak256(abi.encodePacked(salt, 'spoke-', string(abi.encode(i))))
      });
    }

    // Deploy Configurators with AccessManager as authority
    bytes32 configuratorSalt = keccak256(abi.encodePacked(salt, 'configurator'));
    report.configuratorReport.hubConfigurator = AaveV4HubConfiguratorDeployProcedure
      .deployHubConfigurator({authority: report.accessManager, salt: configuratorSalt});
    report.configuratorReport.spokeConfigurator = AaveV4SpokeConfiguratorDeployProcedure
      .deploySpokeConfigurator({authority: report.accessManager, salt: configuratorSalt});

    // Deploy Gateways
    bytes32 gatewaysSalt = keccak256(abi.encodePacked(salt, 'gateways'));
    report.gatewaysReport.nativeGateway = AaveV4NativeTokenGatewayDeployProcedure
      .deployNativeTokenGateway({nativeWrapper: nativeWrapper, owner: admin, salt: gatewaysSalt});
    report.gatewaysReport.signatureGateway = AaveV4SignatureGatewayDeployProcedure
      .deploySignatureGateway({owner: admin, salt: gatewaysSalt});

    return report;
  }

  function deployTestHub(
    address proxyAdminOwner,
    address accessManager,
    bytes memory hubBytecode,
    string memory label,
    bytes32 salt
  ) external returns (TestTypes.TestHubReport memory) {
    return
      _deployHub({
        proxyAdminOwner: proxyAdminOwner,
        authority: accessManager,
        hubBytecode: hubBytecode,
        salt: keccak256(abi.encodePacked(salt, 'hub-', label))
      });
  }

  function deployTestSpoke(
    address proxyAdminOwner,
    address accessManager,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) external returns (TestTypes.TestSpokeReport memory) {
    return
      _deploySpoke({
        proxyAdminOwner: proxyAdminOwner,
        authority: accessManager,
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: maxUserReservesLimit,
        salt: salt
      });
  }

  function deployTestTokenizationSpoke(
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) external returns (address tokenizationSpokeProxy) {
    (tokenizationSpokeProxy, ) = AaveV4TokenizationSpokeDeployProcedure
      .deployUpgradeableTokenizationSpokeInstance({
        hub: hub,
        underlying: underlying,
        proxyAdminOwner: proxyAdminOwner,
        shareName: shareName,
        shareSymbol: shareSymbol,
        salt: salt
      });
  }

  function deployTestTreasurySpoke(
    address owner,
    bytes32 salt
  ) external returns (address treasurySpoke) {
    return AaveV4TreasurySpokeDeployProcedure.deployTreasurySpoke({owner: owner, salt: salt});
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

  function _deployHub(
    address proxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (TestTypes.TestHubReport memory report) {
    (report.hub, ) = AaveV4HubDeployProcedure.deployUpgradeableHubInstance({
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      hubBytecode: hubBytecode,
      salt: salt
    });
    report.irStrategy = AaveV4InterestRateStrategyDeployProcedure.deployInterestRateStrategy({
      hub: report.hub,
      salt: salt
    });
    return report;
  }

  function _deploySpoke(
    address proxyAdminOwner,
    address authority,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (TestTypes.TestSpokeReport memory report) {
    address aaveOracleDeployer;
    (aaveOracleDeployer, report.aaveOracle) = AaveV4AaveOracleDeployProcedure.deployAaveOracle({
      owner: address(this),
      decimals: DeployConstants.ORACLE_DECIMALS,
      salt: salt
    });
    (report.spoke, ) = AaveV4SpokeDeployProcedure.deployUpgradeableSpokeInstance({
      proxyAdminOwner: proxyAdminOwner,
      authority: authority,
      oracle: report.aaveOracle,
      spokeBytecode: spokeBytecode,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
    AaveV4AaveOracleDeployProcedure.setAaveOracleSpoke({
      aaveOracleDeployer: aaveOracleDeployer,
      spoke: report.spoke
    });
    return report;
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
