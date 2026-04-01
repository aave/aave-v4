// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeHelpers} from 'tests/helpers/spoke/SpokeHelpers.sol';
import {IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ITokenizationSpoke} from 'src/spoke/TokenizationSpoke.sol';

/// @title Assertions
/// @notice Assertion utilities for tokenization spoke tests.
abstract contract Assertions is SpokeHelpers {
  function _assertVaultHasNoBalanceOrAllowance(ITokenizationSpoke vault, address who) internal {
    _assertEntityHasNoBalanceOrAllowance({
      underlying: IERC20(vault.asset()),
      entity: address(vault),
      user: who
    });
  }
}
