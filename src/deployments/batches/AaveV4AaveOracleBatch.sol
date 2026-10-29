// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

/// @title AaveV4AaveOracleBatch
/// @author Aave Labs
/// @notice Deploys the AaveOracle of a Spoke and later binds it to the Spoke, producing a batch report.
/// @dev The Spoke implementation reads the oracle in its constructor, so the oracle comes first and the Spoke
///      implementation and proxy follow in their own transactions. Only the oracle's deployer can call
///      `AaveOracle.setSpoke`, so this batch stays the deployer and exposes `setSpoke` to `owner`.
///      `AaveOracle.setSpoke` is one-shot, so `setSpoke` here can succeed only once.
contract AaveV4AaveOracleBatch is AaveV4AaveOracleDeployProcedure {
  /// @notice The only account allowed to call `setSpoke`.
  address public immutable OWNER;

  BatchReports.AaveOracleBatchReport internal _report;

  /// @dev Constructor.
  /// @param owner_ The account allowed to bind the AaveOracle to its Spoke.
  /// @param oracleDecimals_ The decimal precision for the AaveOracle.
  /// @param salt_ The CREATE2 salt for deterministic deployment.
  constructor(address owner_, uint8 oracleDecimals_, bytes32 salt_) {
    require(owner_ != address(0), 'invalid owner');
    OWNER = owner_;
    _report = BatchReports.AaveOracleBatchReport({
      aaveOracleBatch: address(this),
      aaveOracle: _deployAaveOracle(oracleDecimals_, salt_)
    });
  }

  /// @notice Binds the AaveOracle to its Spoke.
  /// @dev `AaveOracle.setSpoke` checks that the Spoke uses this oracle and that no Spoke is bound yet.
  /// @param spoke The address of the Spoke proxy using the AaveOracle.
  function setSpoke(address spoke) external {
    require(msg.sender == OWNER, 'only owner');
    IAaveOracle(_report.aaveOracle).setSpoke(spoke);
  }

  /// @notice Returns the batch deployment report.
  function getReport() external view returns (BatchReports.AaveOracleBatchReport memory) {
    return _report;
  }
}
