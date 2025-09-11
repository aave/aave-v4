// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGateway_InsufficientAllowance_Test is SignatureGatewayBaseTest {
  function setUp() public virtual override {
    super.setUp();

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_supplyWithSig_revertsWith_ERC20InsufficientAllowance() public {
    uint256 deadline = _warpBeforeRandomDeadline();

    EIP712Types.Supply memory p = _supplyData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(gateway),
        0,
        p.amount,
        address(_underlying(spoke1, p.reserveId))
      )
    );
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, alice, deadline, signature);
  }

  function test_repayWithSig_revertsWith_ERC20InsufficientAllowance() public {
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 1000e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);

    uint256 deadline = _warpBeforeRandomDeadline();

    EIP712Types.Repay memory p = _repayData(spoke1, alice, deadline);
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 50e18;
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientAllowance.selector,
        address(gateway),
        0,
        p.amount
      ),
      address(_underlying(spoke1, p.reserveId))
    );
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, alice, deadline, signature);
  }
}
