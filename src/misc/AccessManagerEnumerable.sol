// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';

contract AccessManagerEnumerable is AccessManager {
  // duplicate reverse map
  mapping(uint64 roleId => mapping(address target => EnumerableSet.Set selectors))
    internal _roleIdToSelectors;

  constructor(address initialAdmin) AccessManager(initialAdmin) {}

  function _grantRole(
    uint64 roleId,
    address account,
    uint32 grantDelay,
    uint32 executionDelay
  ) internal override returns (bool) {}
}
