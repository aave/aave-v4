// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
import {AaveV4HubConfiguratorBatch} from 'src/deployments/batches/AaveV4HubConfiguratorBatch.sol';
import {AaveV4SpokeConfiguratorBatch} from 'src/deployments/batches/AaveV4SpokeConfiguratorBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4HubInstanceBatch} from 'src/deployments/batches/AaveV4HubInstanceBatch.sol';
import {AaveV4GiverPositionManagerBatch} from 'src/deployments/batches/AaveV4GiverPositionManagerBatch.sol';
import {AaveV4TakerPositionManagerBatch} from 'src/deployments/batches/AaveV4TakerPositionManagerBatch.sol';
import {AaveV4ConfigPositionManagerBatch} from 'src/deployments/batches/AaveV4ConfigPositionManagerBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4TokenizationSpokeBatch} from 'src/deployments/batches/AaveV4TokenizationSpokeBatch.sol';
import {AaveV4TreasurySpokeBatch} from 'src/deployments/batches/AaveV4TreasurySpokeBatch.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

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

  /// @notice Deploys the HubConfigurator batch.
  /// @param authority The authority for the HubConfigurator.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The HubConfigurator batch report.
  function deployHubConfiguratorBatch(
    address authority,
    bytes32 salt
  ) internal returns (BatchReports.HubConfiguratorBatchReport memory) {
    AaveV4HubConfiguratorBatch hubConfiguratorBatch = new AaveV4HubConfiguratorBatch({
      authority_: authority,
      salt_: salt
    });
    return hubConfiguratorBatch.getReport();
  }

  /// @notice Deploys the SpokeConfigurator batch.
  /// @param authority The authority for the SpokeConfigurator.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The SpokeConfigurator batch report.
  function deploySpokeConfiguratorBatch(
    address authority,
    bytes32 salt
  ) internal returns (BatchReports.SpokeConfiguratorBatchReport memory) {
    AaveV4SpokeConfiguratorBatch spokeConfiguratorBatch = new AaveV4SpokeConfiguratorBatch({
      authority_: authority,
      salt_: salt
    });
    return spokeConfiguratorBatch.getReport();
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

  /// @notice Deploys the Hub instance batch containing the Hub proxy and IR strategy.
  /// @param proxyAdminOwner The owner of the proxy admin.
  /// @param authority The access-control authority for the Hub.
  /// @param hubImplementation The address of the deployed Hub implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Hub instance batch report.
  function deployHubInstanceBatch(
    address proxyAdminOwner,
    address authority,
    address hubImplementation,
    bytes32 salt
  ) internal returns (BatchReports.HubInstanceBatchReport memory) {
    AaveV4HubInstanceBatch hubInstanceBatch = new AaveV4HubInstanceBatch({
      proxyAdminOwner_: proxyAdminOwner,
      authority_: authority,
      hubImplementation_: hubImplementation,
      salt_: salt
    });
    return hubInstanceBatch.getReport();
  }

  /// @notice Deploys the Spoke instance batch containing the Spoke proxy, implementation, and AaveOracle.
  /// @dev Unlike the other batches, this one is deployed through the CREATE2 factory instead of `new`.
  ///      The batch deploys the AaveOracle with `new` (the oracle's deployer must be the batch, which calls
  ///      `setSpoke`), so the oracle address is only deterministic if the batch address is. The factory drops
  ///      revert reasons, so the batch's input checks are repeated here.
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
    require(oracleDecimals > 0, 'invalid oracle decimals');
    require(proxyAdminOwner != address(0), 'invalid proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(maxUserReservesLimit > 0, 'invalid max user reserves limit');
    address spokeInstanceBatch = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: abi.encodePacked(
        type(AaveV4SpokeInstanceBatch).creationCode,
        abi.encode(
          proxyAdminOwner,
          authority,
          spokeBytecode,
          oracleDecimals,
          maxUserReservesLimit,
          salt
        )
      )
    });
    return AaveV4SpokeInstanceBatch(spokeInstanceBatch).getReport();
  }

  /// @notice Deploys the GiverPositionManager batch.
  /// @param owner The owner of the GiverPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The GiverPositionManager batch report.
  function deployGiverPositionManagerBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.GiverPositionManagerBatchReport memory) {
    AaveV4GiverPositionManagerBatch giverPositionManagerBatch = new AaveV4GiverPositionManagerBatch({
        owner_: owner,
        salt_: salt
      });
    return giverPositionManagerBatch.getReport();
  }

  /// @notice Deploys the TakerPositionManager batch.
  /// @param owner The owner of the TakerPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The TakerPositionManager batch report.
  function deployTakerPositionManagerBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.TakerPositionManagerBatchReport memory) {
    AaveV4TakerPositionManagerBatch takerPositionManagerBatch = new AaveV4TakerPositionManagerBatch({
        owner_: owner,
        salt_: salt
      });
    return takerPositionManagerBatch.getReport();
  }

  /// @notice Deploys the ConfigPositionManager batch.
  /// @param owner The owner of the ConfigPositionManager.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The ConfigPositionManager batch report.
  function deployConfigPositionManagerBatch(
    address owner,
    bytes32 salt
  ) internal returns (BatchReports.ConfigPositionManagerBatchReport memory) {
    AaveV4ConfigPositionManagerBatch configPositionManagerBatch = new AaveV4ConfigPositionManagerBatch({
        owner_: owner,
        salt_: salt
      });
    return configPositionManagerBatch.getReport();
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
