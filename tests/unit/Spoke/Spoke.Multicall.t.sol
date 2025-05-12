// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {Multicall} from 'src/dependencies/openzeppelin/Multicall.sol';

contract SpokeMulticall is SpokeBase {
  /// Supply and set collateral using multicall
  function test_multicall_supply_setCollateral() public {
    uint256 daiReserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 1e18;

    // Set up the multicall
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature('supply(uint256,uint256)', daiReserveId, supplyAmount);
    calls[1] = abi.encodeWithSignature('setUsingAsCollateral(uint256,bool)', daiReserveId, true);

    // Execute the multicall
    vm.startPrank(bob);
    Multicall(address(spoke1)).multicall(calls);
    vm.stopPrank();

    // Check the supply
    uint256 bobSupplied = spoke1.getUserSuppliedAmount(daiReserveId, bob);
    assertEq(bobSupplied, supplyAmount, 'Bob supplied dai amount');

    // Check the collateral
    assertEq(spoke1.getUsingAsCollateral(daiReserveId, bob), true, 'Bob using as collateral');
  }
}
