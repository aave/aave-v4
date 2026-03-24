// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4TokenizationSpokeDeployProcedureTest is ProceduresBase {
  AaveV4TokenizationSpokeDeployProcedureWrapper public wrapper;
  address public deployedHub;
  uint256 public assetId;
  address public underlying;
  string public shareName = 'Test Vault Share';
  string public shareSymbol = 'tvDAI';

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4TokenizationSpokeDeployProcedureWrapper();

    // TokenizationSpokeInstance constructor requires hub
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: admin,
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

  function test_deployUpgradeableTokenizationSpokeInstance() public {
    (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) = wrapper
      .deployUpgradeableTokenizationSpokeInstance(
        deployedHub,
        underlying,
        owner,
        shareName,
        shareSymbol,
        salt
      );
    assertNotEq(tokenizationSpokeProxy, address(0));
    assertNotEq(tokenizationSpokeImplementation, address(0));
    assertEq(Ownable(ProxyHelper.getProxyAdmin(tokenizationSpokeProxy)).owner(), owner);
    assertEq(
      ProxyHelper.getImplementation(tokenizationSpokeProxy),
      tokenizationSpokeImplementation
    );
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).hub(), deployedHub);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).assetId(), assetId);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).asset(), underlying);
  }

  function test_deployUpgradeableTokenizationSpokeInstance_reverts() public {
    vm.expectRevert('invalid hub');
    wrapper.deployUpgradeableTokenizationSpokeInstance({
      hub: address(0),
      underlying: underlying,
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: salt
    });

    vm.expectRevert('invalid spoke proxy admin owner');
    wrapper.deployUpgradeableTokenizationSpokeInstance({
      hub: deployedHub,
      underlying: underlying,
      spokeProxyAdminOwner: address(0),
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('zeroAdminSalt')
    });

    vm.expectRevert('invalid share name');
    wrapper.deployUpgradeableTokenizationSpokeInstance({
      hub: deployedHub,
      underlying: underlying,
      spokeProxyAdminOwner: owner,
      shareName: '',
      shareSymbol: shareSymbol,
      salt: keccak256('emptyNameSalt')
    });

    vm.expectRevert('invalid share symbol');
    wrapper.deployUpgradeableTokenizationSpokeInstance({
      hub: deployedHub,
      underlying: underlying,
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: '',
      salt: keccak256('emptySymbolSalt')
    });
  }

  function test_deployUpgradeableTokenizationSpokeInstance_revertsWith_failedCreate2FactoryCall()
    public
  {
    vm.expectRevert(Create2Utils.FailedCreate2FactoryCall.selector);
    wrapper.deployUpgradeableTokenizationSpokeInstance({
      hub: deployedHub,
      underlying: makeAddr('nonExistentUnderlying'),
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('salt')
    });
  }
}
