// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4GatewayBatch is
  AaveV4NativeTokenGatewayDeployProcedure,
  AaveV4SignatureGatewayDeployProcedure
{
  BatchReports.GatewaysBatchReport internal _report;

  constructor(
    address owner_,
    address nativeWrapper_,
    bool deployNativeTokenGateway_,
    bool deploySignatureGateway_,
    bytes32 salt_
  ) {
    address nativeGateway;
    address signatureGateway;

    if (deployNativeTokenGateway_) {
      nativeGateway = _deployNativeTokenGateway({
        nativeWrapper: nativeWrapper_,
        owner: owner_,
        salt: salt_
      });
    }
    if (deploySignatureGateway_) {
      signatureGateway = _deploySignatureGateway({owner: owner_, salt: salt_});
    }

    _report = BatchReports.GatewaysBatchReport({
      signatureGateway: signatureGateway,
      nativeGateway: nativeGateway
    });
  }

  function getReport() external view returns (BatchReports.GatewaysBatchReport memory) {
    return _report;
  }
}
