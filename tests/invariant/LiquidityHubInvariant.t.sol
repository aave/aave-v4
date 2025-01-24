// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/StdInvariant.sol';
import './LiquidityHubHandler.t.sol';

import {LiquidityHub} from 'src/contracts/LiquidityHub.sol';

contract LiquidityHubInvariant is StdInvariant, Test {
  LiquidityHubHandler hubHandler;
  LiquidityHub hub;

  function setUp() public {
    hubHandler = new LiquidityHubHandler();
    hub = hubHandler.hub();
    targetContract(address(hubHandler));
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = LiquidityHubHandler.supply.selector;
    targetSelector(FuzzSelector({addr: address(hubHandler), selectors: selectors}));
  }

  /// forge-config: default.invariant.fail-on-revert = true
  /// forge-config: default.invariant.runs = 256
  /// forge-config: default.invariant.depth = 500
  /// @dev Reserve total assets must be equal to value returned by IERC20 balanceOf function minus donations
  function invariant_reserveTotalAssets() public {
    vm.skip(true);
    // TODO: manage asset listed multiple times
    // TODO: manage interest
    for (uint256 i; i < hub.assetCount(); ++i) {
      Asset memory reserveData = hub.getAsset(i);
      IERC20 asset = hub.assetsList(i);
      assertEq(
        hub.getTotalAssets(reserveData.id),
        asset.balanceOf(address(hub)) - hubHandler.getAssetDonated(address(asset)),
        'wrong total assets'
      );
    }
  }

  /// @dev Exchange rate must be monotonically increasing
  function invariant_exchangeRateMonotonicallyIncreasing() public {
    vm.skip(true);
    // TODO this can be improved with borrows OR changes in borrowRate
    for (uint256 id = 0; id < hub.assetCount(); id++) {
      Asset memory reserveData = hub.getAsset(id);
      uint256 calcExchangeRate = reserveData.suppliedShares == 0
        ? 0
        : hub.getTotalAssets(reserveData.id) / reserveData.suppliedShares;

      assertTrue(hubHandler.getLastExchangeRate(id) <= calcExchangeRate, 'supply index decrease');
    }
  }
}
