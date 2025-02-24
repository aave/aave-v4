// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';
import {Spoke} from 'src/contracts/Spoke.sol';

contract SpokeBaseTest is BaseTest {
  function setUp() public virtual override {
    super.setUp();
    initEnvironment();
  }
}
