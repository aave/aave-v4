// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EtherFiSpokeInstance} from 'src/etherfi/EtherFiSpokeInstance.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {MockOracle} from 'tests/helpers/mocks/MockOracle.sol';
import {ProxyHelper} from 'tests/utils/ProxyHelper.sol';

import 'tests/etherfi/EtherFiSpokeTestBase.t.sol';

/// @dev Unit and fuzz coverage of the EtherFiSpokeInstance borrow gate against the full test
/// environment (no fork): spokes deployed from the ether.fi bytecode with a mock data provider
/// etched at the hardcoded provider address. The provider is put in deny-all mode in setUp, so
/// every test states explicitly who is a recognized Cash Safe. Complementary coverage:
/// - EtherFiSpokeSuiteRerun.t.sol re-runs the stock Spoke suites with the gate transparent,
///   proving all non-borrow behavior (and borrow mechanics themselves) are untouched.
/// - EtherFiSpokeGateForkTest (below) checks the gate against the LIVE data provider on OP.
contract EtherFiSpokeGateTest is EtherFiSpokeTestBase {
  function setUp() public override {
    super.setUp();
    etherFiDataProvider.setAllSafe(false);
  }

  /// @dev The gate runs before any Spoke validation: any non-safe onBehalfOf reverts with
  /// OnlyEtherFiSafe for ANY reserveId/amount, even nonsensical ones.
  function test_borrow_fuzz_revertsWith_OnlyEtherFiSafe_whenNotASafe(
    address onBehalfOf,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.expectRevert(
      abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, onBehalfOf)
    );
    spoke1.borrow(reserveId, amount, onBehalfOf);
  }

  /// @dev The gate keys on onBehalfOf, not the caller: a recognized safe passes the gate and
  /// execution reaches the parent's onlyPositionManager check (Unauthorized, NOT OnlyEtherFiSafe).
  function test_borrow_fuzz_gatePassthrough_reachesParentAuth(
    address caller,
    address onBehalfOf
  ) public {
    vm.assume(caller != onBehalfOf && caller != address(vm));
    // the proxy admin never reaches the spoke: the transparent proxy intercepts it with
    // ProxyDeniedAdminAccess before the gate or the parent auth can run
    vm.assume(caller != ProxyHelper.getProxyAdmin(address(spoke1)));
    etherFiDataProvider.setSafe(onBehalfOf, true);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(caller);
    spoke1.borrow(_daiReserveId(spoke1), 1e18, onBehalfOf);
  }

  /// @dev Collateral does not help: only safe status opens the gate.
  function test_borrow_revertsWith_OnlyEtherFiSafe_evenWithCollateral() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 1_000e18,
      onBehalfOf: bob
    });

    vm.expectRevert(abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, bob));
    vm.prank(bob);
    spoke1.borrow(reserveId, 100e18, bob);
  }

  /// @dev An approved position manager cannot bypass the gate for a non-safe position owner.
  function test_borrow_viaPositionManager_stillGatedOnOnBehalfOf() public {
    uint256 reserveId = _daiReserveId(spoke1);
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: 1_000e18,
      onBehalfOf: bob
    });

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager({positionManager: POSITION_MANAGER, active: true});
    vm.prank(bob);
    spoke1.setUserPositionManager(POSITION_MANAGER, true);

    // gated while bob is not a safe
    vm.expectRevert(abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, bob));
    vm.prank(POSITION_MANAGER);
    spoke1.borrow(reserveId, 100e18, bob);

    // open once bob is recognized: the same call goes through
    etherFiDataProvider.setSafe(bob, true);
    vm.prank(POSITION_MANAGER);
    spoke1.borrow(reserveId, 100e18, bob);
  }

  /// @dev Happy path: a recognized safe borrows end-to-end and receives the underlying.
  function test_borrow_succeeds_forSafe() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;
    etherFiDataProvider.setSafe(bob, true);

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amount * 10,
      onBehalfOf: bob
    });

    uint256 balanceBefore = tokenList.dai.balanceOf(bob);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
    assertEq(tokenList.dai.balanceOf(bob), balanceBefore + amount);
  }

  /// @dev Only borrow is gated: supply, withdraw, and repay stay permissionless. Repay/withdraw
  /// keep working even for an account that LOSES safe status while carrying debt.
  function test_supplyWithdrawRepay_ungated_forNonSafe() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 100e18;

    // non-safe bob supplies and withdraws freely
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: reserveId,
      caller: bob,
      amount: amount * 10,
      onBehalfOf: bob
    });

    // borrow while recognized, then revoke safe status
    etherFiDataProvider.setSafe(bob, true);
    vm.prank(bob);
    spoke1.borrow(reserveId, amount, bob);
    etherFiDataProvider.setSafe(bob, false);

    // repay is not gated
    vm.startPrank(bob);
    tokenList.dai.approve(address(spoke1), amount);
    spoke1.repay(reserveId, amount, bob);

    // withdraw is not gated
    spoke1.withdraw(reserveId, amount, bob);
    vm.stopPrank();
  }

  /// @dev The instances deployed by the fixtures are genuinely gated EtherFiSpokeInstance, and
  /// the provider address mirrored in EtherFiSpokeTestHelpers matches the one hardcoded in the
  /// instance (the helpers deliberately avoid importing it; see EtherFiSpokeTestBase.t.sol).
  function test_fixtures_deployEtherFiSpokeInstance() public {
    assertEq(
      EtherFiSpokeInstance(address(spoke1)).ETHERFI_DATA_PROVIDER(),
      address(etherFiDataProvider)
    );
    for (uint256 i; i < _spokes.length; ++i) {
      vm.expectRevert(
        abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, address(0xBEEF))
      );
      vm.prank(address(0xBEEF));
      _spokes[i].borrow(0, 1, address(0xBEEF));
    }
  }
}

/// @dev Verifies the borrow gate against the LIVE EtherFiDataProvider on an OP Mainnet fork: a
/// non-safe onBehalfOf is rejected with OnlyEtherFiSafe BEFORE any Spoke logic runs; a recognized
/// safe passes the gate and proceeds into the parent borrow (which then reverts Unauthorized for
/// lack of a position manager — proving the gate is pass-through, not a wall). Skips itself unless
/// running against chainid 10:
///   forge test --match-contract EtherFiSpokeGateForkTest --fork-url <op-rpc> -vv
contract EtherFiSpokeGateForkTest is Test {
  function test_fork_borrowGate() public {
    if (block.chainid != 10) {
      vm.skip(true);
    }

    EtherFiSpokeInstance spoke = new EtherFiSpokeInstance(address(new MockOracle()), 64);
    address notASafe = address(0xBEEF);
    address fakeSafe = address(0xCAFE);

    // live data provider says no -> gated
    vm.expectRevert(
      abi.encodeWithSelector(EtherFiSpokeInstance.OnlyEtherFiSafe.selector, notASafe)
    );
    spoke.borrow(0, 1, notASafe);

    // data provider says yes -> gate passes, parent borrow takes over
    vm.mockCall(
      spoke.ETHERFI_DATA_PROVIDER(),
      abi.encodeWithSignature('isEtherFiSafe(address)', fakeSafe),
      abi.encode(true)
    );
    // parent's Unauthorized (onlyPositionManager), NOT OnlyEtherFiSafe
    vm.expectRevert(ISpoke.Unauthorized.selector);
    spoke.borrow(0, 1, fakeSafe);

    assertEq(spoke.ETHERFI_DATA_PROVIDER(), 0xDC515Cb479a64552c5A11a57109C314E40A1A778);
  }
}
