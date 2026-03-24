// SPDX-License-Identifier: LicenseRef-BUSL
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library RolesValidation {
  function validateNonZeroAddress(address addr) internal pure {
    require(addr != address(0), 'zero address');
  }
}
