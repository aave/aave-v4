// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';

/// forge-config: default.isolate = true
contract BaseGasTest is Base {
  function setUp() public virtual override {
    super.setUp();
    _initEnvironment();
  }
}
