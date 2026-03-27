// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Rescuable} from 'src/utils/Rescuable.sol';

contract RescuableWrapper is Rescuable {
  address admin;

  constructor(address admin_) {
    admin = admin_;
  }

  function _rescueGuardian() internal view override returns (address) {
    return admin;
  }
}
