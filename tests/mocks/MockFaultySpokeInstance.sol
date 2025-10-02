// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke} from 'src/spoke/Spoke.sol';

contract MockFaultySpokeInstance is Spoke {
  uint64 public immutable SPOKE_REVISION = 1;

  constructor(address oracle_) Spoke(oracle_) {
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(address _authority) public override reinitializer(SPOKE_REVISION) {
    require(_authority != address(0), InvalidAddress());
    __AccessManaged_init(_authority);
    super.initialize(_authority);
  }
}
