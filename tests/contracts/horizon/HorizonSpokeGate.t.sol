// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/permissioned/PermissionedSpoke.Base.t.sol';

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {HorizonSpokeGate} from 'src/horizon/HorizonSpokeGate.sol';
import {IHorizonSpokeGate} from 'src/horizon/interfaces/IHorizonSpokeGate.sol';

contract HorizonSpokeGateTest is PermissionedSpokeBase {
  HorizonSpokeGate internal horizonGate;
  address internal GATE_OWNER = makeAddr('GATE_OWNER');

  function _deployGate() internal override returns (address) {
    horizonGate = new HorizonSpokeGate(GATE_OWNER);
    return address(horizonGate);
  }

  function _authorizeManager(uint256 reserveId, address manager) internal {
    vm.prank(GATE_OWNER);
    horizonGate.updateReserveManager({reserveId: reserveId, manager: manager, active: true});
  }

  function test_constructor() public view {
    assertEq(horizonGate.owner(), GATE_OWNER);
  }

  function test_updateReserveManager() public {
    assertFalse(horizonGate.isReserveManager(usdxReserveId, RWA_MANAGER));

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
    vm.prank(alice);
    horizonGate.updateReserveManager({
      reserveId: usdxReserveId,
      manager: RWA_MANAGER,
      active: true
    });

    vm.expectEmit(address(horizonGate));
    emit IHorizonSpokeGate.UpdateReserveManager(usdxReserveId, RWA_MANAGER, true);
    _authorizeManager(usdxReserveId, RWA_MANAGER);
    assertTrue(horizonGate.isReserveManager(usdxReserveId, RWA_MANAGER));

    vm.prank(GATE_OWNER);
    horizonGate.updateReserveManager({
      reserveId: usdxReserveId,
      manager: RWA_MANAGER,
      active: false
    });
    assertFalse(horizonGate.isReserveManager(usdxReserveId, RWA_MANAGER));
  }

  function test_revokedManagerCannotAct() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.prank(GATE_OWNER);
    horizonGate.updateReserveManager({
      reserveId: usdxReserveId,
      manager: RWA_MANAGER,
      active: false
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_forcedTransfer() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: bob
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 0);
    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, bob), amount);
  }

  function test_forcedTransfer_viaMulticall() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpoke.withdraw, (usdxReserveId, amount, alice));
    calls[1] = abi.encodeCall(ISpoke.supply, (usdxReserveId, amount, bob));
    vm.prank(RWA_MANAGER);
    spoke.multicall(calls);

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 0);
    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, bob), amount);
  }

  function test_forcedRepay() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    uint256 amount = 100e6;
    _supplyCollateralAndBorrow(alice, amount);

    deal(address(tokenList.usdx), RWA_MANAGER, amount);
    SpokeActions.repay({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserTotalDebt(usdxReserveId, alice), 0);
  }

  function test_forcedSetUsingAsCollateral() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    SpokeActions.setUsingAsCollateral({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      usingAsCollateral: true,
      onBehalfOf: alice
    });

    assertTrue(_isUsingAsCollateral(spoke, usdxReserveId, alice));
  }

  function test_managerScopedPerReserve() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethReserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });

    // the manager of usdx cannot act on alice's weth position
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: wethReserveId,
      caller: RWA_MANAGER,
      amount: 1e18,
      onBehalfOf: alice
    });
  }

  function test_managerCannotBorrowOnBehalf() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    _supplyCollateralAndBorrow(alice, 100e6);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_forcedWithdraw_stillValidatesHealthFactor() public {
    _authorizeManager(usdxReserveId, RWA_MANAGER);

    _supplyCollateralAndBorrow(alice, 100e6);

    vm.expectRevert(ISpoke.HealthFactorBelowThreshold.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: 100e6,
      onBehalfOf: alice
    });
  }

  function test_liquidationsPermissionless() public {
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 10_000e6,
      onBehalfOf: bob
    });
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: wethReserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    _borrowToBeLiquidatableWithPriceChange({
      spoke: spoke,
      user: alice,
      reserveId: usdxReserveId,
      collateralReserveId: wethReserveId,
      desiredHf: 1.01e18,
      pricePercentage: 90_00
    });

    uint256 debtBefore = spoke.getUserTotalDebt(usdxReserveId, alice);

    // bob is neither a manager nor a position manager of alice
    SpokeActions.liquidationCall({
      spoke: spoke,
      collateralReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });

    assertLt(spoke.getUserTotalDebt(usdxReserveId, alice), debtBefore, 'liquidation executed');
  }

  function test_defaultPositionManagerAuthorizationPreserved() public {
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(bob, true);
    vm.prank(alice);
    spoke.setUserPositionManager(bob, true);

    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserSuppliedAssets(usdxReserveId, alice), 50e6);
  }
}
