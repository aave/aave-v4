// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/InvariantTest.sol';
import 'forge-std/StdCheats.sol';
import './LiquidityHubHandler.t.sol';

import 'src/contracts/LiquidityHub.sol';

contract LiquidityHubInvariant is InvariantTest, Test {
  LiquidityHubHandler hubHandler;
  LiquidityHub hub;

  function setUp() public {
    hubHandler = new LiquidityHubHandler();
    hub = hubHandler.hub();
    targetContract(address(hubHandler));
    // bytes4[] memory selectors = new bytes4[](1);
    // selectors[0] = LiquidityHubHandler.supply.selector;
    // targetSelector(FuzzSelector({addr: address(hubHandler), selectors: selectors}));
  }

  /// forge-config: default.invariant.fail-on-revert = true
  /// forge-config: default.invariant.runs = 256
  /// forge-config: default.invariant.depth = 500
  /// @dev Virtual Balance must be equal to value returned by IERC20 balanceOf function minus donations
  function invariant_reserveVirtualBalance() public {
    // TODO: manage asset listed multiple times
    LiquidityHub.Reserve memory reserveData;
    address asset;
    for (uint256 i = 0; i < hub.reserveCount(); i++) {
      reserveData = hub.getReserve(i);
      asset = hub.reservesList(i);
      assertEq(
        reserveData.virtualBalance,
        IERC20(asset).balanceOf(address(hub)) - hubHandler.getAssetDonated(asset),
        'wrong virtual balance'
      );
    }
  }

  /// @dev Supply index must be monotonically increasing
  function invariant_supplyIndexMonotonicallyIncreasing() public {
    // TODO this can be improved with borrows OR changes in borrowRate
    LiquidityHub.Reserve memory reserveData;
    for (uint256 id = 0; id < hub.reserveCount(); id++) {
      reserveData = hub.getReserve(id);
      assertTrue(
        hubHandler.getLastSupplyIndex(id) <= reserveData.supplyIndex,
        'supply index decrease'
      );
    }
  }
}
