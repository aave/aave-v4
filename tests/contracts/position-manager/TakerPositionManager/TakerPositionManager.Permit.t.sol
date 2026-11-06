// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/position-manager/TakerPositionManager/TakerPositionManager.Base.t.sol';

contract TakerPositionManagerPermitTest is TakerPositionManagerBaseTest {
  function test_eip712Domain() public {
    TakerPositionManager instance = new TakerPositionManager{salt: bytes32(vm.randomUint())}(
      vm.randomAddress()
    );
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(instance)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'TakerPositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    TakerPositionManager instance = new TakerPositionManager{salt: bytes32(vm.randomUint())}(
      vm.randomAddress()
    );
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('TakerPositionManager'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_withdrawPermit_typeHash() public view {
    assertEq(positionManager.WITHDRAW_PERMIT_TYPEHASH(), vm.eip712HashType('WithdrawPermit'));
    assertEq(
      positionManager.WITHDRAW_PERMIT_TYPEHASH(),
      keccak256(
        'WithdrawPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_borrowPermit_typeHash() public view {
    assertEq(positionManager.BORROW_PERMIT_TYPEHASH(), vm.eip712HashType('BorrowPermit'));
    assertEq(
      positionManager.BORROW_PERMIT_TYPEHASH(),
      keccak256(
        'BorrowPermit(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_approveWithdrawWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT_DAI);

    ITakerPositionManager.WithdrawPermit memory p = _withdrawPermitData(
      spender,
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.WithdrawApproval(address(spoke1), alice, spender, reserveId, amount);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ITakerPositionManager.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline(MAX_SKIP_TIME)
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ITakerPositionManager.WithdrawPermit memory p = _withdrawPermitData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline(MAX_SKIP_TIME)
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ITakerPositionManager.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_revertsWith_SpokeNotRegistered() public {
    ITakerPositionManager.WithdrawPermit memory p = _withdrawPermitData(
      bob,
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveBorrowWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT_DAI);

    ITakerPositionManager.BorrowPermit memory p = _approveBorrowData(
      spender,
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit ITakerPositionManager.BorrowApproval(address(spoke1), alice, spender, reserveId, amount);
    vm.prank(vm.randomAddress());
    positionManager.approveBorrowWithSig(p, signature);

    assertEq(positionManager.borrowAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveBorrowWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    ITakerPositionManager.BorrowPermit memory p = _approveBorrowData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline(MAX_SKIP_TIME)
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveBorrowWithSig(p, signature);
  }

  function test_approveBorrowWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    ITakerPositionManager.BorrowPermit memory p = _approveBorrowData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline(MAX_SKIP_TIME)
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveBorrowWithSig(p, signature);
  }

  function test_approveBorrowWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    ITakerPositionManager.BorrowPermit memory p = _approveBorrowData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.approveBorrowWithSig(p, signature);
  }

  function test_approveBorrowWithSig_revertsWith_SpokeNotRegistered() public {
    ITakerPositionManager.BorrowPermit memory p = _approveBorrowData(
      bob,
      alice,
      _warpBeforeRandomDeadline(MAX_SKIP_TIME)
    );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveBorrowWithSig(p, signature);
  }
}
