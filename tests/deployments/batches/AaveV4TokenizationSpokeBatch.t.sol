// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4TokenizationSpokeBatchTest is BatchBaseTest {
  AaveV4TokenizationSpokeBatch public tokenizationSpokeBatch;
  BatchReports.TokenizationSpokeBatchReport public report;

  address public hub;
  address public irStrategy;
  uint256 public assetId;
  address public underlying;
  address public implementation;
  string public shareName = 'Core Hub DAI';
  string public shareSymbol = 'chDAI';

  function setUp() public override {
    super.setUp();

    // Deploy a Hub with asset
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    BatchReports.HubInstanceBatchReport memory hubReport = hubInstanceBatch.getReport();
    hub = hubReport.hubProxy;
    irStrategy = hubReport.irStrategy;

    // Deploy test token and add asset
    TestnetERC20 testToken = new TestnetERC20('Test DAI', 'tDAI', 18);
    underlying = address(testToken);

    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      })
    );

    // Setup Hub roles and grant HUB_CONFIGURATOR_ROLE to admin
    vm.startPrank(admin);
    AaveV4HubRolesProcedure.setupHubAllRoles(accessManager, hub);
    IAccessManagerEnumerable(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, admin, 0);

    assetId = IHub(hub).addAsset({
      underlying: underlying,
      decimals: 18,
      feeReceiver: feeReceiver,
      irStrategy: irStrategy,
      irData: irData
    });
    vm.stopPrank();

    implementation = new AaveV4TokenizationSpokeImplementationBatch(salt)
      .getReport()
      .tokenizationSpokeImplementation;

    // Deploy the TokenizationSpoke batch
    tokenizationSpokeBatch = new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      underlying,
      admin,
      shareName,
      shareSymbol,
      salt
    );
    report = tokenizationSpokeBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.tokenizationSpokeProxy, address(0));
    assertEq(report.tokenizationSpokeImplementation, implementation);
    assertEq(ProxyHelper.getImplementation(report.tokenizationSpokeProxy), implementation);
  }

  function test_tokenizationSpokeHub() public view {
    assertEq(ITokenizationSpoke(report.tokenizationSpokeProxy).hub(), hub);
  }

  function test_tokenizationSpokeAssetId() public view {
    assertEq(ITokenizationSpoke(report.tokenizationSpokeProxy).assetId(), assetId);
  }

  function test_tokenizationSpokeAsset() public view {
    assertEq(ITokenizationSpoke(report.tokenizationSpokeProxy).asset(), underlying);
  }

  function test_revert_zeroHub() public {
    vm.expectRevert('invalid hub');
    new AaveV4TokenizationSpokeBatch(
      implementation,
      address(0),
      underlying,
      admin,
      shareName,
      shareSymbol,
      salt
    );
  }

  function test_revert_zeroImplementation() public {
    vm.expectRevert('invalid implementation');
    new AaveV4TokenizationSpokeBatch(
      address(0),
      hub,
      underlying,
      admin,
      shareName,
      shareSymbol,
      keccak256('zeroImplementationSalt')
    );
  }

  function test_revert_zeroProxyAdminOwner() public {
    vm.expectRevert('invalid proxy admin owner');
    new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      underlying,
      address(0),
      shareName,
      shareSymbol,
      keccak256('zeroAdminSalt')
    );
  }

  function test_revert_emptyShareName() public {
    vm.expectRevert('invalid share name');
    new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      underlying,
      admin,
      '',
      shareSymbol,
      keccak256('emptyNameSalt')
    );
  }

  function test_revert_emptyShareSymbol() public {
    vm.expectRevert('invalid share symbol');
    new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      underlying,
      admin,
      shareName,
      '',
      keccak256('emptySymbolSalt')
    );
  }

  function test_revert_invalidUnderlying() public {
    vm.expectRevert();
    new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      makeAddr('nonExistentUnderlying'),
      admin,
      shareName,
      shareSymbol,
      keccak256('invalidAssetSalt')
    );
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4TokenizationSpokeBatch newBatch = new AaveV4TokenizationSpokeBatch(
      implementation,
      hub,
      underlying,
      admin,
      shareName,
      shareSymbol,
      keccak256('differentSalt')
    );
    assertNotEq(report.tokenizationSpokeProxy, newBatch.getReport().tokenizationSpokeProxy);
  }
}
