// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {MockGovernanceExecutor} from 'tests/helpers/mocks/config-engine/MockGovernanceExecutor.sol';
import {MockTokenizationListingPayload} from 'tests/helpers/mocks/config-engine/MockTokenizationListingPayload.sol';

/// @dev Validates that payload execution flow through the correct governance topology,
/// respecting the correct order of calls and delegatecalls between each contract
/// (PayloadsController → Executor → delegatecall payload → delegatecall engine), where
/// `msg.sender` is the PayloadsController and `address(this)` is the Executor.
contract ConfigEngineGovernanceTopologyTest is BaseConfigEngineTest {
  MockTokenizationListingPayload internal payload;

  function setUp() public override {
    super.setUp();

    payload = new MockTokenizationListingPayload({
      configEngine: IAaveV4ConfigEngine(address(engine)),
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(newToken),
      feeReceiver: FEE_RECEIVER,
      irStrategy: address(irStrategy1()),
      proxyAdminOwner: PROXY_ADMIN_OWNER
    });

    // in production the Executor, not the payload or the engine, holds the configurator permissions
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(executor), 0);
  }

  function _executePayload(address target) internal {
    vm.prank(PAYLOADS_CONTROLLER);
    executor.executeTransaction(target, abi.encodeCall(AaveV4Payload.execute, ()));
  }

  function test_hubAssetListing_tokenizationSpoke_proxyAdminOwner() public {
    uint256 expectedAssetId = hub1().getAssetCount();

    _executePayload(address(payload));

    // spoke 0 is the fee receiver registered by addAsset, spoke 1 the deployed TokenizationSpoke
    assertEq(hub1().getSpokeCount(expectedAssetId), 2);
    address tokenizationSpoke = hub1().getSpokeAddress(expectedAssetId, 1);
    assertNotEq(tokenizationSpoke, FEE_RECEIVER);
    address proxyAdminOwner = Ownable(ProxyHelper.getProxyAdmin(tokenizationSpoke)).owner();

    assertNotEq(
      proxyAdminOwner,
      PAYLOADS_CONTROLLER,
      'TokenizationSpoke ProxyAdmin owner must never be the PayloadsController'
    );
    assertEq(
      proxyAdminOwner,
      PROXY_ADMIN_OWNER,
      'TokenizationSpoke ProxyAdmin owner should be the declared proxyAdminOwner'
    );
  }

  function test_hubAssetListing_tokenizationSpoke_deterministicAddress() public {
    uint256 expectedAssetId = hub1().getAssetCount();
    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      PROXY_ADMIN_OWNER
    );

    _executePayload(address(payload));

    assertTrue(hub1().isSpokeListed(expectedAssetId, predictedProxy));
  }

  function test_executeTransaction_withValue_reverts() public {
    vm.deal(PAYLOADS_CONTROLLER, 1 ether);
    vm.prank(PAYLOADS_CONTROLLER);
    vm.expectRevert(MockGovernanceExecutor.FailedActionExecution.selector);
    executor.executeTransaction{value: 1 ether}(
      address(payload),
      abi.encodeCall(AaveV4Payload.execute, ())
    );
  }
}
