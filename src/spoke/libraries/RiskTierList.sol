// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.20;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';

/// @title RiskTierList Library
/// @author Aave Labs
/// @notice Aggregates collateral values into buckets addressed by a reserve's dense collateral risk rank (tier),
/// replacing a runtime sort: iterating set tiers from lowest to highest yields collaterals in ascending risk order.
/// @dev Collaterals sharing a risk are summed into one bucket; ordering within equal risk does not affect the
/// risk premium since each covered unit of value contributes the same `collateralRisk`.
/// @dev Bucket words are never zeroed: a word is only read once its tier bit is set, and the first write to a tier
/// overwrites whatever was in memory. Memory expansion is therefore paid only up to the highest tier touched.
library RiskTierList {
  using LibBit for uint256;

  /// @notice Thrown when the aggregated value of a tier does not fit in `VALUE_BITS`.
  error MaxDataSizeExceeded();

  /// @notice In-memory container: occupancy bitmap over tiers and a pointer to 256 packed (risk, value) words.
  struct List {
    uint256 occupied;
    uint256 slots;
  }

  uint256 internal constant MAX_TIER = 255;
  uint256 internal constant VALUE_BITS = 232;
  uint256 internal constant MAX_VALUE = (1 << VALUE_BITS) - 1;

  /// @notice Reserves 256 words of memory for the buckets without initializing them.
  function init() internal pure returns (List memory self) {
    uint256 slots;
    assembly ('memory-safe') {
      slots := mload(0x40)
      mstore(0x40, add(slots, 0x2000))
    }
    self.slots = slots;
  }

  /// @notice Adds `value` to the bucket of `tier`, tagging it with `risk`.
  /// @dev `tier` must be at most `MAX_TIER`; all reserves of a tier share the same `risk`.
  function add(List memory self, uint256 tier, uint256 risk, uint256 value) internal pure {
    uint256 occupied = self.occupied;
    uint256 bit = 1 << tier;
    uint256 ptr = self.slots + (tier << 5);
    uint256 sum = value;
    if (occupied & bit != 0) {
      uint256 slot;
      assembly ('memory-safe') {
        slot := mload(ptr)
      }
      sum += slot & MAX_VALUE;
    }
    require(sum <= MAX_VALUE, MaxDataSizeExceeded());
    assembly ('memory-safe') {
      mstore(ptr, or(shl(VALUE_BITS, risk), sum))
    }
    self.occupied = occupied | bit;
  }

  /// @notice Pops the lowest occupied tier, returning its risk and aggregated value.
  /// @dev Returns `found = false` once every tier has been consumed.
  function popLowest(
    List memory self
  ) internal pure returns (bool found, uint256 risk, uint256 value) {
    uint256 occupied = self.occupied;
    if (occupied == 0) return (false, 0, 0);
    unchecked {
      uint256 ptr = self.slots + ((occupied & (~occupied + 1)).fls() << 5);
      self.occupied = occupied & (occupied - 1);
      uint256 slot;
      assembly ('memory-safe') {
        slot := mload(ptr)
      }
      return (true, slot >> VALUE_BITS, slot & MAX_VALUE);
    }
  }
}
