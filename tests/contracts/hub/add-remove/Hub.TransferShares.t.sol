// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract HubTransferSharesTest is Base {
  using SharesMath for uint256;
  using SafeCast for uint256;

  function test_transferShares() public {
    test_transferShares_fuzz(1000e18, 1000e18);
  }

  function test_transferShares_fuzz(uint256 supplyAmount, uint256 moveAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    moveAmount = bound(moveAmount, 1, supplyAmount);

    // supply from spoke1
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 assetSuppliedShares = hub1.getAddedShares(daiAssetId);
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));
    assertEq(suppliedShares, assetSuppliedShares);

    vm.expectEmit(address(hub1));
    emit IHubBase.TransferShares(daiAssetId, address(spoke1), address(spoke2), moveAmount);

    // transfer supplied shares from spoke1 to spoke2
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, moveAmount, address(spoke2));

    _assertDrawnRateSynced(hub1, daiAssetId, 'transferShares');
    _assertHubLiquidity(hub1, daiAssetId, 'transferShares');
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke1)), suppliedShares - moveAmount);
    assertEq(hub1.getSpokeAddedShares(daiAssetId, address(spoke2)), moveAmount);
    assertEq(hub1.getAddedShares(daiAssetId), assetSuppliedShares);
  }

  /// @dev Test transferring more shares than a spoke has supplied
  function test_transferShares_fuzz_revertsWith_underflow_spoke_added_shares_exceeded(
    uint256 supplyAmount
  ) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT - 1);

    // supply from spoke1
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    // try to transfer more supplied shares than spoke1 has
    vm.prank(address(spoke1));
    vm.expectRevert(stdError.arithmeticError);
    hub1.transferShares(daiAssetId, suppliedShares + 1, address(spoke2));
  }

  function test_transferShares_zeroShares_revertsWith_InvalidShares() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.transferShares(daiAssetId, 0, address(spoke2));
  }

  function test_transferShares_revertsWith_SpokeNotActive() public {
    uint256 supplyAmount = 1000e18;
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

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

  function test_transferShares_revertsWith_SpokeHalted() public {
    uint256 supplyAmount = 1000e18;
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    // halt spoke1
    _updateSpokeHalted(hub1, daiAssetId, address(spoke1), true);

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    // try to transfer supplied shares from halted spoke1
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokeHalted.selector);
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }

  function test_transferShares_revertsWith_AddCapExceeded() public {
    uint40 newAddCap = 1000;

    uint256 supplyAmount = newAddCap * 10 ** tokenList.dai.decimals() + 1;
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    uint256 suppliedShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(suppliedShares, hub1.previewRemoveByShares(daiAssetId, supplyAmount));

    _updateAddCap(hub1, daiAssetId, address(spoke2), newAddCap);

    // attempting transfer of supplied shares exceeding cap on spoke2
    assertLt(
      hub1.getSpokeConfig(daiAssetId, address(spoke2)).addCap,
      hub1.previewRemoveByShares(daiAssetId, supplyAmount)
    );

    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, suppliedShares, address(spoke2));
  }
}
