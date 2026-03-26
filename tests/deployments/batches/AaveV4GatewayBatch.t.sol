// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4GatewayBatchTest is BatchBaseTest {
  AaveV4GatewayBatch public gatewayBatch;
  BatchReports.GatewaysBatchReport public report;

  function setUp() public override {
    super.setUp();
    gatewayBatch = new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: true,
      deploySignatureGateway_: true,
      salt_: salt
    });
    report = gatewayBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.nativeGateway, address(0));
    assertNotEq(report.signatureGateway, address(0));
  }

  function test_nativeGatewayWiring() public view {
    NativeTokenGateway gateway = NativeTokenGateway(payable(report.nativeGateway));
    assertEq(gateway.owner(), admin);
    assertEq(gateway.NATIVE_TOKEN_WRAPPER(), nativeWrapper);
  }

  function test_signatureGatewayOwner() public view {
    assertEq(Ownable(report.signatureGateway).owner(), admin);
  }

  function test_onlyNativeTokenGateway() public {
    AaveV4GatewayBatch batch = new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: true,
      deploySignatureGateway_: false,
      salt_: keccak256('nativeOnly')
    });
    BatchReports.GatewaysBatchReport memory r = batch.getReport();
    assertNotEq(r.nativeGateway, address(0));
    assertEq(r.signatureGateway, address(0));
  }

  function test_onlySignatureGateway() public {
    AaveV4GatewayBatch batch = new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: false,
      deploySignatureGateway_: true,
      salt_: keccak256('sigOnly')
    });
    BatchReports.GatewaysBatchReport memory r = batch.getReport();
    assertEq(r.nativeGateway, address(0));
    assertNotEq(r.signatureGateway, address(0));
  }

  function test_noGateways() public {
    AaveV4GatewayBatch batch = new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: false,
      deploySignatureGateway_: false,
      salt_: keccak256('none')
    });
    BatchReports.GatewaysBatchReport memory r = batch.getReport();
    assertEq(r.nativeGateway, address(0));
    assertEq(r.signatureGateway, address(0));
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4GatewayBatch({
      owner_: address(0),
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: true,
      deploySignatureGateway_: true,
      salt_: salt
    });
  }

  function test_revert_zeroNativeWrapper() public {
    vm.expectRevert('invalid native wrapper');
    new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: address(0),
      deployNativeTokenGateway_: true,
      deploySignatureGateway_: true,
      salt_: salt
    });
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4GatewayBatch newBatch = new AaveV4GatewayBatch({
      owner_: admin,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: true,
      deploySignatureGateway_: true,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.nativeGateway, newBatch.getReport().nativeGateway);
  }
}
