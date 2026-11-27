// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {PermissionedPositionManager} from 'src/position-manager/PermissionedPositionManager.sol';
import {IPermissionedPositionManager} from 'src/position-manager/interfaces/IPermissionedPositionManager.sol';

contract PermissionedPositionManagerBaseTest is Base {
  PermissionedPositionManager public positionManager;
  address public liquidator = makeAddr('liquidator');
  uint256 internal daiReserveId;
  uint256 internal usdxReserveId;

  function setUp() public virtual override {
    super.setUp();
    daiReserveId = _daiReserveId(spoke1);
    usdxReserveId = _usdxReserveId(spoke1);

    // liquidity is provided before the mandatory position manager blocks direct calls
    _openSupplyPosition(spoke1, daiReserveId, 1_000_000e18);
    _openSupplyPosition(spoke1, usdxReserveId, 1_000_000e6);

    positionManager = PermissionedPositionManager(
      AaveV4TestOrchestration.proxify(
        address(_deployImplementation()),
        ADMIN,
        abi.encodeCall(PermissionedPositionManager.initialize, (ADMIN))
      )
    );

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    spoke1.updateMandatoryPositionManager(address(positionManager));

    vm.startPrank(alice);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);
    tokenList.usdx.approve(address(positionManager), UINT256_MAX);
    vm.stopPrank();
  }

  function _deployImplementation() internal virtual returns (PermissionedPositionManager) {
    return new PermissionedPositionManager(address(spoke1));
  }

  function _setPermissioned(IPermissionedPositionManager.Action action) internal {
    vm.prank(ADMIN);
    positionManager.setPermissionedAction(action, true);
  }

  function _approveCaller(address caller) internal {
    vm.prank(ADMIN);
    positionManager.setApprovedCaller(caller, true);
  }

  /// @dev Supplies collateral and borrows through the position manager.
  function _openBorrowPosition(address user, uint256 collateral, uint256 debt) internal {
    vm.startPrank(user);
    positionManager.supply(daiReserveId, collateral, user);
    positionManager.setUsingAsCollateral(daiReserveId, true, user);
    positionManager.borrow(usdxReserveId, debt, user);
    vm.stopPrank();
  }

  /// @dev Bounds `seed` to an action performed on behalf of a user, i.e. any action but liquidation.
  function _boundUserAction(
    uint256 seed
  ) internal pure returns (IPermissionedPositionManager.Action) {
    uint256 index = seed % 7;
    if (index >= uint8(IPermissionedPositionManager.Action.LiquidationCall)) ++index;
    return IPermissionedPositionManager.Action(index);
  }

  /// @dev Calls `action` on the position manager as `caller`, with parameters only valid for revert checks.
  function _callAction(
    IPermissionedPositionManager.Action action,
    address caller,
    address onBehalfOf
  ) internal {
    vm.prank(caller);
    if (action == IPermissionedPositionManager.Action.Supply) {
      positionManager.supply(daiReserveId, 1e18, onBehalfOf);
    } else if (action == IPermissionedPositionManager.Action.Withdraw) {
      positionManager.withdraw(daiReserveId, 1e18, onBehalfOf);
    } else if (action == IPermissionedPositionManager.Action.Borrow) {
      positionManager.borrow(usdxReserveId, 1e6, onBehalfOf);
    } else if (action == IPermissionedPositionManager.Action.Repay) {
      positionManager.repay(usdxReserveId, 1e6, onBehalfOf);
    } else if (action == IPermissionedPositionManager.Action.SetUsingAsCollateral) {
      positionManager.setUsingAsCollateral(daiReserveId, true, onBehalfOf);
    } else if (action == IPermissionedPositionManager.Action.LiquidationCall) {
      positionManager.liquidationCall(daiReserveId, usdxReserveId, onBehalfOf, 1e6);
    } else if (action == IPermissionedPositionManager.Action.UpdateUserRiskPremium) {
      positionManager.updateUserRiskPremium(onBehalfOf);
    } else {
      positionManager.updateUserDynamicConfig(onBehalfOf);
    }
  }
}
