// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SignatureGatewayDeployProcedureTest is ProceduresBase {
  AaveV4SignatureGatewayDeployProcedureWrapper public aaveV4SignatureGatewayDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4SignatureGatewayDeployProcedureWrapper = new AaveV4SignatureGatewayDeployProcedureWrapper();
  }

  function test_deploySignatureGateway() public {
    address signatureGateway = aaveV4SignatureGatewayDeployProcedureWrapper.deploySignatureGateway(
      owner,
      salt
    );
    assertNotEq(signatureGateway, address(0));
    assertEq(Ownable(signatureGateway).owner(), owner);
  }

  function test_deploySignatureGateway_reverts() public {
    vm.expectRevert('invalid owner');
    aaveV4SignatureGatewayDeployProcedureWrapper.deploySignatureGateway(address(0), salt);
  }
}
