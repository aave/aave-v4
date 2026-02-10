// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokePermitTest is TokenizationSpokeBaseTest {
  using MathUtils for uint256;

  ITokenizationSpoke public vault;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
  }

  function test_nonces_uses_permit_nonce_key_namespace(bytes32) public {
    vm.setArbitraryStorage(address(vault));
    uint192 key = vault.PERMIT_NONCE_NAMESPACE();

    address user = vm.randomAddress();
    assertEq(vault.nonces(user), vault.nonces(user, key));

    uint256 keyNonce = vault.nonces(user);
    (uint192 unpackedKey, ) = _unpackNonce(keyNonce);
    assertEq(unpackedKey, key);
  }

  function test_usePermitNonce(bytes32) public {
    vm.setArbitraryStorage(address(vault));
    uint192 key = vault.PERMIT_NONCE_NAMESPACE();

    address owner = vm.randomAddress();
    uint256 initialNonce = vault.nonces(owner, key);

    vm.prank(owner);
    uint256 usedNonce = vault.usePermitNonce();
    assertEq(usedNonce, initialNonce);

    uint256 newNonce = vault.nonces(owner, key);
    assertEq(newNonce, initialNonce.uncheckedAdd(1));
  }

  function test_permit() public {
    EIP712Types.Permit memory p = _permitData(vault, alice, _warpBeforeRandomDeadline());
    p.nonce = _burnRandomNoncesAtKey(vault, p.owner, vault.PERMIT_NONCE_NAMESPACE());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectEmit(address(vault));
    emit IERC20.Approval(p.owner, p.spender, p.value);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);

    assertEq(vault.allowance(p.owner, p.spender), p.value);
  }

  function test_permit_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.Permit memory p = _permitData(vault, alice, _warpAfterRandomDeadline());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
  }

  function test_permit_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address owner = _randomAddressOmit(randomUser);

    EIP712Types.Permit memory p = _permitData(vault, owner, _warpBeforeRandomDeadline());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(randomUserPk, _getTypedDataHash(vault, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
  }

  function test_permit_revertsWith_InvalidAddress_dueTo_ZeroAddressOwner() public {
    EIP712Types.Permit memory p = _permitData(vault, address(0), _warpBeforeRandomDeadline());
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
  }

  // @dev Any nonce used at arbitrary namespace will revert with InvalidSignature.
  function test_permit_revertsWith_InvalidSignature_dueTo_invalid_nonce_at_arbitrary_namespace(
    bytes32
  ) public {
    EIP712Types.Permit memory p = _permitData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = _randomNonceKey();
    while (nonceKey == vault.PERMIT_NONCE_NAMESPACE()) nonceKey = _randomNonceKey();

    p.nonce = _getRandomNonceAtKey(nonceKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
  }

  function test_permit_revertsWith_InvalidSignature_dueTo_invalid_nonce_at_permit_key_namespace(
    bytes32
  ) public {
    EIP712Types.Permit memory p = _permitData(vault, alice, _warpBeforeRandomDeadline());
    uint192 nonceKey = vault.PERMIT_NONCE_NAMESPACE();

    p.nonce = _getRandomInvalidNonceAtKey(vault, p.owner, nonceKey);

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(vault, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    vault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
  }

  function test_renounceAllowance() public {
    address owner = vm.randomAddress();
    address spender = vm.randomAddress();
    uint256 amount = vm.randomUint();

    vm.prank(owner);
    vault.approve(spender, amount);

    assertEq(vault.allowance(owner, spender), amount);

    vm.expectEmit(address(vault));
    emit IERC20.Approval(owner, spender, 0);
    vm.prank(spender);
    vault.renounceAllowance(owner);

    assertEq(vault.allowance(owner, spender), 0);
  }

  function test_renounceAllowance_noop() public {
    address owner = vm.randomAddress();
    address spender = vm.randomAddress();

    vm.prank(owner);
    vault.approve(spender, 0);

    vm.record();
    vm.recordLogs();
    vm.prank(spender);
    vault.renounceAllowance(owner);

    assertEq(vm.getRecordedLogs().length, 0);
    (, bytes32[] memory writeSlots) = vm.accesses(address(vault));
    assertEq(writeSlots.length, 0);
  }
}
