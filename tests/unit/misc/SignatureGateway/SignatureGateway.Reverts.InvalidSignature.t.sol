// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayInvalidSignatureTest is SignatureGatewayBaseTest {
  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(
      p.reserveId,
      p.useAsCollateral,
      p.onBehalfOf,
      p.deadline,
      signature
    );
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p.user, p.deadline, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p.user, p.deadline, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.Supply memory p = _supplyData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.Withdraw memory p = _withdrawData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.Borrow memory p = _borrowData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.Repay memory p = _repayData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, onBehalfOf, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(
      p.reserveId,
      p.useAsCollateral,
      p.onBehalfOf,
      p.deadline,
      signature
    );
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidSignatureDueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(spoke1, user, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p.user, p.deadline, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidSignatureDueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(spoke1, user, deadline);
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p.user, p.deadline, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    EIP712Types.Supply memory p = _supplyData(spoke1, alice, _warpAfterRandomDeadline());
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    EIP712Types.Withdraw memory p = _withdrawData(spoke1, alice, _warpAfterRandomDeadline());
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    EIP712Types.Borrow memory p = _borrowData(spoke1, alice, _warpAfterRandomDeadline());
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce() public {
    EIP712Types.Repay memory p = _repayData(spoke1, alice, _warpAfterRandomDeadline());
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p.reserveId, p.amount, p.onBehalfOf, p.deadline, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidSignature_dueTo_InvalidNonce()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(
      p.reserveId,
      p.useAsCollateral,
      p.onBehalfOf,
      p.deadline,
      signature
    );
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidSignatureDueTo_InvalidNonce()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    EIP712Types.UpdateUserRiskPremium memory p = _updateRiskPremiumData(spoke1, alice, deadline);
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p.user, p.deadline, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidSignatureDueTo_InvalidNonce()
    public
  {
    EIP712Types.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpAfterRandomDeadline()
    );
    _burnRandomNonces(alice);
    p.nonce = vm.randomUint(0, gateway.nonces(alice) - 1);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p.user, p.deadline, signature);
  }
}
