// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4HubInstanceBatch} from 'src/deployments/batches/AaveV4HubInstanceBatch.sol';
import {AaveV4PositionManagerBatch} from 'src/deployments/batches/AaveV4PositionManagerBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4TokenizationSpokeBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBatch.sol';
import {AaveV4TreasurySpokeBatch} from 'src/deployments/batches/AaveV4TreasurySpokeBatch.sol';

library AaveV4DeployBase {
  function deployAuthorityBatch(
    address admin,
    bytes32 salt
  ) internal returns (BatchReports.AuthorityBatchReport memory) {
    AaveV4AuthorityBatch authorityBatch = new AaveV4AuthorityBatch({admin_: admin, salt_: salt});
    return authorityBatch.getReport();
  }

  function deployConfiguratorBatch(
    address hubConfiguratorAuthority,
    address spokeConfiguratorAuthority,
    bytes32 salt
  ) internal returns (BatchReports.ConfiguratorBatchReport memory) {
    AaveV4ConfiguratorBatch configuratorBatch = new AaveV4ConfiguratorBatch({
      hubConfiguratorAuthority_: hubConfiguratorAuthority,
      spokeConfiguratorAuthority_: spokeConfiguratorAuthority,
      salt_: salt
    });
    return configuratorBatch.getReport();
  }

  function deployTreasurySpokeBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.TreasurySpokeBatchReport memory) {
    AaveV4TreasurySpokeBatch treasurySpokeBatch = new AaveV4TreasurySpokeBatch({
      owner_: owner,
      salt_: salt
    });
    return treasurySpokeBatch.getReport();
  }

  function deployHubInstanceBatch(
    address hubProxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (BatchReports.HubInstanceBatchReport memory) {
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      hubProxyAdminOwner_: hubProxyAdminOwner,
      authority_: authority,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    return hubInstanceBatch.getReport();
  }

  function deploySpokeInstanceBatch(
    address spokeProxyAdminOwner,
    address authority,
    bytes memory spokeBytecode,
    uint8 oracleDecimals,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch({
      spokeProxyAdminOwner_: spokeProxyAdminOwner,
      authority_: authority,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: oracleDecimals,
      maxUserReservesLimit_: maxUserReservesLimit,
      salt_: salt
    });
    return spokeInstanceBatch.getReport();
  }

  function deployPositionManagerBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.PositionManagerBatchReport memory) {
    AaveV4PositionManagerBatch positionManagerBatch = new AaveV4PositionManagerBatch({
      owner_: owner,
      salt_: salt
    });
    return positionManagerBatch.getReport();
  }

  function deployGatewaysBatch(
    address owner,
    address nativeWrapper,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway,
    bytes32 salt
  ) internal returns (BatchReports.GatewaysBatchReport memory) {
    AaveV4GatewayBatch gatewayBatch = new AaveV4GatewayBatch({
      owner_: owner,
      nativeWrapper_: nativeWrapper,
      deployNativeTokenGateway_: deployNativeTokenGateway,
      deploySignatureGateway_: deploySignatureGateway,
      salt_: salt
    });
    return gatewayBatch.getReport();
  }

  function deployTokenizationSpokeBatch(
    address hub,
    address underlying,
    address spokeProxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (BatchReports.TokenizationSpokeBatchReport memory) {
    AaveV4TokenizationSpokeBatch tokenizationSpokeBatch = new AaveV4TokenizationSpokeBatch({
      hub_: hub,
      underlying_: underlying,
      spokeProxyAdminOwner_: spokeProxyAdminOwner,
      shareName_: shareName,
      shareSymbol_: shareSymbol,
      salt_: salt
    });
    return tokenizationSpokeBatch.getReport();
  }
}
