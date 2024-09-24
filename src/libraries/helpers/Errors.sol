// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title Errors library
 * @author Aave Labs
 * @notice Defines the error messages emitted by the different contracts of the Aave protocol
 */
library Errors {
  string public constant ZERO_ADDRESS_NOT_VALID = '77'; // 'Zero address not valid'

  string public constant INVALID_MAX_RATE = '92'; // The expect maximum borrow rate is invalid
  string public constant SLOPE_2_MUST_BE_GTE_SLOPE_1 = '95'; // Variable interest rate slope 2 can not be lower than slope 1
  string public constant INVALID_OPTIMAL_USAGE_RATIO = '83'; // 'Invalid optimal usage ratio'
  string public constant INVALID_ASSET_ID = '84'; // 'Invalid asset id'
}
