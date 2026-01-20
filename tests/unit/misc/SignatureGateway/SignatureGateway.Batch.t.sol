// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';

contract SignatureGatewayBatchTest is SignatureGatewayBaseTest {
  using SafeCast for *;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }

  function test_executeBatchWithSig_singleSupply() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyParams(spoke1, reserveId, amount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);

    vm.expectCall(address(spoke1), abi.encodeCall(ISpokeBase.supply, (reserveId, amount, alice)));
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyAndWithdraw() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 supplyAmount = 2e18;
    uint256 withdrawAmount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    Utils.supply(spoke1, reserveId, alice, supplyAmount + 1e18, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_supplyParams(spoke1, reserveId, supplyAmount));
    actionData[1] = abi.encode(_withdrawParams(spoke1, reserveId, withdrawAmount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), supplyAmount);

    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.supply, (reserveId, supplyAmount, alice))
    );
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.withdraw, (reserveId, withdrawAmount, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyAndSetCollateral() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_supplyParams(spoke1, reserveId, amount));
    actionData[1] = abi.encode(_setUsingAsCollateralParams(spoke1, reserveId, true));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);

    vm.expectCall(address(spoke1), abi.encodeCall(ISpokeBase.supply, (reserveId, amount, alice)));
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId, true, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    assertTrue(_isUsingAsCollateral(spoke1, reserveId, alice));
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyBorrowRepay() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 10e18;
    uint256 borrowAmount = 5e18;
    uint256 repayAmount = 2e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_borrowParams(spoke1, reserveId, borrowAmount));
    actionData[1] = abi.encode(_repayParams(spoke1, reserveId, repayAmount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), repayAmount);

    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.borrow, (reserveId, borrowAmount, alice))
    );
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.repay, (reserveId, repayAmount, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_revertsOnExpiredDeadline() public {
    uint256 deadline = vm.getBlockTimestamp() - 1; // Expired
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyParams(spoke1, reserveId, amount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnInvalidSignature() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyParams(spoke1, reserveId, amount));

    // Sign with wrong key
    (, uint256 wrongPk) = makeAddrAndKey('wrong');
    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(wrongPk, digest);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnLengthMismatch() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, 0);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](1); // Mismatch!
    actionData[0] = abi.encode(_supplyParams(spoke1, 0, 1e18));

    // Don't compute digest - length mismatch should revert before signature verification
    vm.expectRevert(IGatewayBase.LengthMismatch.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, hex'00');
  }

  function test_executeBatchWithSig_revertsOnEmptyBatch() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](0);
    bytes[] memory actionData = new bytes[](0);

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.expectRevert(IGatewayBase.InvalidBatchSize.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnInvalidActionType() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = 255; // Invalid action type

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyParams(spoke1, 0, 1e18));

    vm.expectRevert();
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, hex'00');
  }
}
