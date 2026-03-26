// SPDX-License-Identifier: MIT
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

abstract contract Create2TestHelper is Test {
  function _etchCreate2Factory() internal {
    vm.etch(
      Create2Utils.CREATE2_FACTORY,
      hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3'
    );
  }
}
