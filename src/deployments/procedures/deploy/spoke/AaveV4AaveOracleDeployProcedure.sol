// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {AaveV4AaveOracleDeployer} from 'src/deployments/utils/AaveV4AaveOracleDeployer.sol';

/// @title AaveV4AaveOracleDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys the AaveOracle of a Spoke through an AaveV4AaveOracleDeployer and binds it to the Spoke.
library AaveV4AaveOracleDeployProcedure {
  /// @notice Deploys an AaveV4AaveOracleDeployer via CREATE2, which deploys the AaveOracle.
  /// @param owner The account allowed to bind the AaveOracle to its Spoke.
  /// @param decimals The number of decimals for the oracle price feed.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return aaveOracleDeployer The address of the deployed AaveV4AaveOracleDeployer.
  /// @return aaveOracle The address of the deployed AaveOracle.
  function deployAaveOracle(
    address owner,
    uint8 decimals,
    bytes32 salt
  ) internal returns (address aaveOracleDeployer, address aaveOracle) {
    // the CREATE2 factory drops revert reasons, so repeat the deployer's input checks here
    require(owner != address(0), 'invalid owner');
    require(decimals > 0, 'invalid oracle decimals');
    aaveOracleDeployer = Create2Utils.create2Deploy({
      salt: salt,
      bytecode: abi.encodePacked(
        type(AaveV4AaveOracleDeployer).creationCode,
        abi.encode(owner, decimals, salt)
      )
    });
    aaveOracle = AaveV4AaveOracleDeployer(aaveOracleDeployer).AAVE_ORACLE();
  }

  /// @notice Binds the AaveOracle deployed by `aaveOracleDeployer` to `spoke`.
  /// @dev Must be called by the `owner` passed to `deployAaveOracle`.
  /// @param aaveOracleDeployer The address of the AaveV4AaveOracleDeployer.
  /// @param spoke The address of the Spoke proxy using the AaveOracle.
  function setAaveOracleSpoke(address aaveOracleDeployer, address spoke) internal {
    AaveV4AaveOracleDeployer(aaveOracleDeployer).setSpoke(spoke);
  }
}
