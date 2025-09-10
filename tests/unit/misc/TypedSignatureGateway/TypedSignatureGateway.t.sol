// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/TypedSignatureGateway/TypedSignatureGateway.Base.t.sol';

contract TypedSignatureGatewayTest is TypedSignatureGatewayBaseTest {
  function setUp() public virtual override {
    super.setUp();
    _approveAllUnderlying(spoke1, alice);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_useNonce_monotonic() public {
    vm.setArbitraryStorage(address(gateway));
    address user = vm.randomAddress();

    uint256 currentNonce = gateway.nonces(user);
    vm.assume(currentNonce != UINT256_MAX);
  }

  function test_supplyWithSig() public {
    uint256 deadline = _warpUntilRandomDeadline();

    EIP712Types.Supply memory p = _supplyData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    uint256 shares = _hub(spoke1, p.reserveId).previewAddByAssets(
      _assetId(spoke1, p.reserveId),
      p.amount
    );

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(p.reserveId, address(gateway), alice, shares);

    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, alice, deadline, signature);
  }
}
