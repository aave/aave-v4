// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubMoveSuppliedSharesTest is LiquidityHubBase {
  function test_moveSuppliedShares() public {
    test_moveSuppliedShares_fuzz(1000e18, 1000e18);
  }

  function test_moveSuppliedShares_fuzz(uint256 supplyAmount, uint256 moveAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    moveAmount = bound(moveAmount, 1, supplyAmount);

    // supply from spoke1
    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    uint256 suppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    uint256 assetSuppliedShares = hub.getAssetSuppliedShares(daiAssetId);
    assertEq(suppliedShares, hub.convertToSuppliedAssets(daiAssetId, supplyAmount));
    assertEq(suppliedShares, assetSuppliedShares);

    // move supplied shares from spoke1 to spoke2
    vm.prank(address(spoke1));
    hub.transferShares(daiAssetId, moveAmount, address(spoke2));

    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub.getAssetSuppliedShares(daiAssetId), assetSuppliedShares);
  }

  /// @dev Test moving more shares than a spoke has supplied
  function test_moveSuppliedShares_fuzz_exceedingSuppliedShares_revertsWith_SuppliedSharesExceeded(
    uint256 supplyAmount
  ) public {
    uint256 supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT - 1);

    // supply from spoke1
    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    uint256 suppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub.convertToSuppliedAssets(daiAssetId, supplyAmount));

    // try to move more supplied shares than spoke1 has
    vm.prank(address(spoke1));
    vm.expectRevert(
      abi.encodeWithSelector(ILiquidityHub.SuppliedSharesExceeded.selector, suppliedShares)
    );
    hub.transferShares(daiAssetId, suppliedShares + 1, address(spoke2));
  }

  function test_moveSuppliedShares_zeroShares_revertsWith_InvalidSharesAmount() public {
    vm.prank(address(spoke1));
    vm.expectRevert(ILiquidityHub.InvalidSharesAmount.selector);
    hub.transferShares(daiAssetId, 0, address(spoke2));
  }

  function test_moveSuppliedShares_revertsWith_InactiveSpoke() public {
    uint256 supplyAmount = 1000e18;
    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    // deactivate spoke1
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(daiAssetId, address(spoke1));
    spokeConfig.active = false;
    vm.prank(HUB_ADMIN);
    hub.updateSpokeConfig(daiAssetId, address(spoke1), spokeConfig);
    assertFalse(hub.getSpokeConfig(daiAssetId, address(spoke1)).active);

    uint256 suppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub.convertToSuppliedAssets(daiAssetId, supplyAmount));

    // try to move supplied shares from inactive spoke1
    vm.prank(address(spoke1));
    vm.expectRevert(ILiquidityHub.SpokeNotActive.selector);
    hub.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }

  function test_moveSuppliedShares_exceedingCap_revertsWith_InvalidSharesAmount() public {
    uint256 supplyAmount = 1000e18;
    deal(address(tokenList.dai), address(spoke1), supplyAmount);
    Utils.add(hub, daiAssetId, address(spoke1), supplyAmount, address(spoke1));

    uint256 suppliedShares = hub.getSpokeSuppliedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub.convertToSuppliedAssets(daiAssetId, supplyAmount));

    uint256 newSupplyCap = supplyAmount - 1;
    _updateSupplyCap(daiAssetId, address(spoke2), newSupplyCap);

    // attempting transfer of supplied shares exceeding cap on spoke2
    assertLt(
      hub.getSpokeConfig(daiAssetId, address(spoke2)).supplyCap,
      hub.convertToSuppliedAssets(daiAssetId, supplyAmount)
    );

    vm.expectRevert(abi.encodeWithSelector(ILiquidityHub.SupplyCapExceeded.selector, newSupplyCap));
    vm.prank(address(spoke1));
    hub.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }
}
