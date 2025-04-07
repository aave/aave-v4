// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Aave Labs
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
  error ZERO_ADDRESS_NOT_VALID();
  error INVALID_MAX_RATE();
  error SLOPE_2_MUST_BE_GTE_SLOPE_1();
  error INVALID_OPTIMAL_USAGE_RATIO();
  error INVALID_ASSET_ID();
}
