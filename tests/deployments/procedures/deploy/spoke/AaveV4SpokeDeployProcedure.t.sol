// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeDeployProcedureTest is ProceduresBase {
  AaveV4SpokeDeployProcedureWrapper public aaveV4SpokeDeployProcedureWrapper;
  address public spokeImplementation;
  bytes32 public spokeInitCodeHash;

  function setUp() public override {
    super.setUp();
    aaveV4SpokeDeployProcedureWrapper = new AaveV4SpokeDeployProcedureWrapper();
    bytes memory spokeInitCode = abi.encodePacked(
      spokeBytecode,
      abi.encode(aaveOracle, maxUserReservesLimit)
    );
    spokeImplementation = Create2Utils.create2Deploy(salt, spokeInitCode);
    spokeInitCodeHash = keccak256(spokeInitCode);
  }

  function test_deploySpokeProxy() public {
    address spokeProxy = aaveV4SpokeDeployProcedureWrapper.deploySpokeProxy(
      owner,
      accessManager,
      spokeImplementation,
      spokeInitCodeHash,
      salt
    );
    assertNotEq(spokeProxy, address(0));
    assertEq(Ownable(ProxyHelper.getProxyAdmin(spokeProxy)).owner(), owner);
    assertEq(ProxyHelper.getImplementation(spokeProxy), spokeImplementation);
    assertEq(ISpoke(spokeProxy).ORACLE(), aaveOracle);
    assertEq(IAccessManaged(spokeProxy).authority(), accessManager);
  }

  function test_deploySpokeProxy_reverts() public {
    vm.expectRevert('invalid proxy admin owner');
    aaveV4SpokeDeployProcedureWrapper.deploySpokeProxy({
      proxyAdminOwner: address(0),
      authority: accessManager,
      spokeImplementation: spokeImplementation,
      spokeInitCodeHash: spokeInitCodeHash,
      salt: salt
    });

    vm.expectRevert('invalid authority');
    aaveV4SpokeDeployProcedureWrapper.deploySpokeProxy({
      proxyAdminOwner: owner,
      authority: address(0),
      spokeImplementation: spokeImplementation,
      spokeInitCodeHash: spokeInitCodeHash,
      salt: salt
    });

    vm.expectRevert('invalid spoke implementation');
    aaveV4SpokeDeployProcedureWrapper.deploySpokeProxy({
      proxyAdminOwner: owner,
      authority: accessManager,
      spokeImplementation: makeAddr('noCode'),
      spokeInitCodeHash: spokeInitCodeHash,
      salt: salt
    });

    vm.expectRevert('invalid spoke implementation');
    aaveV4SpokeDeployProcedureWrapper.deploySpokeProxy({
      proxyAdminOwner: owner,
      authority: accessManager,
      spokeImplementation: spokeImplementation,
      spokeInitCodeHash: keccak256('otherBytecode'),
      salt: salt
    });
  }
}
