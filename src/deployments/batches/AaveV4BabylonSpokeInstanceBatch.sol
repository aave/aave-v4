// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

/// @title AaveV4BabylonSpokeInstanceBatch
/// @author Aave Labs
/// @notice Deploys a BabylonSpoke (proxy + implementation) and its AaveOracle, producing a batch report.
/// @dev Reuses the canonical Spoke deploy procedure: the BabylonSpoke instance has the identical
/// constructor and initializer.
contract AaveV4BabylonSpokeInstanceBatch is
  AaveV4SpokeDeployProcedure,
  AaveV4AaveOracleDeployProcedure
{
  BatchReports.SpokeInstanceBatchReport internal _report;

  /// @dev Constructor.
  /// @param proxyAdminOwner_ The owner of the proxy admin.
  /// @param authority_ The access-control authority for the BabylonSpoke.
  /// @param babylonSpokeBytecode_ The creation bytecode of the BabylonSpoke implementation.
  /// @param oracleDecimals_ The decimal precision for the AaveOracle.
  /// @param maxUserReservesLimit_ The maximum number of reserves a user can interact with.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(
    address proxyAdminOwner_,
    address authority_,
    bytes memory babylonSpokeBytecode_,
    uint8 oracleDecimals_,
    uint16 maxUserReservesLimit_,
    bytes32 salt_
  ) {
    address aaveOracle = _deployAaveOracle(oracleDecimals_);
    (address spokeProxy, address spokeImplementation) = _deployUpgradeableSpokeInstance({
      proxyAdminOwner: proxyAdminOwner_,
      authority: authority_,
      oracle: aaveOracle,
      spokeBytecode: babylonSpokeBytecode_,
      salt: salt_,
      maxUserReservesLimit: maxUserReservesLimit_
    });
    IAaveOracle(aaveOracle).setSpoke(spokeProxy);

    require(ISpoke(spokeProxy).ORACLE() == aaveOracle, 'spoke oracle mismatch');
    require(IAaveOracle(aaveOracle).spoke() == spokeProxy, 'oracle spoke mismatch');

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracle: aaveOracle,
      spokeImplementation: spokeImplementation,
      spokeProxy: spokeProxy
    });
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
