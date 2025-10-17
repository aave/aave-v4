// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubTransferSharesTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  function test_transferShares() public {
    test_transferShares_fuzz(1000e18, 1000e18);
  }

  function test_transferShares_fuzz(uint256 supplyAmount, uint256 moveAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    moveAmount = bound(moveAmount, 1, supplyAmount);

    // supply from spoke1
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 assetSuppliedShares = hub1.getAddedShares(daiAssetId);
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));
    assertEq(suppliedShares, assetSuppliedShares);

    vm.expectEmit(address(hub1));
    emit IHubBase.TransferShares(daiAssetId, address(spoke1), address(spoke2), moveAmount);

    // transfer supplied shares from spoke1 to spoke2
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, moveAmount, address(spoke2));

    assertBorrowRateSynced(hub1, daiAssetId, 'transferShares');
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub1.getAddedShares(daiAssetId), assetSuppliedShares);
  }

  /// @dev Test transferring more shares than a spoke has supplied
  function test_transferShares_fuzz_revertsWith_AddedSharesExceeded(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT - 1);

    // supply from spoke1
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    // try to transfer more supplied shares than spoke1 has
    vm.prank(address(spoke1));
    vm.expectRevert(abi.encodeWithSelector(IHub.AddedSharesExceeded.selector, suppliedShares));
    hub1.transferShares(daiAssetId, suppliedShares + 1, address(spoke2));
  }

  function test_transferShares_zeroShares_revertsWith_InvalidShares() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.transferShares(daiAssetId, 0, address(spoke2));
  }

  function test_transferShares_revertsWith_SpokeNotActive() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // deactivate spoke1
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(daiAssetId, address(spoke1));
    spokeConfig.active = false;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);
    assertFalse(hub1.getSpokeConfig(daiAssetId, address(spoke1)).active);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    // try to transfer supplied shares from inactive spoke1
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokeNotActive.selector);
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }

  function test_transferShares_revertsWith_SpokePaused() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // pause spoke1
    IHub.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(daiAssetId, address(spoke1));
    spokeConfig.paused = true;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);
    assertTrue(hub1.getSpokeConfig(daiAssetId, address(spoke1)).paused);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    // try to transfer supplied shares from paused spoke1
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokePaused.selector);
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }

  function test_transferShares_revertsWith_AddCapExceeded() public {
    uint40 newSupplyCap = 1000;

    uint256 supplyAmount = newSupplyCap * 10 ** tokenList.dai.decimals() + 1;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    _updateAddCap(daiAssetId, address(spoke2), newSupplyCap);

    // attempting transfer of supplied shares exceeding cap on spoke2
    assertLt(
      hub1.getSpokeConfig(daiAssetId, address(spoke2)).addCap,
      hub1.previewRemoveByShares(daiAssetId, supplyAmount)
    );

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }
}
