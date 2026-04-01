// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/helpers/tokenization-spoke/TokenizationSpokeHelpers.sol';
import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract TokenizationSpokeOperations_Gas_Tests is Base, TokenizationSpokeHelpers {
  string internal constant NAMESPACE = 'TokenizationSpoke.Operations';
  ITokenizationSpoke internal daiVault;
  uint192 internal nonceKey = 100;

  string internal constant SHARE_NAME = 'Core Hub DAI';
  string internal constant SHARE_SYMBOL = 'chDAI';

  function setUp() public virtual override {
    super.setUp();
    daiVault = _deployTokenizationSpoke(
      hub1,
      address(tokenList.dai),
      SHARE_NAME,
      SHARE_SYMBOL,
      ADMIN
    );
    _registerTokenizationSpoke(hub1, daiAssetId, daiVault, ADMIN);

    SpokeActions.approve({vault: daiVault, owner: alice, amount: 2100e18});
    vm.startPrank(alice);
    daiVault.deposit(100e18, alice);
    daiVault.useNonce(nonceKey);
    daiVault.usePermitNonce();
    vm.stopPrank();
  }

  function test_deposit() public {
    vm.prank(alice);
    daiVault.deposit(1000e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'deposit');
  }

  function test_mint() public {
    uint256 shares = daiVault.previewMint(1000e18);
    vm.prank(alice);
    daiVault.mint(shares, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'mint');
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    daiVault.deposit(1000e18, alice);
    daiVault.withdraw(500e18, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, partial');

    uint256 balance = daiVault.maxWithdraw(alice);
    daiVault.withdraw(balance, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, full');

    daiVault.deposit(1000e18, alice);
    daiVault.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    daiVault.withdraw(500e18, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, partial');

    balance = daiVault.maxWithdraw(alice);
    daiVault.withdraw(balance, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, full');
    vm.stopPrank();
  }

  function test_redeem() public {
    vm.startPrank(alice);
    daiVault.deposit(1000e18, alice);
    uint256 shares = daiVault.balanceOf(alice);
    daiVault.redeem(shares / 2, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, partial');

    shares = daiVault.maxRedeem(alice);
    daiVault.redeem(shares, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, full');

    daiVault.deposit(1000e18, alice);
    daiVault.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    shares = daiVault.balanceOf(alice);
    daiVault.redeem(shares / 2, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, partial');

    shares = daiVault.maxRedeem(alice);
    daiVault.redeem(shares, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, full');
    vm.stopPrank();
  }

  function test_depositWithSig() public {
    ITokenizationSpoke.TokenizedDeposit memory p = ITokenizationSpoke.TokenizedDeposit({
      depositor: alice,
      assets: 1000e18,
      receiver: alice,
      nonce: daiVault.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiVault, p));
    SpokeActions.approve({vault: daiVault, owner: alice, amount: p.assets});

    daiVault.depositWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'depositWithSig');
  }

  function test_mintWithSig() public {
    ITokenizationSpoke.TokenizedMint memory p = ITokenizationSpoke.TokenizedMint({
      depositor: alice,
      shares: daiVault.previewMint(1000e18),
      receiver: alice,
      nonce: daiVault.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiVault, p));
    SpokeActions.approve({vault: daiVault, owner: alice, amount: p.shares});

    daiVault.mintWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'mintWithSig');
  }

  function test_withdrawWithSig() public {
    ITokenizationSpoke.TokenizedWithdraw memory p = ITokenizationSpoke.TokenizedWithdraw({
      owner: alice,
      assets: 500e18,
      receiver: alice,
      nonce: daiVault.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiVault, p));
    SpokeActions.approve({vault: daiVault, owner: alice, amount: p.assets});
    vm.prank(alice);
    daiVault.deposit(p.assets, alice);

    daiVault.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_redeemWithSig() public {
    ITokenizationSpoke.TokenizedRedeem memory p = ITokenizationSpoke.TokenizedRedeem({
      owner: alice,
      shares: 1000e18,
      receiver: alice,
      nonce: daiVault.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiVault, p));
    SpokeActions.approve({vault: daiVault, owner: alice, amount: p.shares});
    vm.prank(alice);
    daiVault.mint(p.shares, alice);

    daiVault.redeemWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'redeemWithSig');
  }

  function test_permit() public {
    EIP712Types.Permit memory p = EIP712Types.Permit({
      owner: alice,
      spender: bob,
      value: 1000e18,
      nonce: daiVault.nonces(alice),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(daiVault, p));

    vm.expectEmit(address(daiVault));
    emit IERC20.Approval(p.owner, p.spender, p.value);

    daiVault.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
    vm.snapshotGasLastCall(NAMESPACE, 'permit');

    assertEq(daiVault.allowance(p.owner, p.spender), p.value);
  }
}
