// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeSupplyTest is SpokeBase {
  function test_transferAssetsFrom_revertsWith_AssetNotListed() public {
    address invalidHub = makeAddr('invalidHub');

    vm.expectRevert(ISpoke.AssetNotListed.selector);
    vm.prank(invalidHub);
    spoke1.transferAssetsFrom(daiAssetId, address(tokenList.dai), alice, 1000 ether);
  }

  function test_transferAssetsFrom_fuzz_revertsWith_TransferFromFailed(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectRevert(SafeTransferLib.TransferFromFailed.selector);
    vm.prank(address(hub1));
    spoke1.transferAssetsFrom(daiAssetId, address(tokenList.dai), makeAddr('randomUser'), amount);
  }

  function test_transferAssetsFrom_fuzz_transferFrom(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    uint256 aliceInitialBalance = tokenList.dai.balanceOf(alice);
    uint256 hubInitialBalance = tokenList.dai.balanceOf(address(hub1));
    uint256 spokeInitialBalance = tokenList.dai.balanceOf(address(spoke1));

    vm.prank(address(hub1));
    spoke1.transferAssetsFrom(daiAssetId, address(tokenList.dai), alice, amount);

    assertEq(tokenList.dai.balanceOf(alice), aliceInitialBalance - amount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubInitialBalance + amount);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), spokeInitialBalance);
  }

  function test_transferAssetsFrom_fuzz_transfer(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    deal(address(tokenList.dai), address(spoke1), MAX_SUPPLY_AMOUNT);

    uint256 hubInitialBalance = tokenList.dai.balanceOf(address(hub1));
    uint256 spokeInitialBalance = tokenList.dai.balanceOf(address(spoke1));

    vm.prank(address(hub1));
    spoke1.transferAssetsFrom(daiAssetId, address(tokenList.dai), address(spoke1), amount);

    assertEq(tokenList.dai.balanceOf(address(hub1)), hubInitialBalance + amount);
    assertEq(tokenList.dai.balanceOf(address(spoke1)), spokeInitialBalance - amount);
  }
}
