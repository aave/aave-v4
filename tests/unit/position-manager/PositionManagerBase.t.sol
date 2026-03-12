// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract PositionManagerBaseTest is SpokeBase {
  PositionManagerBaseWrapper public positionManager;
  PositionManagerNoMulticall public positionManager2;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new PositionManagerBaseWrapper(address(ADMIN));
    positionManager2 = new PositionManagerNoMulticall(address(ADMIN));

    vm.startPrank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    spoke1.updatePositionManager(address(positionManager2), true);
    vm.stopPrank();
  }

  function test_constructor() public view {
    assertEq(positionManager.owner(), address(ADMIN));
    assertEq(positionManager.pendingOwner(), address(0));

    assertEq(positionManager.rescueGuardian(), address(ADMIN));
  }

  function test_getReserveUnderlying_fuzz(uint256 reserveId) public view {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    address expectedUnderlying = address(_underlying(spoke1, reserveId));

    assertEq(positionManager.getReserveUnderlying(address(spoke1), reserveId), expectedUnderlying);
  }

  function test_getReserveUnderlying_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    positionManager.getReserveUnderlying(address(spoke1), reserveId);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(positionManager), true);

    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke1.nonces(address(alice), _randomNonceKey()), // note: this typed sig is forwarded to spoke1
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    assertFalse(spoke1.isPositionManager(alice, address(positionManager)));

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUserPositionManager(alice, address(positionManager), p.updates[0].approve);

    vm.prank(vm.randomAddress());
    positionManager.setSelfAsUserPositionManagerWithSig(
      address(spoke1),
      p.onBehalfOf,
      p.updates[0].approve,
      p.nonce,
      p.deadline,
      signature
    );

    _assertNonceIncrement(ISignatureGateway(address(spoke1)), alice, p.nonce); // note: nonce consumed on spoke1
    assertTrue(spoke1.isPositionManager(alice, address(positionManager)));
  }

  function test_permitReserveUnderlying_revertsWith_ReserveNotListed() public {
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
    uint256 unlistedReserveId = vm.randomUint(spoke1.getReserveCount() + 1, UINT256_MAX);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      address(spoke1),
      unlistedReserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserveUnderlying_forwards_correct_call() public {
    uint256 reserveId = _randomReserveId(spoke1);
    address owner = vm.randomAddress();
    address spender = address(positionManager);
    uint256 value = vm.randomUint();
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    vm.expectCall(
      address(_underlying(spoke1, reserveId)),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1
    );
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      address(spoke1),
      reserveId,
      owner,
      value,
      deadline,
      v,
      r,
      s
    );
  }

  function test_permitReserveUnderlying_ignores_permit_reverts() public {
    uint256 reserveId = _randomReserveId(spoke1);
    address token = address(_underlying(spoke1, reserveId));

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    vm.mockCallRevert(token, TestnetERC20.permit.selector, vm.randomBytes(64));

    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      address(spoke1),
      reserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserveUnderlying() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 reserveId = _daiReserveId(spoke1);
    TestnetERC20 token = TestnetERC20(address(_underlying(spoke1, reserveId)));

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    assertEq(token.allowance(user, address(positionManager)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(positionManager),
      value: 100e18,
      deadline: _warpBeforeRandomDeadline(),
      nonce: token.nonces(user)
    });

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(token, params));

    vm.expectEmit(address(token));
    emit IERC20.Approval(user, address(positionManager), params.value);
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      address(spoke1),
      reserveId,
      user,
      params.value,
      params.deadline,
      v,
      r,
      s
    );

    assertEq(token.allowance(user, address(positionManager)), params.value);
  }

  function test_registerSpoke_fuzz(address newSpoke) public {
    vm.assume(newSpoke != address(0));
    assertFalse(positionManager.isSpokeRegistered(newSpoke));

    vm.expectEmit(address(positionManager));
    emit IPositionManagerBase.SpokeRegistered(newSpoke, true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(newSpoke, true);

    assertTrue(positionManager.isSpokeRegistered(newSpoke));
  }

  function test_registerSpoke_unregister() public {
    assertFalse(positionManager.isSpokeRegistered(address(spoke1)));

    vm.expectEmit(address(positionManager));
    emit IPositionManagerBase.SpokeRegistered(address(spoke1), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    assertTrue(positionManager.isSpokeRegistered(address(spoke1)));

    vm.expectEmit(address(positionManager));
    emit IPositionManagerBase.SpokeRegistered(address(spoke1), false);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), false);

    assertFalse(positionManager.isSpokeRegistered(address(spoke1)));
  }

  function test_registerSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == ADMIN) caller = vm.randomAddress();

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_registerSpoke_revertsWith_InvalidAddress() public {
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(0), true);
  }

  function test_multicall_revertsWith_UnsupportedAction() public {
    bytes[] memory calls = new bytes[](1);
    calls[0] = abi.encodeWithSignature('randomFunction()');

    vm.expectRevert(IPositionManagerBase.UnsupportedAction.selector);
    positionManager2.multicall(calls);
  }

  function test_multicall() public {
    address spoke2 = makeAddr('spoke2');

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature('registerSpoke(address,bool)', address(spoke1), true);
    calls[1] = abi.encodeWithSignature('registerSpoke(address,bool)', address(spoke2), true);

    vm.prank(ADMIN);
    bytes[] memory res = positionManager.multicall(calls);

    assertEq(res[0].length, 0);
    assertEq(res[1].length, 0);

    assertTrue(positionManager.isSpokeRegistered(address(spoke1)));
    assertTrue(positionManager.isSpokeRegistered(address(spoke2)));
  }

  function test_multicall_atomicity_on_revert() public {
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature('registerSpoke(address,bool)', address(spoke1), true);
    calls[1] = abi.encodeWithSignature('registerSpoke(address,bool)', address(0), true); // will revert

    vm.prank(ADMIN);
    vm.expectRevert(IPositionManagerBase.InvalidAddress.selector);
    positionManager.multicall(calls);

    assertFalse(positionManager.isSpokeRegistered(address(spoke1)));
  }

  function test_renouncePositionManagerRole() public {
    address user = vm.randomAddress();

    vm.prank(user);
    spoke1.setUserPositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    assertTrue(spoke1.isPositionManager(user, address(positionManager)));

    vm.prank(ADMIN);
    positionManager.renouncePositionManagerRole(address(spoke1), user);

    assertFalse(spoke1.isPositionManager(user, address(positionManager)));
  }

  function test_renouncePositionManagerRole_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = vm.randomAddress();
    while (caller == ADMIN) caller = vm.randomAddress();

    vm.prank(caller);
    spoke1.setUserPositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    positionManager.renouncePositionManagerRole(address(spoke1), caller);
  }
}
