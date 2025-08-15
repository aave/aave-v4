// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/StdInvariant.sol';
import './HubHandler.t.sol';

import {Hub} from 'src/contracts/Hub.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

contract HubInvariant is StdInvariant, Test {
  HubHandler hubHandler;
  Hub hub1;

  function setUp() public {
    hubHandler = new HubHandler();
    hub1 = hubHandler.hub1();
    targetContract(address(hubHandler));
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = HubHandler.supply.selector;
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
    for (uint256 i; i < hub1.getAssetCount(); ++i) {
      DataTypes.Asset memory reserveData = hub1.getAsset(i);
      address underlying = hub1.getAsset(i).underlying;
      // todo implement
      // assertEq(
      //   hub1.getTotalAssets(reserveData.id),
      //   IERC20(underlying).balanceOf(address(hub)) - hubHandler.getAssetDonated(underlying),
      //   'wrong total assets'
      // );
    }
  }

  /// @dev Exchange rate must be monotonically increasing
  function invariant_exchangeRateMonotonicallyIncreasing() public {
    vm.skip(true);
    // TODO this can be improved with borrows OR changes in borrowRate
    for (uint256 id = 0; id < hub1.getAssetCount(); id++) {
      DataTypes.Asset memory reserveData = hub1.getAsset(id);
      // todo migrate
      // uint256 calcExchangeRate = reserveData.suppliedShares == 0
      //   ? 0
      //   : hub1.getTotalAssets(reserveData.id) / reserveData.suppliedShares;

      // assertTrue(hubHandler.getLastExchangeRate(id) <= calcExchangeRate, 'supply index decrease');
    }
  }
}
