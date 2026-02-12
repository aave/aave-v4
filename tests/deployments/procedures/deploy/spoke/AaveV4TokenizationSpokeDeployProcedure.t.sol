// SPDX-License-Identifier: UNLICENSED
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
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(admin, accessManager, salt);
    BatchReports.HubBatchReport memory hubReport = hubBatch.getReport();
    deployedHub = hubReport.hub;

    // Deploy test ERC20
    TestnetERC20 testToken = new TestnetERC20('Test DAI', 'tDAI', 18);
    underlying = address(testToken);

    // Setup Hub roles and add asset
    vm.startPrank(accessManagerAdmin);
    AaveV4HubRolesProcedure.setupHubRoles(accessManager, deployedHub);
    IAccessManagerEnumerable(accessManager).grantRole(Roles.HUB_CONFIGURATOR_ROLE, admin, 0);
    vm.stopPrank();

    bytes memory irData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00,
        baseVariableBorrowRate: 5_00,
        variableRateSlope1: 5_00,
        variableRateSlope2: 5_00
      })
    );

    vm.prank(admin);
    assetId = IHub(deployedHub).addAsset({
      underlying: underlying,
      decimals: 18,
      feeReceiver: hubReport.treasurySpoke,
      irStrategy: hubReport.irStrategy,
      irData: irData
    });
  }

  function test_deployUpgradableTokenizationSpokeInstance() public {
    (address tokenizationSpokeProxy, address tokenizationSpokeImplementation) = wrapper
      .deployUpgradableTokenizationSpokeInstance(
        deployedHub,
        assetId,
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

  function test_deployUpgradableTokenizationSpokeInstance_reverts() public {
    vm.expectRevert('invalid hub');
    wrapper.deployUpgradableTokenizationSpokeInstance({
      hub: address(0),
      assetId: assetId,
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: salt
    });

    vm.expectRevert('invalid spoke proxy admin owner');
    wrapper.deployUpgradableTokenizationSpokeInstance({
      hub: deployedHub,
      assetId: assetId,
      spokeProxyAdminOwner: address(0),
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('zeroAdminSalt')
    });

    vm.expectRevert('invalid share name');
    wrapper.deployUpgradableTokenizationSpokeInstance({
      hub: deployedHub,
      assetId: assetId,
      spokeProxyAdminOwner: owner,
      shareName: '',
      shareSymbol: shareSymbol,
      salt: keccak256('emptyNameSalt')
    });

    vm.expectRevert('invalid share symbol');
    wrapper.deployUpgradableTokenizationSpokeInstance({
      hub: deployedHub,
      assetId: assetId,
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: '',
      salt: keccak256('emptySymbolSalt')
    });
  }

  function test_deployUpgradableTokenizationSpokeInstance_revertsWith_failedCreate2FactoryCall()
    public
  {
    vm.expectRevert(Create2Utils.failedCreate2FactoryCall.selector);
    wrapper.deployUpgradableTokenizationSpokeInstance({
      hub: deployedHub,
      assetId: 999,
      spokeProxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('salt')
    });
  }
}
