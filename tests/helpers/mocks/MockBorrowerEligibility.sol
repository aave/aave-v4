// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IBorrowerEligibility} from 'src/access/interfaces/IBorrowerEligibility.sol';

contract MockBorrowerEligibility is IBorrowerEligibility {
  mapping(address account => bool) internal _eligible;

  function setEligible(address account, bool eligible) external {
    _eligible[account] = eligible;
  }

  function isEligible(address account) external view returns (bool) {
    return _eligible[account];
  }
}
