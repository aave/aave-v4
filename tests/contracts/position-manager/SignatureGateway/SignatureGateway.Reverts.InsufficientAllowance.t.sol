// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/position-manager/SignatureGateway/SignatureGateway.Base.t.sol';

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
    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);

    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    address underlying = ISpoke(p.spoke).getReserve(p.reserveId).underlying;
    assertTrue(IERC20(underlying).allowance(alice, address(gateway)) < p.amount);

    if (underlying == address(tokenList.weth)) {
      // WETH9 reverts with no data on insufficient allowance
      vm.expectRevert();
    } else {
      vm.expectRevert(
        abi.encodeWithSelector(
          IERC20Errors.ERC20InsufficientAllowance.selector,
          address(gateway),
          0,
          p.amount
        )
      );
    }

    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_ERC20InsufficientAllowance() public {
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: 1000e18,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: 100e18,
      onBehalfOf: alice
    });

    uint256 deadline = _warpBeforeRandomDeadline(MAX_SKIP_TIME);

    ISignatureGateway.Repay memory p = _repayData(spoke1, alice, deadline);
    p.reserveId = _daiReserveId(spoke1);
    p.amount = 50e18;
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
    gateway.repayWithSig(p, signature);
  }
}
