// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/StdInvariant.sol';
import 'forge-std/StdCheats.sol';
import './LiquidityHubHandler.t.sol';

import 'src/contracts/LiquidityHub.sol';

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
  function skip_invariant_reserveTotalAssets() public {
    // TODO: manage asset listed multiple times
    // TODO: manage interest
    LiquidityHub.Asset memory reserveData;
    address asset;
    for (uint256 i = 0; i < hub.assetCount(); i++) {
      reserveData = hub.getAsset(i);
      asset = hub.assetsList(i);
      assertEq(
        reserveData.totalAssets,
        IERC20(asset).balanceOf(address(hub)) - hubHandler.getAssetDonated(asset),
        'wrong total assets'
      );
    }
  }

  /// @dev Exchange rate must be monotonically increasing
  function skip_invariant_exchangeRateMonotonicallyIncreasing() public {
    // TODO this can be improved with borrows OR changes in borrowRate
    LiquidityHub.Asset memory reserveData;
    uint256 calcExchangeRate;
    for (uint256 id = 0; id < hub.assetCount(); id++) {
      reserveData = hub.getAsset(id);
      calcExchangeRate = reserveData.totalShares == 0
        ? 0
        : reserveData.totalAssets / reserveData.totalShares;

      assertTrue(hubHandler.getLastExchangeRate(id) <= calcExchangeRate, 'supply index decrease');
    }
  }
}
