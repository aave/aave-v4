// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/position-manager/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewaySetSelfAsUserPositionManagerTest is SignatureGatewayBaseTest {
  function test_setSelfAsUserPositionManagerWithSig_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
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
    IPositionManagerGate.PositionManagerUpdate[]
      memory updates = new IPositionManagerGate.PositionManagerUpdate[](1);
    updates[0] = IPositionManagerGate.PositionManagerUpdate(address(gateway), vm.randomBool());
    IPositionManagerGate.SetUserPositionManagers memory p = IPositionManagerGate
      .SetUserPositionManagers({
        spoke: address(spoke1),
        onBehalfOf: vm.randomAddress(),
        updates: updates,
        nonce: vm.randomUint(),
        deadline: vm.randomUint()
      });
    bytes memory signature = vm.randomBytes(72);

    vm.expectCall(
      spoke1.GATE(),
      abi.encodeCall(IPositionManagerGate.setUserPositionManagersWithSig, (p, signature)),
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
      IPositionManagerGate.setUserPositionManagersWithSig.selector,
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

    assertFalse(_isPositionManager(spoke1, alice, address(gateway)));
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    uint192 nonceKey = _randomNonceKey();
    vm.prank(alice);
    IPositionManagerGate(spoke1.GATE()).useNonce(nonceKey);
    IPositionManagerGate.PositionManagerUpdate[]
      memory updates = new IPositionManagerGate.PositionManagerUpdate[](1);
    updates[0] = IPositionManagerGate.PositionManagerUpdate(address(gateway), true);
    IPositionManagerGate.SetUserPositionManagers memory p = IPositionManagerGate
      .SetUserPositionManagers({
        spoke: address(spoke1),
        onBehalfOf: alice,
        updates: updates,
        nonce: IPositionManagerGate(spoke1.GATE()).nonces(alice, nonceKey), // note: this typed sig is forwarded to spoke
        deadline: _warpBeforeRandomDeadline(MAX_SKIP_TIME)
      });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(SPOKE_ADMIN);
    _updatePositionManager(spoke1, address(gateway), true);
    vm.prank(alice);
    _setUserPositionManager(spoke1, address(gateway), false);

    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: p.onBehalfOf,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });

    assertTrue(_isPositionManager(spoke1, alice, address(gateway)));
  }
}
