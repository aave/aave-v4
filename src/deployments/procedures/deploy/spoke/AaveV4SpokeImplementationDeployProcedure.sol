// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

/// @title AaveV4SpokeImplementationDeployProcedure Library
/// @author Aave Labs
/// @notice Deploys a Spoke implementation in its own transaction.
/// @dev A library rather than a batch base: the implementation is close to the 24 KB code size limit, so it does not
///      share a transaction with other contracts on chains with a per-transaction gas cap.
library AaveV4SpokeImplementationDeployProcedure {
  /// @notice Deploys a Spoke implementation via CREATE2.
  /// @param oracle The AaveOracle used by the Spoke instance; must already be deployed.
  /// @param spokeBytecode The creation bytecode of the SpokeInstance contract.
  /// @param maxUserReservesLimit The maximum number of reserves a single user can interact with.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the deployed Spoke implementation.
  function deploySpokeImplementation(
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address) {
    require(oracle != address(0), 'invalid oracle');
    require(maxUserReservesLimit > 0, 'invalid max user reserves limit');
    return
      Create2Utils.create2Deploy({
        salt: salt,
        bytecode: getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
      });
  }

  /// @notice Computes the address `deploySpokeImplementation` deploys to for the same arguments.
  /// @param oracle The AaveOracle used by the Spoke instance.
  /// @param spokeBytecode The creation bytecode of the SpokeInstance contract.
  /// @param maxUserReservesLimit The maximum number of reserves a single user can interact with.
  /// @param salt The CREATE2 salt for deterministic deployment.
  /// @return The address of the Spoke implementation.
  function computeSpokeImplementationAddress(
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal pure returns (address) {
    return
      Create2Utils.computeCreate2Address({
        salt: salt,
        bytecode: getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
      });
  }

  /// @notice Constructs the full init code for a Spoke instance by appending constructor arguments.
  /// @param spokeBytecode The creation bytecode of the Spoke implementation.
  /// @param oracle The oracle address to encode as a constructor argument.
  /// @param maxUserReservesLimit The maximum number of user reserves to encode as a constructor argument.
  /// @return The complete init code with encoded constructor arguments.
  function getSpokeInstanceInitCode(
    bytes memory spokeBytecode,
    address oracle,
    uint16 maxUserReservesLimit
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(spokeBytecode, abi.encode(oracle, maxUserReservesLimit));
  }
}
