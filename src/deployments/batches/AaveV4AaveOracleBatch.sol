// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {AaveV4SpokeImplementationDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeImplementationDeployProcedure.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

/// @title AaveV4AaveOracleBatch
/// @author Aave Labs
/// @notice Deploys the AaveOracle of a Spoke and binds it to the Spoke proxy's predicted address, producing a batch report.
/// @dev The Spoke implementation reads the oracle in its constructor, so the oracle comes first. Only the oracle
///      deployer can call `setSpoke`, so this batch binds the Spoke proxy before it exists, using the CREATE2
///      addresses that `AaveV4SpokeImplementationDeployProcedure` and `AaveV4SpokeInstanceBatch` later deploy to.
///      `AaveV4SpokeInstanceBatch` checks the binding once the proxy is deployed.
contract AaveV4AaveOracleBatch is AaveV4AaveOracleDeployProcedure, AaveV4SpokeDeployProcedure {
  BatchReports.AaveOracleBatchReport internal _report;

  /// @dev Constructor.
  /// @param proxyAdminOwner_ The owner of the Spoke proxy admin.
  /// @param authority_ The access-control authority for the Spoke.
  /// @param spokeBytecode_ The creation bytecode of the SpokeInstance contract.
  /// @param oracleDecimals_ The decimal precision for the AaveOracle.
  /// @param maxUserReservesLimit_ The maximum number of reserves a user can interact with.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address proxyAdminOwner_,
    address authority_,
    bytes memory spokeBytecode_,
    uint8 oracleDecimals_,
    uint16 maxUserReservesLimit_,
    bytes32 salt_
  ) {
    require(proxyAdminOwner_ != address(0), 'invalid proxy admin owner');
    require(authority_ != address(0), 'invalid authority');
    require(maxUserReservesLimit_ > 0, 'invalid max user reserves limit');

    address aaveOracle = _deployAaveOracle(oracleDecimals_, salt_);
    address spokeImplementation = AaveV4SpokeImplementationDeployProcedure
      .computeSpokeImplementationAddress({
        oracle: aaveOracle,
        spokeBytecode: spokeBytecode_,
        maxUserReservesLimit: maxUserReservesLimit_,
        salt: salt_
      });
    address spokeProxy = _computeSpokeProxyAddress({
      proxyAdminOwner: proxyAdminOwner_,
      authority: authority_,
      spokeImplementation: spokeImplementation,
      salt: salt_
    });
    IAaveOracle(aaveOracle).setSpoke(spokeProxy);

    _report = BatchReports.AaveOracleBatchReport({
      aaveOracle: aaveOracle,
      spokeImplementation: spokeImplementation,
      spokeProxy: spokeProxy
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.AaveOracleBatchReport memory) {
    return _report;
  }
}
