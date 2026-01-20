// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Permit2.Base.t.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';
import {IIntentConsumer} from 'src/interfaces/IIntentConsumer.sol';
import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';

contract SignatureGatewayPermit2RevertsTest is SignatureGatewayPermit2BaseTest {
  // Permit2 errors
  error InvalidSigner();
  error SignatureExpired(uint256 signatureDeadline);

  function test_supplyWithPermit2_revertsWith_InvalidSigner() public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpBeforeRandomDeadline());

    (, uint256 bobPk) = makeAddrAndKey('bob');
    bytes memory signature = _getPermit2SupplySignature(permit, p, bobPk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_supplyWithPermit2_revertsWith_SignatureExpired() public {
    // Set up with VALID gateway deadline but EXPIRED Permit2 deadline
    uint256 expiredDeadline = _warpAfterRandomDeadline();
    uint256 validDeadline = block.timestamp + 1 hours;

    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke1, reserveId));
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: expiredDeadline // Permit2 deadline is expired
    });

    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: validDeadline // Gateway deadline is valid
    });

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, permit.deadline));
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_supplyWithPermit2_revertsWith_SpokeNotRegistered() public {
    address unregisteredSpoke = vm.randomAddress();

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: address(0), amount: 1e18}),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: _warpBeforeRandomDeadline()
    });

    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: unregisteredSpoke,
      reserveId: 0,
      amount: 1e18,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: permit.deadline
    });

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    vm.expectRevert(
      abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, unregisteredSpoke)
    );
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_InvalidSigner() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: deadline
    });

    (, uint256 bobPk) = makeAddrAndKey('bob');
    bytes memory signature = _getPermit2RepaySignature(permit, p, bobPk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_SignatureExpired() public {
    // Set up with VALID gateway deadline but EXPIRED Permit2 deadline
    uint256 expiredDeadline = _warpAfterRandomDeadline();
    uint256 validDeadline = block.timestamp + 1 hours;
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: expiredDeadline // Permit2 deadline is expired
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: validDeadline // Gateway deadline is valid
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, permit.deadline));
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_SpokeNotRegistered() public {
    address unregisteredSpoke = vm.randomAddress();

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: address(0), amount: 1e18}),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: _warpBeforeRandomDeadline()
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: unregisteredSpoke,
      reserveId: 0,
      amount: 1e18,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: permit.deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    vm.expectRevert(
      abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, unregisteredSpoke)
    );
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  // ============ Gateway Deadline Validation Tests ============

  function test_supplyWithPermit2_revertsWith_InvalidSignature_dueTo_ExpiredGatewayDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();

    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, deadline);

    // Set permit deadline to far future so Permit2 won't reject it
    permit.deadline = type(uint256).max;

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_InvalidSignature_dueTo_ExpiredGatewayDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: type(uint256).max // Set permit deadline to far future
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: deadline // Gateway deadline is expired
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  // ============ Gateway Nonce Validation Tests ============

  function test_supplyWithPermit2_revertsWith_InvalidAccountNonce(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, alice, nonceKey);

    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke1, reserveId));

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: _getRandomInvalidNonceAtKey(gateway, alice, nonceKey),
      deadline: deadline
    });

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, alice, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_InvalidAccountNonce(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, alice, nonceKey);

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: _getRandomInvalidNonceAtKey(gateway, alice, nonceKey),
      deadline: deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, alice, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  // ============ Frontrun Protection Tests ============
  // These tests verify that signatures are bound to the gateway as spender,
  // preventing attackers from using the signature directly with Permit2

  function test_supplyWithPermit2_cannotBeFrontrun_signatureBoundToGatewaySpender() public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpBeforeRandomDeadline());

    // Alice signs for gateway as spender
    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    // Cache PERMIT2 address before prank (prank only applies to next external call)
    ISignatureTransfer permit2 = ISignatureTransfer(gateway.PERMIT2());

    // Attacker tries to use the signature directly with Permit2 (as a different spender)
    // This should fail because the signature was signed with gateway as spender
    address attacker = vm.randomAddress();
    vm.expectRevert(InvalidSigner.selector);
    vm.prank(attacker);
    permit2.permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails({to: attacker, requestedAmount: p.amount}),
      alice,
      _getSupplyWitnessHash(p),
      'Supply witness)Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)',
      signature
    );
  }

  function test_repayWithPermit2_cannotBeFrontrun_signatureBoundToGatewaySpender() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: deadline
    });

    // Alice signs for gateway as spender
    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    // Cache PERMIT2 address before prank (prank only applies to next external call)
    ISignatureTransfer permit2 = ISignatureTransfer(gateway.PERMIT2());

    // Attacker tries to use the signature directly with Permit2 (as a different spender)
    address attacker = vm.randomAddress();
    vm.expectRevert(InvalidSigner.selector);
    vm.prank(attacker);
    permit2.permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails({to: attacker, requestedAmount: borrowAmount}),
      alice,
      _getRepayWitnessHash(p),
      'Repay witness)Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)',
      signature
    );
  }

  function test_supplyWithPermit2_revertsWith_InvalidSigner_whenSignedForDifferentSpender() public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpBeforeRandomDeadline());

    // Alice signs for a DIFFERENT spender (not the gateway)
    address differentSpender = vm.randomAddress();
    bytes memory signature = _getPermit2WitnessSignatureForSpender(
      permit,
      _getSupplyWitnessHash(p),
      _FULL_SUPPLY_WITNESS_TYPEHASH,
      alicePk,
      differentSpender
    );

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    // Gateway call should fail because signature was signed for different spender
    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_InvalidSigner_whenSignedForDifferentSpender() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: nonce,
      deadline: deadline
    });

    // Alice signs for a DIFFERENT spender (not the gateway)
    address differentSpender = vm.randomAddress();
    bytes memory signature = _getPermit2WitnessSignatureForSpender(
      permit,
      _getRepayWitnessHash(p),
      _FULL_REPAY_WITNESS_TYPEHASH,
      alicePk,
      differentSpender
    );

    _approvePermit2(spoke1, p.reserveId, alice);

    // Gateway call should fail because signature was signed for different spender
    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }
}
