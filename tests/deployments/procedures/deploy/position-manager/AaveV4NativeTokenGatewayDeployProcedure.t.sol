// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4NativeTokenGatewayDeployProcedureTest is ProceduresBase {
  AaveV4NativeTokenGatewayDeployProcedureWrapper
    public aaveV4NativeTokenGatewayDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4NativeTokenGatewayDeployProcedureWrapper = new AaveV4NativeTokenGatewayDeployProcedureWrapper();
  }

  function test_deployNativeTokenGateway() public {
    address nativeTokenGateway = aaveV4NativeTokenGatewayDeployProcedureWrapper
      .deployNativeTokenGateway(nativeWrapper, owner, salt);
    assertNotEq(nativeTokenGateway, address(0));
    assertEq(Ownable(nativeTokenGateway).owner(), owner);
  }

  function test_deployNativeTokenGateway_reverts() public {
    vm.expectRevert('invalid native wrapper');
    aaveV4NativeTokenGatewayDeployProcedureWrapper.deployNativeTokenGateway({
      nativeWrapper: address(0),
      owner: owner,
      salt: salt
    });

    vm.expectRevert('invalid owner');
    aaveV4NativeTokenGatewayDeployProcedureWrapper.deployNativeTokenGateway({
      nativeWrapper: nativeWrapper,
      owner: address(0),
      salt: salt
    });
  }
}
