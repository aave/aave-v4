// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4TokenizationSpokeBatchTest is BatchBaseTest {
  AaveV4TokenizationSpokeBeaconBatch public tokenizationSpokeBeaconBatch;
  AaveV4TokenizationSpokeBatch public tokenizationSpokeBatch;
  BatchReports.TokenizationSpokeBeaconBatchReport public beaconReport;
  BatchReports.TokenizationSpokeBatchReport public report;

  address public hub;
  address public irStrategy;
  address public beacon;
  uint256 public assetId;
  address public underlying;
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

    // Deploy the shared TokenizationSpoke implementation and beacon
    tokenizationSpokeBeaconBatch = new AaveV4TokenizationSpokeBeaconBatch(admin, salt);
    beaconReport = tokenizationSpokeBeaconBatch.getReport();
    beacon = beaconReport.tokenizationSpokeBeacon;

    // Deploy the TokenizationSpoke batch
    tokenizationSpokeBatch = new AaveV4TokenizationSpokeBatch(
      beacon,
      hub,
      underlying,
      shareName,
      shareSymbol,
      salt
    );
    report = tokenizationSpokeBatch.getReport();
  }

  function test_getBeaconReport() public view {
    assertNotEq(beaconReport.tokenizationSpokeBeacon, address(0));
    assertNotEq(beaconReport.tokenizationSpokeImplementation, address(0));
    assertEq(
      ProxyHelper.getImplementation(beaconReport.tokenizationSpokeImplementation),
      address(0)
    );
  }

  function test_getReport() public view {
    assertNotEq(report.tokenizationSpokeProxy, address(0));
  }

  function test_tokenizationSpokeBeacon() public view {
    assertEq(ProxyHelper.getBeacon(report.tokenizationSpokeProxy), beacon);
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

  function test_revert_zeroBeaconOwner() public {
    vm.expectRevert('invalid beacon owner');
    new AaveV4TokenizationSpokeBeaconBatch(address(0), keccak256('zeroBeaconOwnerSalt'));
  }

  function test_revert_zeroBeacon() public {
    vm.expectRevert('invalid beacon');
    new AaveV4TokenizationSpokeBatch(
      address(0),
      hub,
      underlying,
      shareName,
      shareSymbol,
      keccak256('zeroBeaconSalt')
    );
  }

  function test_revert_zeroHub() public {
    vm.expectRevert('invalid hub');
    new AaveV4TokenizationSpokeBatch(
      beacon,
      address(0),
      underlying,
      shareName,
      shareSymbol,
      keccak256('zeroHubSalt')
    );
  }

  function test_revert_emptyShareName() public {
    vm.expectRevert('invalid share name');
    new AaveV4TokenizationSpokeBatch(
      beacon,
      hub,
      underlying,
      '',
      shareSymbol,
      keccak256('emptyNameSalt')
    );
  }

  function test_revert_emptyShareSymbol() public {
    vm.expectRevert('invalid share symbol');
    new AaveV4TokenizationSpokeBatch(
      beacon,
      hub,
      underlying,
      shareName,
      '',
      keccak256('emptySymbolSalt')
    );
  }

  function test_revert_invalidUnderlying() public {
    vm.expectRevert();
    new AaveV4TokenizationSpokeBatch(
      beacon,
      hub,
      makeAddr('nonExistentUnderlying'),
      shareName,
      shareSymbol,
      keccak256('invalidAssetSalt')
    );
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4TokenizationSpokeBatch newBatch = new AaveV4TokenizationSpokeBatch(
      beacon,
      hub,
      underlying,
      shareName,
      shareSymbol,
      keccak256('differentSalt')
    );
    assertNotEq(report.tokenizationSpokeProxy, newBatch.getReport().tokenizationSpokeProxy);
  }
}
