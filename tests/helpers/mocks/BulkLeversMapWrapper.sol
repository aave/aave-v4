// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BulkLeversMap} from 'src/libraries/BulkLeversMap.sol';

contract BulkLeversMapWrapper {
  function ASSET_MASK() external pure returns (uint8) {
    return BulkLeversMap.ASSET_MASK;
  }

  function SPOKE_MASK() external pure returns (uint8) {
    return BulkLeversMap.SPOKE_MASK;
  }

  function brake(uint8 bulkLevers, uint8 mask, bool flagUpdated) external pure returns (uint8) {
    return BulkLeversMap.brake(bulkLevers, mask, flagUpdated);
  }

  function release(uint8 bulkLevers, uint8 mask) external pure returns (uint8, bool) {
    return BulkLeversMap.release(bulkLevers, mask);
  }

  function isHeld(uint8 bulkLevers, uint8 mask) external pure returns (bool) {
    return BulkLeversMap.isHeld(bulkLevers, mask);
  }
}
