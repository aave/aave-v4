// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

interface IBorrowRegistry {
  function isEligible(address borrower) external view returns (bool);
}

contract MockPermissionedBorrowSpokeInstance is SpokeInstance {
  IBorrowRegistry public immutable BORROW_REGISTRY;

  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_,
    IBorrowRegistry borrowRegistry_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) {
    BORROW_REGISTRY = borrowRegistry_;
  }

  function _isBorrowAllowed(
    address,
    address onBehalfOf,
    uint256,
    uint256
  ) internal view override returns (bool) {
    return BORROW_REGISTRY.isEligible(onBehalfOf);
  }
}
