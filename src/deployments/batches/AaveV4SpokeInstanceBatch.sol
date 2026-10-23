// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4SpokeInstanceBatch
/// @author Aave Labs
/// @notice Deploys a Spoke proxy in front of an already deployed implementation, producing a batch report.
/// @dev The AaveOracle is the one the implementation was built with. Binding it to this proxy is a separate call to
///      `AaveV4AaveOracleBatch.setSpoke`, since only the oracle's deployer can call `AaveOracle.setSpoke`.
contract AaveV4SpokeInstanceBatch is AaveV4SpokeDeployProcedure {
  BatchReports.SpokeInstanceBatchReport internal _report;

  /// @dev Constructor.
  /// @param proxyAdminOwner_ The owner of the proxy admin.
  /// @param authority_ The access-control authority for the Spoke.
  /// @param spokeImplementation_ The address of the deployed Spoke implementation.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address proxyAdminOwner_,
    address authority_,
    address spokeImplementation_,
    bytes32 salt_
  ) {
    address spokeProxy = _deploySpokeProxy({
      proxyAdminOwner: proxyAdminOwner_,
      authority: authority_,
      spokeImplementation: spokeImplementation_,
      salt: salt_
    });

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracle: ISpoke(spokeProxy).ORACLE(),
      spokeImplementation: spokeImplementation_,
      spokeProxy: spokeProxy
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
