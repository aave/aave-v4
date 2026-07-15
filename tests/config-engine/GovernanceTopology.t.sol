// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/config-engine/BaseConfigEngine.t.sol';

import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';
import {MockGovernanceExecutor} from 'tests/helpers/mocks/config-engine/MockGovernanceExecutor.sol';

/// @dev Production-style payload: all action data lives in immutables or literals. `execute()`
/// runs via delegatecall inside the Executor, so payload storage is not readable at execution time.
contract TokenizationListingPayload is AaveV4Payload {
  IHubConfigurator internal immutable HUB_CONFIGURATOR;
  address internal immutable HUB;
  address internal immutable UNDERLYING;
  address internal immutable FEE_RECEIVER;
  address internal immutable IR_STRATEGY;
  address internal immutable PROXY_ADMIN_OWNER;

  constructor(
    IAaveV4ConfigEngine configEngine,
    IHubConfigurator hubConfigurator,
    address hub,
    address underlying,
    address feeReceiver,
    address irStrategy,
    address proxyAdminOwner
  ) AaveV4Payload(configEngine) {
    HUB_CONFIGURATOR = hubConfigurator;
    HUB = hub;
    UNDERLYING = underlying;
    FEE_RECEIVER = feeReceiver;
    IR_STRATEGY = irStrategy;
    PROXY_ADMIN_OWNER = proxyAdminOwner;
  }

  function hubAssetListings()
    public
    view
    override
    returns (IAaveV4ConfigEngine.AssetListing[] memory)
  {
    IAaveV4ConfigEngine.AssetListing[] memory listings = new IAaveV4ConfigEngine.AssetListing[](1);
    listings[0] = IAaveV4ConfigEngine.AssetListing({
      hubConfigurator: HUB_CONFIGURATOR,
      hub: HUB,
      underlying: UNDERLYING,
      feeReceiver: FEE_RECEIVER,
      liquidityFee: 5_00,
      irStrategy: IR_STRATEGY,
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 80_00,
        baseDrawnRate: 1_00,
        rateGrowthBeforeOptimal: 4_00,
        rateGrowthAfterOptimal: 60_00
      }),
      tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
        addCap: 1000,
        proxyAdminOwner: PROXY_ADMIN_OWNER,
        name: 'Tokenized NEW',
        symbol: 'tNEW'
      })
    });
    return listings;
  }
}

/// @dev Executes engine payloads through the real governance topology
/// (PayloadsController → Executor → delegatecall payload → delegatecall engine), where
/// `msg.sender` is the PayloadsController and `address(this)` is the Executor.
contract ConfigEngineGovernanceTopologyTest is BaseConfigEngineTest {
  address internal PAYLOADS_CONTROLLER = makeAddr('PAYLOADS_CONTROLLER');
  address internal SECURITY_COUNCIL = makeAddr('SECURITY_COUNCIL');

  MockGovernanceExecutor internal executor;
  TokenizationListingPayload internal payload;

  function setUp() public override {
    super.setUp();

    executor = new MockGovernanceExecutor(PAYLOADS_CONTROLLER);
    payload = new TokenizationListingPayload({
      configEngine: IAaveV4ConfigEngine(address(engine)),
      hubConfigurator: hubConfigurator,
      hub: address(hub1()),
      underlying: address(newToken),
      feeReceiver: FEE_RECEIVER,
      irStrategy: address(irStrategy1()),
      proxyAdminOwner: SECURITY_COUNCIL
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
      SECURITY_COUNCIL,
      'TokenizationSpoke ProxyAdmin owner should be the owner declared in the payload'
    );
  }

  function test_hubAssetListing_tokenizationSpoke_deterministicAddress() public {
    uint256 expectedAssetId = hub1().getAssetCount();
    address predictedProxy = TokenizationSpokeDeployer.computeProxyAddress(
      address(hub1()),
      address(newToken),
      'Tokenized NEW',
      'tNEW',
      SECURITY_COUNCIL
    );

    _executePayload(address(payload));

    assertTrue(hub1().isSpokeListed(expectedAssetId, predictedProxy));
  }
}
