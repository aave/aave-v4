// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// @dev Shared setup + state for Spoke Operations gas tests.
abstract contract SpokeOperationsGasBase is SpokeBase {
  string internal NAMESPACE = 'Spoke.Operations';
  ReserveIds internal reserveId;
  ISpoke internal spoke;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
    spoke = spoke1;
    reserveId = _getReserveIds(spoke);
    _seed();
    _afterSetUp();
  }

  function _afterSetUp() internal virtual {}

  function _seed() internal {
    vm.startPrank(address(spoke2));
    tokenList.dai.transferFrom(bob, address(hub1), 10000e18);
    hub1.add(daiAssetId, 10000e18);
    tokenList.weth.transferFrom(bob, address(hub1), 1000e18);
    hub1.add(wethAssetId, 1000e18);
    tokenList.usdx.transferFrom(bob, address(hub1), 1000e6);
    hub1.add(usdxAssetId, 1000e6);
    tokenList.wbtc.transferFrom(bob, address(hub1), 1000e8);
    hub1.add(wbtcAssetId, 1000e8);
    vm.stopPrank();
  }
}
