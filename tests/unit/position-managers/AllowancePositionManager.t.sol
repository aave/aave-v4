// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AllowancePositionManagerWrapper} from 'tests/mocks/AllowancePositionManagerWrapper.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract AllowancePositionManagerTest is SpokeBase {
  AllowancePositionManagerWrapper public positionManager;
  TestReturnValues public returnValues;
  uint256 public alicePk;

  function setUp() public virtual override {
    super.setUp();

    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new AllowancePositionManagerWrapper(ADMIN);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_eip712Domain() public {
    AllowancePositionManager instance = new AllowancePositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
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
    assertEq(name, 'AllowancePositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    AllowancePositionManager instance = new AllowancePositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('AllowancePositionManager'),
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

  function test_approveWithdraw_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(
      address(spoke1),
      reserveId,
      alice,
      spender,
      amount
    );
    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, spender, amount);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveWithdrawWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      spender,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(
      address(spoke1),
      reserveId,
      alice,
      spender,
      amount
    );
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_fuzz_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline()
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

  function test_approveWithdraw_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke2), 1, bob, 100e18);
  }

  function test_approveWithdrawWithSig_revertsWith_SpokeNotRegistered() public {
    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      bob,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_temporaryApproveWithdraw_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager), 0);
    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(address(spoke1), reserveId, spender, amount);

    assertEq(
      positionManager.temporaryWithdrawAllowance(address(spoke1), reserveId, alice, spender),
      amount
    );
  }

  /// forge-config: default.isolate = true
  function test_temporaryApproveWithdraw_TransientStorage() public {
    // make sure transient storage is used for temporary withdraw allowances
    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, 100e18);
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      0
    );
  }

  function test_temporaryApproveWithdraw_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(address(spoke2), 1, bob, 100e18);
  }

  function test_renounceWithdrawAllowance_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke1);
    initialAllowance = bound(initialAllowance, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(address(spoke1), reserveId, alice, bob, 0);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);

    assertEq(positionManager.withdrawAllowance(address(spoke1), reserveId, alice, bob), 0);
  }

  function test_renounceWithdrawAllowance_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, 100e18);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), reserveId, alice);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_renounceWithdrawAllowance_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke2), 1, alice);
  }

  function test_withdrawOnBehalfOf() public {
    test_withdrawOnBehalfOf_fuzz(100e18, 0);
  }

  function test_withdrawOnBehalfOf_TemporaryWithdrawAllowanceTakesPrecedence() public {
    uint256 storedAllowance = 300e18;
    _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      storedAllowance,
      0
    );
    test_withdrawOnBehalfOf_fuzz(100e18, 2);
    // this check is also performed in test_withdrawOnBehalfOf_fuzz, duplicating in case of future changes
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      storedAllowance
    );
  }

  function test_withdrawOnBehalfOf_fuzz(uint256 amount, uint256 approvalType) public {
    amount = bound(amount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, mintAmount_DAI);

    approvalType = _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      approvalType
    );

    uint256 allowanceBefore = positionManager.withdrawAllowance(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );
    uint256 temporaryAllowanceBefore = positionManager.temporaryWithdrawAllowance(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    uint256 userSuppliedAmountBefore = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRemoveByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      amount,
      alice
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewRemoveByAssets(daiAssetId, amount));

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + amount);
    assertEq(
      spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice),
      userSuppliedAmountBefore - amount
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType < 2) ? 0 : allowanceBefore
    );
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      (approvalType == 2) ? 0 : temporaryAllowanceBefore
    );
  }

  // consume partial allowance
  function test_withdrawOnBehalfOf_fuzz_allBalance(
    uint256 supplyAmount,
    uint256 approvalType
  ) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    approvalType = _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 10,
      approvalType
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));
    uint256 allowanceBefore = positionManager.withdrawAllowance(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );
    uint256 temporaryAllowanceBefore = positionManager.temporaryWithdrawAllowance(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      supplyAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 2,
      alice
    );

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + supplyAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - supplyAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType < 2) ? allowanceBefore - (supplyAmount * 2) : allowanceBefore
    );
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      (approvalType == 2) ? temporaryAllowanceBefore - (supplyAmount * 2) : temporaryAllowanceBefore
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalance_noAllowanceDecrease(
    uint256 supplyAmount,
    uint256 approvalType
  ) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    approvalType = _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      type(uint256).max,
      approvalType
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      supplyAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      type(uint256).max,
      alice
    );

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + supplyAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - supplyAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType < 2) ? type(uint256).max : 0
    );
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      (approvalType == 2) ? type(uint256).max : 0
    );
  }

  // consume all allowance
  function test_withdrawOnBehalfOf_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 approvalType
  ) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_DAI / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    Utils.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    Utils.borrow({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(322 days);
    vm.assume(hub1.getAddedAssets(daiAssetId) > supplyAmount);
    uint256 repayAmount = spoke1.getReserveTotalDebt(_daiReserveId(spoke1));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice);

    _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 10,
      approvalType
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    assertEq(spoke1.getUserSuppliedShares(_daiReserveId(spoke1), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      expectedSupplyShares,
      expectedWithdrawAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      supplyAmount * 10,
      alice
    );

    assertEq(returnValues.amount, expectedWithdrawAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(bob), callerBalanceBefore + expectedWithdrawAmount);
    assertEq(spoke1.getUserSuppliedAssets(_daiReserveId(spoke1), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - expectedWithdrawAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      0
    );
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      0
    );
  }

  // temporary withdraw allowance takes precedence over stored withdraw allowance, and does not cumulate
  function test_withdrawOnBehalfOf_revertsWith_InsufficientTemporaryWithdrawAllowance() public {
    uint256 storedAllowance = 300e18;
    _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      storedAllowance,
      0
    );

    uint256 amount = 20e18;
    uint256 temporaryAllowance = amount - 1;
    _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      temporaryAllowance,
      2
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientTemporaryWithdrawAllowance.selector,
        temporaryAllowance,
        amount
      )
    );
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);

    assertEq(
      positionManager.withdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice, bob),
      storedAllowance
    );
  }

  function test_withdrawOnBehalfOf_fuzz_revertsWith_InsufficientAllowance(
    uint256 approvalAmount,
    uint256 approvalType
  ) public {
    uint256 amount = 100e18;
    approvalAmount = bound(approvalAmount, 1, amount - 1);

    Utils.supply({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });

    approvalType = _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      approvalAmount,
      approvalType
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        (approvalType == 2)
          ? IAllowancePositionManager.InsufficientTemporaryWithdrawAllowance.selector
          : IAllowancePositionManager.InsufficientWithdrawAllowance.selector,
        approvalAmount,
        amount
      )
    );
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), reserveId, bob, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke2), 1, 100e18, alice);
  }

  function test_creditDelegation_typeHash() public view {
    assertEq(positionManager.CREDIT_DELEGATION_TYPEHASH(), vm.eip712HashType('CreditDelegation'));
    assertEq(
      positionManager.CREDIT_DELEGATION_TYPEHASH(),
      keccak256(
        'CreditDelegation(address spoke,uint256 reserveId,address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_creditDelegation_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(
      address(spoke1),
      reserveId,
      alice,
      spender,
      amount
    );
    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), reserveId, spender, amount);

    assertEq(positionManager.creditDelegation(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_creditDelegationWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      spender,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(
      address(spoke1),
      reserveId,
      alice,
      spender,
      amount
    );
    vm.prank(vm.randomAddress());
    positionManager.delegateCreditWithSig(p, signature);

    assertEq(positionManager.creditDelegation(address(spoke1), reserveId, alice, spender), amount);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.delegateCreditWithSig(p, signature);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.delegateCreditWithSig(p, signature);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline()
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.delegateCreditWithSig(p, signature);
  }

  function test_creditDelegation_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.delegateCredit(address(spoke2), 1, bob, 100e18);
  }

  function test_creditDelegationWithSig_revertsWith_SpokeNotRegistered() public {
    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      bob,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.spoke = address(spoke2);
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.delegateCreditWithSig(p, signature);
  }

  function test_temporaryDelegateCredit_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager), 0);
    vm.prank(alice);
    positionManager.temporaryDelegateCredit(address(spoke1), reserveId, spender, amount);

    assertEq(
      positionManager.temporaryCreditDelegation(address(spoke1), reserveId, alice, spender),
      amount
    );
  }

  /// forge-config: default.isolate = true
  function test_temporaryDelegateCredit_TransientStorage() public {
    // make sure transient storage is used for temporary credit delegations
    vm.prank(alice);
    positionManager.temporaryDelegateCredit(address(spoke1), _daiReserveId(spoke1), bob, 100e18);
    assertEq(
      positionManager.temporaryCreditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      0
    );
  }

  function test_temporaryDelegateCredit_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.temporaryDelegateCredit(address(spoke2), 1, bob, 100e18);
  }

  function test_renounceCreditDelegation_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke1);
    initialAllowance = bound(initialAllowance, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), reserveId, bob, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(address(spoke1), reserveId, alice, bob, 0);
    vm.prank(bob);
    positionManager.renounceCreditDelegation(address(spoke1), reserveId, alice);

    assertEq(positionManager.creditDelegation(address(spoke1), reserveId, alice, bob), 0);
  }

  function test_renounceCreditDelegation_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke1);

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), reserveId, bob, 100e18);
    vm.prank(bob);
    positionManager.renounceCreditDelegation(address(spoke1), reserveId, alice);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceCreditDelegation(address(spoke1), reserveId, alice);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_renounceCreditDelegation_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCreditDelegation(address(spoke2), 1, alice);
  }

  function test_borrowOnBehalfOf() public {
    test_borrowOnBehalfOf_fuzz(5e18, 5e18, 0);
  }

  function test_borrowOnBehalfOf_temporaryCreditDelegationTakesPrecedence() public {
    uint256 storedAllowance = 300e18;
    _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      storedAllowance,
      0
    );
    test_borrowOnBehalfOf_fuzz(5e18, 5e18, 2);
    // this check is also performed in test_borrowOnBehalfOf_fuzz, duplicating in case of future changes
    assertEq(
      positionManager.creditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      storedAllowance
    );
  }

  function test_borrowOnBehalfOf_fuzz(
    uint256 borrowAmount,
    uint256 creditDelegationAmount,
    uint256 approvalType
  ) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);
    creditDelegationAmount = bound(creditDelegationAmount, borrowAmount, borrowAmount * 10);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    approvalType = _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      creditDelegationAmount,
      approvalType
    );

    uint256 allowanceBefore = positionManager.creditDelegation(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );
    uint256 temporaryAllowanceBefore = positionManager.temporaryCreditDelegation(
      address(spoke1),
      _daiReserveId(spoke1),
      alice,
      bob
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    uint256 drawnShares = hub1.previewDrawByAssets(daiAssetId, borrowAmount);
    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      drawnShares,
      borrowAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.borrowOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      borrowAmount,
      alice
    );

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, drawnShares);

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(alice)), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(address(bob)), callerBalanceBefore + borrowAmount);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.creditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType < 2) ? allowanceBefore - borrowAmount : allowanceBefore
    );
    assertEq(
      positionManager.temporaryCreditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType == 2) ? temporaryAllowanceBefore - borrowAmount : temporaryAllowanceBefore
    );
  }

  function test_borrowOnBehalfOf_fuzz_noAllowanceDecrease(
    uint256 borrowAmount,
    uint256 approvalType
  ) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    approvalType = _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      type(uint256).max,
      approvalType
    );

    uint256 userBalanceBefore = tokenList.dai.balanceOf(alice);
    uint256 callerBalanceBefore = tokenList.dai.balanceOf(bob);
    uint256 hubBalanceBefore = tokenList.dai.balanceOf(address(hub1));

    vm.expectEmit(address(spoke1));
    emit ISpokeBase.Borrow(
      _daiReserveId(spoke1),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, borrowAmount),
      borrowAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.borrowOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      borrowAmount,
      alice
    );

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, hub1.previewDrawByAssets(daiAssetId, borrowAmount));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), hubBalanceBefore - borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(alice)), userBalanceBefore);
    assertEq(tokenList.dai.balanceOf(address(bob)), callerBalanceBefore + borrowAmount);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.creditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType < 2) ? type(uint256).max : 0
    );
    assertEq(
      positionManager.temporaryCreditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      (approvalType == 2) ? type(uint256).max : 0
    );
  }

  // temporary credit delegation takes precedence over stored credit delegation, and does not cumulate
  function test_borrowOnBehalfOf_revertsWith_InsufficientTemporaryCreditDelegation() public {
    uint256 storedAllowance = 300e18;
    _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      storedAllowance,
      0
    );

    uint256 amount = 100e18;
    uint256 temporaryAllowance = amount - 1;
    _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      temporaryAllowance,
      2
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientTemporaryCreditDelegation.selector,
        temporaryAllowance,
        amount
      )
    );
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);

    assertEq(
      positionManager.creditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      storedAllowance
    );
  }

  function test_borrowOnBehalfOf_fuzz_revertsWith_InsufficientAllowance(
    uint256 creditDelegationAmount,
    uint256 approvalType
  ) public {
    uint256 borrowAmount = 100e18;
    creditDelegationAmount = bound(creditDelegationAmount, 1, borrowAmount - 1);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, borrowAmount, bob);

    approvalType = _fuzzyDelegateCredit(
      alice,
      alicePk,
      bob,
      address(spoke1),
      _daiReserveId(spoke1),
      creditDelegationAmount,
      approvalType
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        (approvalType == 2)
          ? IAllowancePositionManager.InsufficientTemporaryCreditDelegation.selector
          : IAllowancePositionManager.InsufficientCreditDelegation.selector,
        creditDelegationAmount,
        borrowAmount
      )
    );
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), borrowAmount, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke1);

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), reserveId, bob, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), reserveId, 100e18, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke2), 1, 100e18, alice);
  }

  function test_temporaryAllowancesInParallel() public {
    _fuzzyApproveWithdraw(alice, alicePk, bob, address(spoke1), _daiReserveId(spoke1), 1e18, 2);
    _fuzzyDelegateCredit(alice, alicePk, bob, address(spoke1), _daiReserveId(spoke1), 2e18, 2);
    assertEq(
      positionManager.temporaryWithdrawAllowance(
        address(spoke1),
        _daiReserveId(spoke1),
        alice,
        bob
      ),
      1e18
    );
    assertEq(
      positionManager.temporaryCreditDelegation(address(spoke1), _daiReserveId(spoke1), alice, bob),
      2e18
    );
  }

  function _fuzzyApproveWithdraw(
    address onBehalfOf,
    uint256 onBehalfOfPk,
    address spender,
    address spoke,
    uint256 reserveId,
    uint256 amount,
    uint256 approvalType
  ) internal returns (uint256) {
    approvalType = bound(approvalType, 0, 2);
    if (approvalType == 0) {
      vm.prank(onBehalfOf);
      positionManager.approveWithdraw(spoke, reserveId, spender, amount);
    } else if (approvalType == 1) {
      EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
        spender,
        onBehalfOf,
        type(uint256).max
      );
      p.spoke = spoke;
      p.reserveId = reserveId;
      p.amount = amount;
      p.nonce = _burnRandomNoncesAtKey(positionManager, onBehalfOf);
      bytes memory signature = _sign(onBehalfOfPk, _getTypedDataHash(positionManager, p));

      vm.prank(vm.randomAddress());
      positionManager.approveWithdrawWithSig(p, signature);
    } else {
      vm.prank(onBehalfOf);
      positionManager.temporaryApproveWithdraw(spoke, reserveId, spender, amount);
    }
    return approvalType;
  }

  function _fuzzyDelegateCredit(
    address onBehalfOf,
    uint256 onBehalfOfPk,
    address spender,
    address spoke,
    uint256 reserveId,
    uint256 amount,
    uint256 approvalType
  ) internal returns (uint256) {
    approvalType = bound(approvalType, 0, 2);
    if (approvalType == 0) {
      vm.prank(onBehalfOf);
      positionManager.delegateCredit(spoke, reserveId, spender, amount);
    } else if (approvalType == 1) {
      EIP712Types.CreditDelegation memory p = _creditDelegationData(
        spender,
        onBehalfOf,
        type(uint256).max
      );
      p.spoke = spoke;
      p.reserveId = reserveId;
      p.amount = amount;
      p.nonce = _burnRandomNoncesAtKey(positionManager, onBehalfOf);
      bytes memory signature = _sign(onBehalfOfPk, _getTypedDataHash(positionManager, p));

      vm.prank(vm.randomAddress());
      positionManager.delegateCreditWithSig(p, signature);
    } else {
      vm.prank(onBehalfOf);
      positionManager.temporaryDelegateCredit(spoke, reserveId, spender, amount);
    }
    return approvalType;
  }

  function _withdrawPermitData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (EIP712Types.WithdrawPermit memory) {
    return
      EIP712Types.WithdrawPermit({
        spoke: address(spoke1),
        reserveId: _randomReserveId(spoke1),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _creditDelegationData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (EIP712Types.CreditDelegation memory) {
    return
      EIP712Types.CreditDelegation({
        spoke: address(spoke1),
        reserveId: _randomReserveId(spoke1),
        owner: onBehalfOf,
        spender: spender,
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    IAllowancePositionManager _positionManager,
    EIP712Types.WithdrawPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_positionManager, vm.eip712HashStruct('WithdrawPermit', abi.encode(_params)));
  }

  function _getTypedDataHash(
    IAllowancePositionManager _positionManager,
    EIP712Types.CreditDelegation memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('CreditDelegation', abi.encode(_params))
      );
  }

  function _typedDataHash(
    IAllowancePositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}
