// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Hub} from 'src/hub/Hub.sol';

contract MockHubInstance is Hub {
  bool public constant IS_TEST = true;

  uint64 public immutable HUB_REVISION;

  constructor(uint64 hubRevision_) {
    HUB_REVISION = hubRevision_;
    _disableInitializers();
  }

  function initialize(address authority) external override reinitializer(HUB_REVISION) {
    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
  }
}
