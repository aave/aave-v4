// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

contract AaveV4TokenizationSpokeDeployProcedureTest is ProceduresBase {
  AaveV4TokenizationSpokeDeployProcedureWrapper public wrapper;
  address public deployedHub;
  uint256 public assetId;
  address public underlying;
  address public implementation;
  string public shareName = 'Test Vault Share';
  string public shareSymbol = 'tvDAI';

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4TokenizationSpokeDeployProcedureWrapper();
    implementation = wrapper.deployTokenizationSpokeImplementation(salt);

    // TokenizationSpokeInstance initializer requires a hub with the asset listed
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

  function test_deployTokenizationSpokeImplementation() public view {
    assertEq(
      implementation,
      Create2Utils.computeCreate2Address(salt, type(TokenizationSpokeInstance).creationCode)
    );
    assertEq(TokenizationSpokeInstance(implementation).SPOKE_REVISION(), 2);
    assertEq(ProxyHelper.getProxyInitializedVersion(implementation), type(uint64).max);
    assertEq(ITokenizationSpoke(implementation).hub(), address(0));
  }

  function test_deployTokenizationSpokeProxy() public {
    address tokenizationSpokeProxy = wrapper.deployTokenizationSpokeProxy(
      implementation,
      deployedHub,
      underlying,
      owner,
      shareName,
      shareSymbol,
      salt
    );
    assertNotEq(tokenizationSpokeProxy, address(0));
    assertEq(Ownable(ProxyHelper.getProxyAdmin(tokenizationSpokeProxy)).owner(), owner);
    assertEq(ProxyHelper.getImplementation(tokenizationSpokeProxy), implementation);
    assertEq(ProxyHelper.getProxyInitializedVersion(tokenizationSpokeProxy), 2);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).hub(), deployedHub);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).assetId(), assetId);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).asset(), underlying);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).name(), shareName);
    assertEq(ITokenizationSpoke(tokenizationSpokeProxy).symbol(), shareSymbol);
  }

  function test_deployTokenizationSpokeProxy_reverts() public {
    vm.expectRevert('invalid implementation');
    wrapper.deployTokenizationSpokeProxy({
      implementation: address(0),
      hub: deployedHub,
      underlying: underlying,
      proxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('zeroImplementationSalt')
    });

    vm.expectRevert('invalid hub');
    wrapper.deployTokenizationSpokeProxy({
      implementation: implementation,
      hub: address(0),
      underlying: underlying,
      proxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: salt
    });

    vm.expectRevert('invalid proxy admin owner');
    wrapper.deployTokenizationSpokeProxy({
      implementation: implementation,
      hub: deployedHub,
      underlying: underlying,
      proxyAdminOwner: address(0),
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('zeroAdminSalt')
    });

    vm.expectRevert('invalid share name');
    wrapper.deployTokenizationSpokeProxy({
      implementation: implementation,
      hub: deployedHub,
      underlying: underlying,
      proxyAdminOwner: owner,
      shareName: '',
      shareSymbol: shareSymbol,
      salt: keccak256('emptyNameSalt')
    });

    vm.expectRevert('invalid share symbol');
    wrapper.deployTokenizationSpokeProxy({
      implementation: implementation,
      hub: deployedHub,
      underlying: underlying,
      proxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: '',
      salt: keccak256('emptySymbolSalt')
    });
  }

  function test_deployTokenizationSpokeProxy_revertsWith_failedCreate2FactoryCall() public {
    vm.expectRevert(Create2Utils.FailedCreate2FactoryCall.selector);
    wrapper.deployTokenizationSpokeProxy({
      implementation: implementation,
      hub: deployedHub,
      underlying: makeAddr('nonExistentUnderlying'),
      proxyAdminOwner: owner,
      shareName: shareName,
      shareSymbol: shareSymbol,
      salt: keccak256('salt')
    });
  }

  function test_deployTokenizationSpokeImplementation_revertsWith_ContractAlreadyDeployed() public {
    vm.expectRevert(Create2Utils.ContractAlreadyDeployed.selector);
    wrapper.deployTokenizationSpokeImplementation(salt);
  }
}
