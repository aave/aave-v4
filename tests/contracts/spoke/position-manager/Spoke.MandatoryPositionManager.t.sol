// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract SpokeMandatoryPositionManagerTest is Base {
  address internal mandatoryPositionManager = makeAddr('mandatoryPositionManager');
  address internal otherPositionManager = makeAddr('otherPositionManager');
  address internal liquidator = makeAddr('liquidator');

  function setUp() public virtual override {
    super.setUp();

    vm.startPrank(SPOKE_ADMIN);
    spoke1.updatePositionManager(mandatoryPositionManager, true);
    spoke1.updatePositionManager(otherPositionManager, true);
    vm.stopPrank();
  }

  function test_updateMandatoryPositionManager() public {
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateMandatoryPositionManager(mandatoryPositionManager, true);
    _setMandatory(mandatoryPositionManager, true);

    assertEq(spoke1.getMandatoryPositionManager(), mandatoryPositionManager);
    assertTrue(spoke1.isPositionManagerExclusive(mandatoryPositionManager));

    // setting the current one again updates its exclusive flag
    _setMandatory(mandatoryPositionManager, false);
    assertFalse(spoke1.isPositionManagerExclusive(mandatoryPositionManager));

    // replacing requires to deactivate and remove the current one first
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(mandatoryPositionManager, false);
    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateMandatoryPositionManager(address(0), false);
    _setMandatory(address(0), false);
    assertEq(spoke1.getMandatoryPositionManager(), address(0));

    _setMandatory(otherPositionManager, true);
    assertEq(spoke1.getMandatoryPositionManager(), otherPositionManager);
    assertFalse(spoke1.isPositionManagerExclusive(mandatoryPositionManager));
    assertTrue(spoke1.isPositionManagerExclusive(otherPositionManager));
  }

  function test_updateMandatoryPositionManager_revertsWith_MandatoryPositionManagerAlreadySet()
    public
  {
    _setMandatory(mandatoryPositionManager, false);

    vm.expectRevert(ISpoke.MandatoryPositionManagerAlreadySet.selector);
    _setMandatory(otherPositionManager, false);

    // still blocked once deactivated, until removed
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(mandatoryPositionManager, false);
    vm.expectRevert(ISpoke.MandatoryPositionManagerAlreadySet.selector);
    _setMandatory(otherPositionManager, false);
  }

  function test_updateMandatoryPositionManager_revertsWith_MandatoryPositionManagerActive() public {
    _setMandatory(mandatoryPositionManager, false);

    vm.expectRevert(ISpoke.MandatoryPositionManagerActive.selector);
    _setMandatory(address(0), false);
  }

  function test_updateMandatoryPositionManager_revertsWith_PositionManagerNotActive() public {
    vm.expectRevert(ISpoke.PositionManagerNotActive.selector);
    _setMandatory(makeAddr('inactive'), false);
  }

  function test_updateMandatoryPositionManager_revertsWith_AccessManagedUnauthorized() public {
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke1.updateMandatoryPositionManager(mandatoryPositionManager, false);
  }

  function test_isPositionManager_with_mandatory() public {
    vm.prank(alice);
    spoke1.setUserPositionManager(otherPositionManager, true);
    assertTrue(spoke1.isPositionManager(alice, alice));
    assertTrue(spoke1.isPositionManager(alice, otherPositionManager));
    assertFalse(spoke1.isPositionManager(alice, mandatoryPositionManager));

    _setMandatory(mandatoryPositionManager, false);

    assertFalse(spoke1.isPositionManager(alice, alice));
    assertFalse(spoke1.isPositionManager(alice, otherPositionManager));
    assertTrue(spoke1.isPositionManager(alice, mandatoryPositionManager));
    // raw approval is still readable for relaying position managers
    assertTrue(spoke1.isPositionManagerApproved(alice, otherPositionManager));
    assertFalse(spoke1.isPositionManagerApproved(alice, mandatoryPositionManager));
  }

  function test_mandatory_acts_without_user_approval() public {
    _setMandatory(mandatoryPositionManager, true);
    uint256 reserveId = _daiReserveId(spoke1);
    deal(address(tokenList.dai), mandatoryPositionManager, 1e18);

    vm.startPrank(mandatoryPositionManager);
    tokenList.dai.approve(address(spoke1), 1e18);
    spoke1.supply(reserveId, 1e18, alice);
    vm.stopPrank();

    assertEq(spoke1.getUserSuppliedAssets(reserveId, alice), 1e18);
  }

  function test_mandatory_blocks_direct_and_other_position_managers() public {
    vm.prank(alice);
    spoke1.setUserPositionManager(otherPositionManager, true);
    _setMandatory(mandatoryPositionManager, false);
    uint256 reserveId = _daiReserveId(spoke1);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke1.supply(reserveId, 1e18, alice);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(otherPositionManager);
    spoke1.supply(reserveId, 1e18, alice);
  }

  function test_mandatory_deactivated_blocks_all() public {
    _setMandatory(mandatoryPositionManager, false);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(mandatoryPositionManager, false);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(mandatoryPositionManager);
    spoke1.setUsingAsCollateral(_daiReserveId(spoke1), true, alice);
  }

  function test_liquidationCall_permissionless_without_mandatory() public {
    // passes the mandatory position manager gate and reverts in the liquidation logic
    vm.expectRevert(ISpoke.ReserveNotSupplied.selector);
    vm.prank(liquidator);
    spoke1.liquidationCall(_daiReserveId(spoke1), _usdxReserveId(spoke1), alice, 1, false);
  }

  function test_liquidationCall_revertsWith_Unauthorized_with_mandatory() public {
    _setMandatory(mandatoryPositionManager, false);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(liquidator);
    spoke1.liquidationCall(_daiReserveId(spoke1), _usdxReserveId(spoke1), alice, 1, false);
  }

  function test_liquidationCall_mandatory_passes_gate() public {
    _setMandatory(mandatoryPositionManager, false);

    vm.expectRevert(ISpoke.ReserveNotSupplied.selector);
    vm.prank(mandatoryPositionManager);
    spoke1.liquidationCall(_daiReserveId(spoke1), _usdxReserveId(spoke1), alice, 1, false);
  }

  function _setMandatory(address positionManager, bool exclusive) internal {
    vm.prank(ADMIN);
    spoke1.updateMandatoryPositionManager(positionManager, exclusive);
  }
}
