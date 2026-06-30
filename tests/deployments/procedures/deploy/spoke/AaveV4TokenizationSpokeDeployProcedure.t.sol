// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {AaveV4TokenizationSpokeBeaconBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBeaconBatch.sol';

contract AaveV4TokenizationSpokeDeployProcedureTest is ProceduresBase {
  AaveV4TokenizationSpokeDeployProcedureWrapper public wrapper;
  address public deployedHub;
  address public beacon;
  uint256 public assetId;
  address public underlying;
  string public shareName = 'Test Vault Share';
  string public shareSymbol = 'tvDAI';

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4TokenizationSpokeDeployProcedureWrapper();

    // Deploy the shared TokenizationSpoke implementation and beacon
    beacon = new AaveV4TokenizationSpokeBeaconBatch(owner, salt)
      .getReport()
      .tokenizationSpokeBeacon;

    // Hub for the asset listing
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: admin,
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    BatchReports.HubInstanceBatchReport memory hubReport = hubInstanceBatch.getReport();
    deployedHub = hubReport.hubProxy;

    // Deploy test ERC20
    TestnetERC20 testToken = new TestnetERC20('Test DAI', 'tDAI', 18);
    underlying = address(testToken);

    // Setup Hub roles and add asset
    vm.startPrank(accessManagerAdmin);
    AaveV4HubRolesProcedure.setupHubAllRoles(accessManager, deployedHub);
    IAccessManagerEnumerable(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, admin, 0);
    vm.stopPrank();

    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 5_00,
        rateGrowthBeforeOptimal: 5_00,
        rateGrowthAfterOptimal: 5_00
      })
    );

    vm.prank(admin);
    assetId = IHub(deployedHub).addAsset({
      underlying: underlying,
      decimals: 18,
      feeReceiver: feeReceiver,
      irStrategy: hubReport.irStrategy,
      irData: irData
    });
  }

  function test_deployTokenizationSpokeInstance() public {
    address tokenizationSpokeProxy = wrapper.deployTokenizationSpokeInstance(
      beacon,
      deployedHub,
      underlying,
      shareName,
      shareSymbol,
      salt
    );
    assertNotEq(tokenizationSpokeProxy, address(0));
    assertEq(ProxyHelper.getBeacon(tokenizationSpokeProxy), beacon);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).hub(), deployedHub);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).assetId(), assetId);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).asset(), underlying);
  }

  function test_deployTokenizationSpokeInstance_reverts() public {
    vm.expectRevert('invalid beacon');
    wrapper.deployTokenizationSpokeInstance({
      beacon: address(0),
      hub: deployedHub,
      underlying: underlying,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: salt
    });

    vm.expectRevert('invalid hub');
    wrapper.deployTokenizationSpokeInstance({
      beacon: beacon,
      hub: address(0),
      underlying: underlying,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('zeroHubSalt')
    });

    vm.expectRevert('invalid share name');
    wrapper.deployTokenizationSpokeInstance({
      beacon: beacon,
      hub: deployedHub,
      underlying: underlying,
      shareName: '',
      shareSymbol: shareSymbol,
      salt: keccak256('emptyNameSalt')
    });

    vm.expectRevert('invalid share symbol');
    wrapper.deployTokenizationSpokeInstance({
      beacon: beacon,
      hub: deployedHub,
      underlying: underlying,
      shareName: shareName,
      shareSymbol: '',
      salt: keccak256('emptySymbolSalt')
    });
  }

  function test_deployTokenizationSpokeInstance_revertsWith_failedCreate2FactoryCall() public {
    vm.expectRevert(Create2Utils.FailedCreate2FactoryCall.selector);
    wrapper.deployTokenizationSpokeInstance({
      beacon: beacon,
      hub: deployedHub,
      underlying: makeAddr('nonExistentUnderlying'),
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('salt')
    });
  }
}
