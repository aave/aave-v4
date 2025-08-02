// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubTransferSharesTest is HubBase {
  function test_transferShares() public {
    test_transferShares_fuzz(1000e18, 1000e18);
  }

  function test_transferShares_fuzz(uint256 supplyAmount, uint256 moveAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    moveAmount = bound(moveAmount, 1, supplyAmount);

    // supply from spoke1
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 assetSuppliedShares = hub1.getAssetAddedShares(daiAssetId);
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));
    assertEq(suppliedShares, assetSuppliedShares);

    // transfer supplied shares from spoke1 to spoke2
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, moveAmount, address(spoke2));

    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub1.getAssetAddedShares(daiAssetId), assetSuppliedShares);
  }

  /// @dev Test transferring more shares than a spoke has supplied
  function test_transferShares_fuzz_revertsWith_AddedSharesExceeded(uint256 supplyAmount) public {
    uint256 supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT - 1);

    // supply from spoke1
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));

    // try to transfer more supplied shares than spoke1 has
    vm.prank(address(spoke1));
    vm.expectRevert(abi.encodeWithSelector(IHub.AddedSharesExceeded.selector, suppliedShares));
    hub1.transferShares(daiAssetId, suppliedShares + 1, address(spoke2));
  }

  function test_transferShares_zeroShares_revertsWith_InvalidSharesAmount() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidSharesAmount.selector);
    hub1.transferShares(daiAssetId, 0, address(spoke2));
  }

  function test_transferShares_revertsWith_InactiveSpoke() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // deactivate spoke1
    DataTypes.SpokeConfig memory spokeConfig = hub1.getSpokeConfig(daiAssetId, address(spoke1));
    spokeConfig.active = false;
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);
    assertFalse(hub1.getSpokeConfig(daiAssetId, address(spoke1)).active);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));

    // try to transfer supplied shares from inactive spoke1
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokeNotActive.selector);
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }

  function test_transferShares_revertsWith_AddCapExceeded() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));

    uint256 newSupplyCap = supplyAmount - 1;
    _updateAddCap(daiAssetId, address(spoke2), newSupplyCap);

    // attempting transfer of supplied shares exceeding cap on spoke2
    assertLt(
      hub1.getSpokeConfig(daiAssetId, address(spoke2)).addCap,
      hub1.convertToAddedAssets(daiAssetId, supplyAmount)
    );

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }
}
