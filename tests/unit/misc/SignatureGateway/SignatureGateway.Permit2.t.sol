// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Permit2.Base.t.sol';

contract SignatureGatewayPermit2Test is SignatureGatewayPermit2BaseTest {
  using SafeCast for *;

  function test_supplyWithPermit2(bytes32) public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpBeforeRandomDeadline());

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    uint256 shares = _hub(spoke1, p.reserveId).previewAddByAssets(
      _spokeAssetId(spoke1, p.reserveId),
      p.amount
    );

    TestReturnValues memory returnValues;
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Supply(p.reserveId, address(gateway), alice, shares, p.amount);

    vm.prank(vm.randomAddress());
    (returnValues.shares, returnValues.amount) = gateway.supplyWithPermit2(permit, p, signature);

    assertEq(returnValues.shares, shares);
    assertEq(returnValues.amount, p.amount);

    _assertNonceIncrement(gateway, alice, p.nonce);
    _assertPermit2NonceConsumed(alice, permit.nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoPermit2Allowance(spoke1);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_repayWithPermit2(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;
    uint256 repayAmount = borrowAmount;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 permit2Nonce = _randomUnusedPermit2Nonce(alice);
    uint256 intentNonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: repayAmount
      }),
      nonce: permit2Nonce,
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: repayAmount,
      onBehalfOf: alice,
      nonce: intentNonce,
      deadline: deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    uint256 debtBefore = spoke1.getUserTotalDebt(reserveId, alice);

    vm.prank(vm.randomAddress());
    (uint256 returnShares, uint256 returnAmount) = gateway.repayWithPermit2(permit, p, signature);

    assertGt(returnShares, 0);
    assertEq(returnAmount, repayAmount);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), debtBefore - repayAmount);

    _assertNonceIncrement(gateway, alice, intentNonce);
    _assertPermit2NonceConsumed(alice, permit2Nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoPermit2Allowance(spoke1);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_repayWithPermit2_capAtDebt(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;
    uint256 requestedRepayAmount = borrowAmount * 2;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 actualDebt = spoke1.getUserTotalDebt(reserveId, alice);
    uint256 permit2Nonce = _randomUnusedPermit2Nonce(alice);
    uint256 intentNonce = gateway.nonces(alice, _randomNonceKey());

    deal(address(_underlying(spoke1, reserveId)), alice, requestedRepayAmount);

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: requestedRepayAmount
      }),
      nonce: permit2Nonce,
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: requestedRepayAmount,
      onBehalfOf: alice,
      nonce: intentNonce,
      deadline: deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.prank(vm.randomAddress());
    (, uint256 amount) = gateway.repayWithPermit2(permit, p, signature);

    assertEq(amount, actualDebt);
    assertEq(spoke1.getUserTotalDebt(reserveId, alice), 0);

    _assertNonceIncrement(gateway, alice, intentNonce);
    _assertPermit2NonceConsumed(alice, permit2Nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoPermit2Allowance(spoke1);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }
}
