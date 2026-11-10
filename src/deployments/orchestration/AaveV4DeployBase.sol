// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4HubImplementationBatch} from 'src/deployments/batches/AaveV4HubImplementationBatch.sol';
import {AaveV4HubSpokeFactoryBatch} from 'src/deployments/batches/AaveV4HubSpokeFactoryBatch.sol';
import {AaveV4PositionManagerBatch} from 'src/deployments/batches/AaveV4PositionManagerBatch.sol';
import {AaveV4SpokeImplementationBatch} from 'src/deployments/batches/AaveV4SpokeImplementationBatch.sol';
import {AaveV4TokenizationSpokeImplementationBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeImplementationBatch.sol';

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

  /// @notice Deploys the canonical Hub implementation batch.
  /// @param hubBytecode The creation bytecode of the HubInstance contract.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Hub implementation batch report.
  function deployHubImplementationBatch(
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (BatchReports.HubImplementationBatchReport memory) {
    AaveV4HubImplementationBatch hubImplementationBatch = new AaveV4HubImplementationBatch({
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    return hubImplementationBatch.getReport();
  }

  /// @notice Deploys the canonical Spoke implementation batch.
  /// @param spokeBytecode The creation bytecode of the SpokeInstance contract.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Spoke implementation batch report.
  function deploySpokeImplementationBatch(
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (BatchReports.SpokeImplementationBatchReport memory) {
    AaveV4SpokeImplementationBatch spokeImplementationBatch = new AaveV4SpokeImplementationBatch({
      spokeBytecode_: spokeBytecode,
      salt_: salt
    });
    return spokeImplementationBatch.getReport();
  }

  /// @notice Deploys the HubSpokeFactory batch containing the canonical TreasurySpoke implementation and the
  /// HubSpokeFactory.
  /// @param proxyAdminOwner The owner of the HubSpokeFactory ProxyAdmin.
  /// @param authority The access control authority of the HubSpokeFactory.
  /// @param hubImplementation The canonical HubInstance implementation.
  /// @param spokeImplementation The canonical SpokeInstance implementation.
  /// @param tokenizationSpokeImplementation The canonical TokenizationSpokeInstance implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The HubSpokeFactory batch report.
  function deployHubSpokeFactoryBatch(
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    address spokeImplementation,
    address tokenizationSpokeImplementation,
    bytes32 salt
  ) internal returns (BatchReports.HubSpokeFactoryBatchReport memory) {
    AaveV4HubSpokeFactoryBatch hubSpokeFactoryBatch = new AaveV4HubSpokeFactoryBatch({
      proxyAdminOwner_: proxyAdminOwner,
      authority_: authority,
      hubImplementation_: hubImplementation,
      spokeImplementation_: spokeImplementation,
      tokenizationSpokeImplementation_: tokenizationSpokeImplementation,
      salt_: salt
    });
    return hubSpokeFactoryBatch.getReport();
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

  /// @notice Deploys the canonical TokenizationSpoke implementation batch.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The TokenizationSpoke implementation batch report.
  function deployTokenizationSpokeImplementationBatch(
    bytes32 salt
  ) internal returns (BatchReports.TokenizationSpokeImplementationBatchReport memory) {
    AaveV4TokenizationSpokeImplementationBatch tokenizationSpokeImplementationBatch = new AaveV4TokenizationSpokeImplementationBatch({
        salt_: salt
      });
    return tokenizationSpokeImplementationBatch.getReport();
  }
}
