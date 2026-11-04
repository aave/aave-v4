// SPDX-License-Identifier: LicenseRef-BUSL
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
import {AaveV4FeeSharesMinterBatch} from 'src/deployments/batches/AaveV4FeeSharesMinterBatch.sol';

/// @title AaveV4DeployBase Library
/// @author Aave Labs
/// @notice Static deploy helpers that instantiate each deployment batch.
library AaveV4DeployBase {
  /// @notice Deploys the authority batch containing the AccessManagerEnumerable.
  /// @param admin The initial admin of the access manager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The authority batch report.
  function deployAuthorityBatch(
    address admin,
    bytes32 salt
  ) internal returns (BatchReports.AuthorityBatchReport memory) {
    AaveV4AuthorityBatch authorityBatch = new AaveV4AuthorityBatch({admin_: admin, salt_: salt});
    return authorityBatch.getReport();
  }

  /// @notice Deploys the configurator batch containing HubConfigurator and SpokeConfigurator.
  /// @param hubConfiguratorAuthority The authority for the HubConfigurator.
  /// @param spokeConfiguratorAuthority The authority for the SpokeConfigurator.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The configurator batch report.
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

  /// @notice Deploys the Treasury Spoke batch containing the TreasurySpoke proxy.
  /// @param owner The owner of the TreasurySpoke.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Treasury Spoke batch report.
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

  /// @notice Deploys the FeeSharesMinter batch containing the FeeSharesMinter contract.
  /// @param owner The owner of the FeeSharesMinter.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The FeeSharesMinter batch report.
  function deployFeeSharesMinterBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.FeeSharesMinterBatchReport memory) {
    AaveV4FeeSharesMinterBatch feeSharesMinterBatch = new AaveV4FeeSharesMinterBatch({
      owner_: owner,
      salt_: salt
    });
    return feeSharesMinterBatch.getReport();
  }

  /// @notice Deploys the Hub instance batch containing the Hub proxy, implementation, and IR strategy.
  /// @param proxyAdminOwner The owner of the proxy admin.
  /// @param authority The access-control authority for the Hub.
  /// @param hubBytecode The creation bytecode of the HubInstance contract.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Hub instance batch report.
  function deployHubInstanceBatch(
    address proxyAdminOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (BatchReports.HubInstanceBatchReport memory) {
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: proxyAdminOwner,
      authority_: authority,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    return hubInstanceBatch.getReport();
  }

  /// @notice Deploys the Spoke instance batch containing the Spoke proxy, implementation, and AaveOracle.
  /// @param proxyAdminOwner The owner of the proxy admin.
  /// @param authority The access-control authority for the Spoke.
  /// @param spokeBytecode The creation bytecode of the SpokeInstance contract.
  /// @param oracleDecimals The decimal precision for the AaveOracle.
  /// @param maxUserReservesLimit The maximum number of reserves a user can interact with.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Spoke instance batch report.
  function deploySpokeInstanceBatch(
    address proxyAdminOwner,
    address authority,
    bytes memory spokeBytecode,
    uint8 oracleDecimals,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: proxyAdminOwner,
      authority_: authority,
      spokeBytecode_: spokeBytecode,
      oracleDecimals_: oracleDecimals,
      maxUserReservesLimit_: maxUserReservesLimit,
      salt_: salt
    });
    return spokeInstanceBatch.getReport();
  }

  /// @notice Deploys the position manager batch containing all three position manager contracts.
  /// @param owner The owner of the position managers.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The position manager batch report.
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

  /// @notice Deploys the gateways batch containing NativeTokenGateway and SignatureGateway.
  /// @param owner The owner of the gateway contracts.
  /// @param nativeWrapper The address of the native token wrapper.
  /// @param deployNativeTokenGateway Whether to deploy the NativeTokenGateway.
  /// @param deploySignatureGateway Whether to deploy the SignatureGateway.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The gateways batch report.
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

  /// @notice Deploys the Tokenization Spoke batch containing the TokenizationSpoke proxy and implementation.
  /// @param hub The address of the Hub the tokenization spoke connects to.
  /// @param underlying The address of the underlying asset to tokenize.
  /// @param proxyAdminOwner The owner of the proxy admin.
  /// @param shareName The name of the share token.
  /// @param shareSymbol The symbol of the share token.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Tokenization Spoke batch report.
  function deployTokenizationSpokeBatch(
    address hub,
    address underlying,
    address proxyAdminOwner,
    string memory shareName,
    string memory shareSymbol,
    bytes32 salt
  ) internal returns (BatchReports.TokenizationSpokeBatchReport memory) {
    AaveV4TokenizationSpokeBatch tokenizationSpokeBatch = new AaveV4TokenizationSpokeBatch({
      hub_: hub,
      underlying_: underlying,
      proxyAdminOwner_: proxyAdminOwner,
      shareName_: shareName,
      shareSymbol_: shareSymbol,
      salt_: salt
    });
    return tokenizationSpokeBatch.getReport();
  }
}
