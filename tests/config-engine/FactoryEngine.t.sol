// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {MockFactoryDeploymentPayload} from 'tests/helpers/mocks/config-engine/MockFactoryDeploymentPayload.sol';

contract FactoryEngineTest is BaseConfigEngineTest {
  /// @dev Per-transaction gas cap on Ethereum mainnet (EIP-7825).
  uint256 internal constant MAINNET_TX_GAS_CAP = 2 ** 24;

  function test_executeHubDeployments() public {
    IAaveV4ConfigEngine.HubDeployment[]
      memory deployments = new IAaveV4ConfigEngine.HubDeployment[](2);
    deployments[0] = IAaveV4ConfigEngine.HubDeployment({
      salt: 'hub-1',
      authority: address(accessManager),
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });
    deployments[1] = IAaveV4ConfigEngine.HubDeployment({
      salt: 'hub-2',
      authority: address(accessManager),
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });

    IHubSpokeFactory.HubDeployment[2] memory predicted;
    for (uint256 i; i < 2; ++i) {
      predicted[i] = factory.predictHub(
        address(engine),
        deployments[i].salt,
        address(accessManager),
        PROXY_ADMIN_OWNER
      );
      vm.expectEmit(address(factory));
      emit IHubSpokeFactory.HubDeployed(
        address(engine),
        predicted[i].proxy,
        predicted[i].irStrategy,
        address(accessManager),
        PROXY_ADMIN_OWNER
      );
    }
    engine.executeHubDeployments(deployments);

    for (uint256 i; i < 2; ++i) {
      assertEq(
        ProxyHelper.getImplementation(predicted[i].proxy),
        factory.getImplementation(IHubSpokeFactory.InstanceType.Hub)
      );
      assertEq(AssetInterestRateStrategy(predicted[i].irStrategy).HUB(), predicted[i].proxy);
    }
  }

  function test_executeSpokeDeployments() public {
    IAaveV4ConfigEngine.SpokeDeployment[]
      memory deployments = new IAaveV4ConfigEngine.SpokeDeployment[](2);
    deployments[0] = IAaveV4ConfigEngine.SpokeDeployment({
      salt: 'spoke-1',
      authority: address(accessManager),
      maxUserReservesLimit: MAX_USER_RESERVES_LIMIT,
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });
    deployments[1] = IAaveV4ConfigEngine.SpokeDeployment({
      salt: 'spoke-2',
      authority: address(accessManager),
      maxUserReservesLimit: MAX_USER_RESERVES_LIMIT,
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });

    IHubSpokeFactory.SpokeDeployment[2] memory predicted;
    for (uint256 i; i < 2; ++i) {
      predicted[i] = factory.predictSpoke(
        address(engine),
        deployments[i].salt,
        address(accessManager),
        MAX_USER_RESERVES_LIMIT,
        PROXY_ADMIN_OWNER
      );
      vm.expectEmit(address(factory));
      emit IHubSpokeFactory.SpokeDeployed(
        address(engine),
        predicted[i].proxy,
        predicted[i].oracle,
        address(accessManager),
        PROXY_ADMIN_OWNER
      );
    }
    engine.executeSpokeDeployments(deployments);

    for (uint256 i; i < 2; ++i) {
      assertEq(
        ProxyHelper.getImplementation(predicted[i].proxy),
        factory.getImplementation(IHubSpokeFactory.InstanceType.Spoke)
      );
      assertEq(ISpoke(predicted[i].proxy).ORACLE(), predicted[i].oracle);
      assertEq(ISpoke(predicted[i].proxy).MAX_USER_RESERVES_LIMIT(), MAX_USER_RESERVES_LIMIT);
      assertEq(IAaveOracle(predicted[i].oracle).spoke(), predicted[i].proxy);
    }
  }

  function test_executeTreasurySpokeDeployments() public {
    IAaveV4ConfigEngine.TreasurySpokeDeployment[]
      memory deployments = new IAaveV4ConfigEngine.TreasurySpokeDeployment[](1);
    deployments[0] = IAaveV4ConfigEngine.TreasurySpokeDeployment({
      salt: 'treasury-spoke',
      owner: ADMIN,
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });

    address predicted = factory.predictTreasurySpoke(
      address(engine),
      deployments[0].salt,
      ADMIN,
      PROXY_ADMIN_OWNER
    );
    vm.expectEmit(address(factory));
    emit IHubSpokeFactory.TreasurySpokeDeployed(
      address(engine),
      predicted,
      ADMIN,
      PROXY_ADMIN_OWNER
    );
    engine.executeTreasurySpokeDeployments(deployments);

    assertEq(
      ProxyHelper.getImplementation(predicted),
      factory.getImplementation(IHubSpokeFactory.InstanceType.TreasurySpoke)
    );
    assertEq(Ownable(predicted).owner(), ADMIN);
  }

  function test_payload_deploysAndWiresInstances() public {
    uint256 spokeCount = 2;
    MockFactoryDeploymentPayload payload = _deployPayload(spokeCount);
    _executePayload(payload);

    // the Executor is the factory caller
    IHubSpokeFactory.HubDeployment memory hubDeployment = payload.predictedHub(address(executor));
    address treasurySpoke = payload.predictedTreasurySpoke(address(executor));
    address[] memory newSpokes = new address[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      newSpokes[i] = payload.predictedSpoke(address(executor), i);
    }

    IHub hub = IHub(hubDeployment.proxy);
    uint256 assetId = hub.getAssetId(address(newToken));
    assertEq(hub.getAssetConfig(assetId).feeReceiver, treasurySpoke);
    assertEq(hub.getAssetConfig(assetId).irStrategy, hubDeployment.irStrategy);

    address tokenizationSpoke = FactoryEngine.predictTokenizationSpoke(
      factory,
      address(executor),
      address(hub),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      PROXY_ADMIN_OWNER
    );
    assertTrue(hub.isSpokeListed(assetId, tokenizationSpoke));
    assertEq(ITokenizationSpoke(tokenizationSpoke).asset(), address(newToken));

    for (uint256 i; i < spokeCount; ++i) {
      assertTrue(hub.isSpokeListed(assetId, newSpokes[i]));
      assertEq(ISpoke(newSpokes[i]).getReserveId(address(hub), assetId), 0);
      assertEq(ISpoke(newSpokes[i]).getReserveCount(), 1);
    }
  }

  /// forge-config: default.isolate = true
  function test_payload_gas_oneSpoke() public {
    _assertPayloadGas(1);
  }

  /// forge-config: default.isolate = true
  function test_payload_gas_fiveSpokes() public {
    _assertPayloadGas(5);
  }

  function _assertPayloadGas(uint256 spokeCount) internal {
    MockFactoryDeploymentPayload payload = _deployPayload(spokeCount);
    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(address(payload), abi.encodeCall(AaveV4Payload.execute, ()));
    uint256 gasUsed = vm.lastCallGas().gasTotalUsed;
    emit log_named_uint(string.concat('payload gas, spokes: ', vm.toString(spokeCount)), gasUsed);
    assertLt(gasUsed, MAINNET_TX_GAS_CAP);
  }

  function _deployPayload(uint256 spokeCount) internal returns (MockFactoryDeploymentPayload) {
    vm.startPrank(ADMIN);
    accessManager.grantRole(Roles.ACCESS_MANAGER_ADMIN_ROLE, address(executor), 0);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(executor), 0);
    accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(executor), 0);
    vm.stopPrank();

    return
      new MockFactoryDeploymentPayload({
        configEngine: IAaveV4ConfigEngine(address(engine)),
        hubConfigurator: hubConfigurator,
        spokeConfigurator: spokeConfigurator,
        authority: address(accessManager),
        underlying: address(newToken),
        priceSource: address(priceFeedNew),
        proxyAdminOwner: PROXY_ADMIN_OWNER,
        spokeCount: spokeCount
      });
  }

  function _executePayload(MockFactoryDeploymentPayload payload) internal {
    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(address(payload), abi.encodeCall(AaveV4Payload.execute, ()));
  }
}
