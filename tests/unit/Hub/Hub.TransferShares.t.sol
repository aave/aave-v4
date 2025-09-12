// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubTransferSharesTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  uint256 zeroDecimalAssetId;

  function setUp() public override {
    super.setUp();

    /// @dev add a zero decimal asset to test add cap rounding
    DataTypes.SpokeConfig memory spokeConfig = DataTypes.SpokeConfig({
      active: true,
      addCap: Constants.MAX_CAP,
      drawCap: Constants.MAX_CAP
    });
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.startPrank(ADMIN);
    zeroDecimalAssetId = hub1.addAsset(
      address(tokenList.dai),
      0,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      zeroDecimalAssetId,
      DataTypes.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      })
    );
    hub1.addSpoke(zeroDecimalAssetId, address(spoke1), spokeConfig);
    hub1.addSpoke(zeroDecimalAssetId, address(spoke2), spokeConfig);
    vm.stopPrank();
  }

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

    assertBorrowRateSynced(hub1, daiAssetId, 'transferShares');
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub1.getAssetAddedShares(daiAssetId), assetSuppliedShares);
  }

  /// @dev Test transferring more shares than a spoke has supplied
  function test_transferShares_fuzz_revertsWith_AddedSharesExceeded(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT - 1);

    // supply from spoke1
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));

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
    uint56 newSupplyCap = 1000;

    uint256 supplyAmount = newSupplyCap * 10 ** tokenList.dai.decimals() + 1;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.convertToAddedAssets(daiAssetId, supplyAmount));

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

  /// transferShares reverts if the cap is exceeded, with proper rounding (up) applied to shares into assets conversion
  function test_transferShares_revertsWith_AddCapExceeded_due_to_rounding() public {
    _addLiquidity(zeroDecimalAssetId, 100e18);
    _drawLiquidity(zeroDecimalAssetId, 45e18, true);

    uint256 totalAddedAssets = hub1.getAssetAddedAmount(zeroDecimalAssetId);
    uint256 totalAddedShares = hub1.getAssetAddedShares(zeroDecimalAssetId);

    uint256 addedAmount = uint256(1e4).toAssetsDown(totalAddedAssets, totalAddedShares) + 1;
    uint256 addedShares = hub1.convertToAddedShares(zeroDecimalAssetId, addedAmount);

    Utils.add({
      hub: hub1,
      assetId: zeroDecimalAssetId,
      caller: address(spoke1),
      amount: addedAmount,
      user: alice
    });

    Utils.add({
      hub: hub1,
      assetId: zeroDecimalAssetId,
      caller: address(spoke2),
      amount: addedAmount,
      user: alice
    });

    uint56 newAddCap = (2 * addedAmount - 1).toUint56();
    _updateAddCap(zeroDecimalAssetId, address(spoke1), newAddCap);

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke2));
    hub1.transferShares(zeroDecimalAssetId, addedShares, address(spoke1));

    // Assert than with rounding down we would have match the cap
    uint256 previewRemoveAmount = hub1.previewRemoveByShares(zeroDecimalAssetId, addedShares * 2);
    assertEq(previewRemoveAmount, newAddCap);
  }
}
