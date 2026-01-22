// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewaySetSelfAsUserPositionManagerTest is SignatureGatewayBaseTest {
  function test_setSelfAsUserPositionManagerWithSig_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IGatewayBase.SpokeNotRegistered.selector);
    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke2),
      onBehalfOf: vm.randomAddress(),
      approve: vm.randomBool(),
      nonce: vm.randomUint(),
      deadline: vm.randomUint(),
      signature: vm.randomBytes(72)
    });
  }

  function test_setSelfAsUserPositionManagerWithSig_forwards_correct_call() public {
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), vm.randomBool());
    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: vm.randomAddress(),
      updates: updates,
      nonce: vm.randomUint(),
      deadline: vm.randomUint()
    });
    bytes memory signature = vm.randomBytes(72);

    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpoke.setUserPositionManagersWithSig, (p, signature)),
      1
    );
    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: p.onBehalfOf,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });
  }

  function test_setSelfAsUserPositionManagerWithSig_ignores_underlying_spoke_reverts() public {
    vm.mockCallRevert(
      address(spoke1),
      ISpoke.setUserPositionManagersWithSig.selector,
      vm.randomBytes(64)
    );

    vm.prank(vm.randomAddress());
    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: vm.randomAddress(),
      approve: vm.randomBool(),
      nonce: vm.randomUint(),
      deadline: vm.randomUint(),
      signature: vm.randomBytes(72)
    });

    assertFalse(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    uint192 nonceKey = _randomNonceKey();
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), true);
    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke1.nonces(alice, nonceKey), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), false);

    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: p.onBehalfOf,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });

    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }
}
