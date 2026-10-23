// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4AaveOracleBatch} from 'src/deployments/batches/AaveV4AaveOracleBatch.sol';
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

  /// @notice Deploys the AaveOracle batch, which deploys a Spoke's AaveOracle and can bind it to the Spoke once.
  /// @dev Deployed through the CREATE2 factory so that the AaveOracle, and the Spoke implementation and proxy
  ///      built on it, do not depend on the deployer's nonce.
  /// @param owner The account allowed to bind the AaveOracle to its Spoke.
  /// @param oracleDecimals The decimal precision for the AaveOracle.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The AaveOracle batch report.
  function deployAaveOracleBatch(
    address owner,
    uint8 oracleDecimals,
    bytes32 salt
  ) internal returns (BatchReports.AaveOracleBatchReport memory) {
    // the CREATE2 factory drops revert reasons, so repeat the batch's input checks here
    require(owner != address(0), 'invalid owner');
    require(oracleDecimals > 0, 'invalid oracle decimals');
    address aaveOracleBatch = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: abi.encodePacked(
        type(AaveV4AaveOracleBatch).creationCode,
        abi.encode(owner, oracleDecimals, salt)
      )
    });
    return AaveV4AaveOracleBatch(aaveOracleBatch).getReport();
  }

  /// @notice Binds a Spoke's AaveOracle to the Spoke through the batch that deployed it.
  /// @dev Must be called by the batch owner, after the Spoke proxy is deployed.
  /// @param aaveOracleBatch The AaveOracle batch.
  /// @param spoke The address of the Spoke proxy.
  function setAaveOracleSpoke(address aaveOracleBatch, address spoke) internal {
    AaveV4AaveOracleBatch(aaveOracleBatch).setSpoke(spoke);
  }

  /// @notice Deploys the Spoke instance batch containing the Spoke proxy.
  /// @param proxyAdminOwner The owner of the proxy admin.
  /// @param authority The access-control authority for the Spoke.
  /// @param spokeImplementation The address of the deployed Spoke implementation.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The Spoke instance batch report.
  function deploySpokeInstanceBatch(
    address proxyAdminOwner,
    address authority,
    address spokeImplementation,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch({
      proxyAdminOwner_: proxyAdminOwner,
      authority_: authority,
      spokeImplementation_: spokeImplementation,
      salt_: salt
    });
    return spokeInstanceBatch.getReport();
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
