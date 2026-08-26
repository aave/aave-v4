// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/PermissionedSpokeBase.sol';

contract PermissionedSpokeTest is PermissionedSpokeBase {
  function test_constructor() public {
    assertEq(PermissionedSpokeInstance(address(spoke)).GATE(), address(gate));

    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new PermissionedSpokeInstance({
      oracle_: address(oracle1),
      maxUserReservesLimit_: DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT,
      gate_: address(0)
    });
  }

  function test_defaultBehaviorViaCallback() public {
    _supplyCollateralAndBorrow(alice, 100e6);

    // an unapproved caller still cannot act on behalf of alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 1e6,
      onBehalfOf: alice
    });
  }

  function test_permissionedBorrow() public {
    gate.setGated(ISpoke.borrow.selector, true);

    // supply is not gated for ineligible users
    SpokeActions.supplyCollateral({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 200e6,
      onBehalfOf: alice
    });

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    gate.setEligible(alice, true);
    SpokeActions.borrow({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    assertEq(spoke.getUserTotalDebt(usdxReserveId, alice), 100e6);
  }

  function test_approvedPositionManagersPreservedViaCallback() public {
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: 100e6,
      onBehalfOf: alice
    });

    // bob is not an approved position manager for alice
    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: bob,
      amount: 50e6,
      onBehalfOf: alice
    });

    // approving bob as position manager makes the call pass through the callback
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

  /// @dev Horizon-style forced transfer: the RWA manager moves alice's position to bob by
  /// withdrawing on her behalf and re-supplying to bob, without any user approval.
  function test_forcedTransfer_viaGlobalManager() public {
    gate.setGlobalManager(RWA_MANAGER, true);

    uint256 amount = 100e6;
    SpokeActions.supply({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: alice,
      amount: amount,
      onBehalfOf: alice
    });

    uint256 balanceBefore = tokenList.usdx.balanceOf(RWA_MANAGER);
    SpokeActions.withdraw({
      spoke: spoke,
      reserveId: usdxReserveId,
      caller: RWA_MANAGER,
      amount: amount,
      onBehalfOf: alice
    });
    assertEq(tokenList.usdx.balanceOf(RWA_MANAGER), balanceBefore + amount);

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

  function test_forcedWithdraw_stillValidatesHealthFactor() public {
    gate.setGlobalManager(RWA_MANAGER, true);

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

  function test_liquidationCallGated() public {
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

    gate.setGated(ISpoke.liquidationCall.selector, true);

    vm.expectRevert(ISpoke.Unauthorized.selector);
    SpokeActions.liquidationCall({
      spoke: spoke,
      collateralReserveId: wethReserveId,
      debtReserveId: usdxReserveId,
      user: alice,
      debtToCover: type(uint256).max,
      receiveShares: false,
      caller: bob
    });

    // ungated liquidations preserve the default permissionless behavior via the gate
    gate.setGated(ISpoke.liquidationCall.selector, false);

    uint256 debtBefore = spoke.getUserTotalDebt(usdxReserveId, alice);

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

  function test_cannotBeBypassedWithMulticall() public {
    gate.setGated(ISpoke.borrow.selector, true);

    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeCall(ISpoke.borrow, (usdxReserveId, 100e6, alice));

    vm.expectRevert(ISpoke.Unauthorized.selector);
    vm.prank(alice);
    spoke.multicall(calls);
  }

  function test_updateUserRiskPremium_gated() public {
    _supplyCollateralAndBorrow(alice, 100e6);

    // the gate denies, so the call falls back to the admin check
    gate.setGated(ISpoke.updateUserRiskPremium.selector, true);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke.updateUserRiskPremium(alice);

    // the gate can authorize a caller that is not a position manager of alice
    gate.setGlobalManager(RWA_MANAGER, true);
    vm.prank(RWA_MANAGER);
    spoke.updateUserRiskPremium(alice);
  }

  function test_updateUserDynamicConfig_gated() public {
    _supplyCollateralAndBorrow(alice, 100e6);

    gate.setGated(ISpoke.updateUserDynamicConfig.selector, true);
    vm.expectRevert(
      abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice)
    );
    vm.prank(alice);
    spoke.updateUserDynamicConfig(alice);

    gate.setGlobalManager(RWA_MANAGER, true);
    vm.prank(RWA_MANAGER);
    spoke.updateUserDynamicConfig(alice);
  }

  function test_eip712Domain() public view {
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(spoke)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'PermissionedSpoke');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(spoke));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public view {
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('PermissionedSpoke'),
        keccak256('1'),
        block.chainid,
        address(spoke)
      )
    );
    assertEq(spoke.DOMAIN_SEPARATOR(), expectedDomainSeparator);
    assertNotEq(spoke.DOMAIN_SEPARATOR(), spoke1.DOMAIN_SEPARATOR());
  }

  function test_setUserPositionManagersWithSig() public {
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager({positionManager: POSITION_MANAGER, active: true});

    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(POSITION_MANAGER, true);
    ISpoke.SetUserPositionManagers memory params = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke.nonces(alice, 0),
      deadline: block.timestamp + 1
    });

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(spoke, params));

    spoke.setUserPositionManagersWithSig(params, abi.encodePacked(r, s, v));

    assertTrue(spoke.isPositionManager(alice, POSITION_MANAGER));
  }
}
