// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

contract SignatureGatewayInvalidSignatureTest is SignatureGatewayBaseTest {
  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ISignatureGateway.Withdraw memory p = _withdrawData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ISignatureGateway.Borrow memory p = _borrowData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ISignatureGateway.Repay memory p = _repayData(spoke1, alice, _warpAfterRandomDeadline());
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    ISignatureGateway.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    uint256 deadline = _warpAfterRandomDeadline();
    ISignatureGateway.UpdateUserRiskPremium memory p = _updateRiskPremiumData(
      spoke1,
      alice,
      deadline
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    ISignatureGateway.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ISignatureGateway.Supply memory p = _supplyData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ISignatureGateway.Withdraw memory p = _withdrawData(
      spoke1,
      onBehalfOf,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ISignatureGateway.Borrow memory p = _borrowData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ISignatureGateway.Repay memory p = _repayData(spoke1, onBehalfOf, _warpAfterRandomDeadline());
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    ISignatureGateway.SetUsingAsCollateral memory p = _setAsCollateralData(
      spoke1,
      onBehalfOf,
      deadline
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidSignatureDueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    ISignatureGateway.UpdateUserRiskPremium memory p = _updateRiskPremiumData(
      spoke1,
      user,
      deadline
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidSignatureDueTo_InvalidSigner()
    public
  {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address user = vm.randomAddress();
    while (user == randomUser) user = vm.randomAddress();

    uint256 deadline = _warpAfterRandomDeadline();
    ISignatureGateway.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      user,
      deadline
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(gateway, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);
  }

  function test_supplyWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ISignatureGateway.Supply memory p = _supplyData(spoke1, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.onBehalfOf, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.onBehalfOf, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.supplyWithSig(p, signature);
  }

  function test_withdrawWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ISignatureGateway.Withdraw memory p = _withdrawData(spoke1, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.onBehalfOf, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.onBehalfOf, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.withdrawWithSig(p, signature);
  }

  function test_borrowWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ISignatureGateway.Borrow memory p = _borrowData(spoke1, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.onBehalfOf, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.onBehalfOf, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.borrowWithSig(p, signature);
  }

  function test_repayWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ISignatureGateway.Repay memory p = _repayData(spoke1, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.onBehalfOf, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.onBehalfOf, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.repayWithSig(p, signature);
  }

  function test_setUsingAsCollateralWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    ISignatureGateway.SetUsingAsCollateral memory p = _setAsCollateralData(spoke1, alice, deadline);
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.onBehalfOf, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.onBehalfOf, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.onBehalfOf, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.setUsingAsCollateralWithSig(p, signature);
  }

  function test_updateUserRiskPremiumWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    uint256 deadline = _warpBeforeRandomDeadline();
    ISignatureGateway.UpdateUserRiskPremium memory p = _updateRiskPremiumData(
      spoke1,
      alice,
      deadline
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.user, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.user, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.user, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserRiskPremiumWithSig(p, signature);
  }

  function test_updateUserDynamicConfigWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ISignatureGateway.UpdateUserDynamicConfig memory p = _updateDynamicConfigData(
      spoke1,
      alice,
      _warpBeforeRandomDeadline()
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(gateway, p.user, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(gateway, p.user, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.user, currentNonce)
    );
    vm.prank(vm.randomAddress());
    gateway.updateUserDynamicConfigWithSig(p, signature);
  }
}
