// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/position-manager/PermissionedPositionManager/PermissionedPositionManager.t.sol';
import {ExtendedPermissionedPositionManager} from 'src/position-manager/ExtendedPermissionedPositionManager.sol';

/// @dev Inherits the PermissionedPositionManager tests to check the extended version behaves the same for direct calls.
contract ExtendedPermissionedPositionManagerTest is PermissionedPositionManagerTest {
  address public relayer = makeAddr('relayer');

  function setUp() public override {
    super.setUp();

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(relayer, true);
    vm.prank(alice);
    spoke1.setUserPositionManager(relayer, true);

    vm.startPrank(relayer);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);
    tokenList.usdx.approve(address(positionManager), UINT256_MAX);
    vm.stopPrank();
  }

  function _deployImplementation() internal override returns (PermissionedPositionManager) {
    return new ExtendedPermissionedPositionManager(address(spoke1));
  }

  function test_relayed_supply() public {
    deal(address(tokenList.dai), relayer, 100e18);

    vm.expectEmit(address(spoke1));
    emit ISpoke.Supply(
      daiReserveId,
      address(positionManager),
      alice,
      hub1.previewAddByAssets(daiAssetId, 100e18),
      100e18
    );
    vm.prank(relayer);
    positionManager.supply(daiReserveId, 100e18, alice);

    assertEq(tokenList.dai.balanceOf(relayer), 0);
    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 100e18);
  }

  function test_relayed_withdraw_to_relayer() public {
    vm.prank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);

    vm.prank(relayer);
    positionManager.withdraw(daiReserveId, UINT256_MAX, alice);

    assertEq(tokenList.dai.balanceOf(relayer), 100e18);
    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 0);
  }

  function test_relayed_borrow_to_relayer() public {
    vm.startPrank(alice);
    positionManager.supply(daiReserveId, 100e18, alice);
    positionManager.setUsingAsCollateral(daiReserveId, true, alice);
    vm.stopPrank();

    vm.prank(relayer);
    positionManager.borrow(usdxReserveId, 10e6, alice);

    assertEq(tokenList.usdx.balanceOf(relayer), 10e6);
    assertEq(spoke1.getUserTotalDebt(usdxReserveId, alice), 10e6);
  }

  function test_relayed_repay_from_relayer() public {
    _openBorrowPosition(alice, 100e18, 10e6);
    deal(address(tokenList.usdx), relayer, 10e6);

    vm.prank(relayer);
    positionManager.repay(usdxReserveId, UINT256_MAX, alice);

    assertEq(tokenList.usdx.balanceOf(relayer), 0);
    assertEq(spoke1.getUserTotalDebt(usdxReserveId, alice), 0);
  }

  function test_relayed_revertsWith_Unauthorized_not_approved_fuzz(uint256 actionSeed) public {
    vm.prank(alice);
    spoke1.setUserPositionManager(relayer, false);

    vm.expectRevert(IPermissionedPositionManager.Unauthorized.selector);
    _callAction(_boundUserAction(actionSeed), relayer, alice);
  }

  function test_relayed_revertsWith_Unauthorized_inactive_relayer_fuzz(uint256 actionSeed) public {
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(relayer, false);

    vm.expectRevert(IPermissionedPositionManager.Unauthorized.selector);
    _callAction(_boundUserAction(actionSeed), relayer, alice);
  }

  function test_relayed_revertsWith_Unauthorized_exclusive_fuzz(uint256 actionSeed) public {
    vm.prank(ADMIN);
    spoke1.updateMandatoryPositionManager(address(positionManager), true);

    vm.expectRevert(IPermissionedPositionManager.Unauthorized.selector);
    _callAction(_boundUserAction(actionSeed), relayer, alice);
  }

  function test_exclusive_allows_direct_calls() public {
    vm.prank(ADMIN);
    spoke1.updateMandatoryPositionManager(address(positionManager), true);

    vm.prank(alice);
    positionManager.supply(daiReserveId, 1e18, alice);

    assertEq(spoke1.getUserSuppliedAssets(daiReserveId, alice), 1e18);
  }

  function test_relayed_permission_checked_against_position_owner() public {
    _setPermissioned(IPermissionedPositionManager.Action.SetUsingAsCollateral);
    _approveCaller(relayer);

    vm.expectRevert(IPermissionedPositionManager.CallerNotApproved.selector);
    _callAction(IPermissionedPositionManager.Action.SetUsingAsCollateral, relayer, alice);

    _approveCaller(alice);
    vm.prank(alice);
    positionManager.supply(daiReserveId, 1e18, alice);
    vm.prank(relayer);
    positionManager.setUsingAsCollateral(daiReserveId, true, alice);

    assertTrue(_isUsingAsCollateral(spoke1, daiReserveId, alice));
  }
}
