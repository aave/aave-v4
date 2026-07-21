// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/helpers/tokenization-spoke/TokenizationSpokeHelpers.sol';
import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract TokenizationSpokeOperations_Gas_Tests is Base, TokenizationSpokeHelpers {
  string internal constant NAMESPACE = 'TokenizationSpoke.Operations';
  ITokenizationSpoke internal daiTokenizationSpoke;
  uint192 internal nonceKey = 100;

  string internal constant SHARE_NAME = 'Core Hub DAI';
  string internal constant SHARE_SYMBOL = 'chDAI';

  function setUp() public virtual override {
    super.setUp();
    daiTokenizationSpoke = _deployTokenizationSpoke({
      hub: hub1,
      underlying: address(tokenList.dai),
      shareName: SHARE_NAME,
      shareSymbol: SHARE_SYMBOL,
      beaconOwner: ADMIN
    });
    _registerTokenizationSpoke({
      hub: hub1,
      assetId: daiAssetId,
      tokenizationSpoke: daiTokenizationSpoke,
      admin: ADMIN
    });

    SpokeActions.approve({vault: daiTokenizationSpoke, owner: alice, amount: 2100e18});
    vm.startPrank(alice);
    daiTokenizationSpoke.deposit(100e18, alice);
    daiTokenizationSpoke.useNonce(nonceKey);
    daiTokenizationSpoke.usePermitNonce();
    vm.stopPrank();
  }

  function test_deposit() public {
    vm.prank(alice);
    daiTokenizationSpoke.deposit(1000e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'deposit');
  }

  function test_mint() public {
    uint256 shares = daiTokenizationSpoke.previewMint(1000e18);
    vm.prank(alice);
    daiTokenizationSpoke.mint(shares, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'mint');
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    daiTokenizationSpoke.deposit(1000e18, alice);
    daiTokenizationSpoke.withdraw(500e18, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, partial');

    uint256 balance = daiTokenizationSpoke.maxWithdraw(alice);
    daiTokenizationSpoke.withdraw(balance, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: self, full');

    daiTokenizationSpoke.deposit(1000e18, alice);
    daiTokenizationSpoke.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    daiTokenizationSpoke.withdraw(500e18, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, partial');

    balance = daiTokenizationSpoke.maxWithdraw(alice);
    daiTokenizationSpoke.withdraw(balance, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: on behalf, full');
    vm.stopPrank();
  }

  function test_redeem() public {
    vm.startPrank(alice);
    daiTokenizationSpoke.deposit(1000e18, alice);
    uint256 shares = daiTokenizationSpoke.balanceOf(alice);
    daiTokenizationSpoke.redeem(shares / 2, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, partial');

    shares = daiTokenizationSpoke.maxRedeem(alice);
    daiTokenizationSpoke.redeem(shares, alice, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: self, full');

    daiTokenizationSpoke.deposit(1000e18, alice);
    daiTokenizationSpoke.approve(bob, 1000e18);
    vm.stopPrank();

    vm.startPrank(bob);
    shares = daiTokenizationSpoke.balanceOf(alice);
    daiTokenizationSpoke.redeem(shares / 2, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, partial');

    shares = daiTokenizationSpoke.maxRedeem(alice);
    daiTokenizationSpoke.redeem(shares, bob, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'redeem: on behalf, full');
    vm.stopPrank();
  }

  function test_depositWithSig() public {
    ITokenizationSpoke.TokenizedDeposit memory p = ITokenizationSpoke.TokenizedDeposit({
      depositor: alice,
      assets: 1000e18,
      receiver: alice,
      nonce: daiTokenizationSpoke.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiTokenizationSpoke, p));
    SpokeActions.approve({vault: daiTokenizationSpoke, owner: alice, amount: p.assets});

    daiTokenizationSpoke.depositWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'depositWithSig');
  }

  function test_mintWithSig() public {
    ITokenizationSpoke.TokenizedMint memory p = ITokenizationSpoke.TokenizedMint({
      depositor: alice,
      shares: daiTokenizationSpoke.previewMint(1000e18),
      receiver: alice,
      nonce: daiTokenizationSpoke.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiTokenizationSpoke, p));
    SpokeActions.approve({vault: daiTokenizationSpoke, owner: alice, amount: p.shares});

    daiTokenizationSpoke.mintWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'mintWithSig');
  }

  function test_withdrawWithSig() public {
    ITokenizationSpoke.TokenizedWithdraw memory p = ITokenizationSpoke.TokenizedWithdraw({
      owner: alice,
      assets: 500e18,
      receiver: alice,
      nonce: daiTokenizationSpoke.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiTokenizationSpoke, p));
    SpokeActions.approve({vault: daiTokenizationSpoke, owner: alice, amount: p.assets});
    vm.prank(alice);
    daiTokenizationSpoke.deposit(p.assets, alice);

    daiTokenizationSpoke.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_redeemWithSig() public {
    ITokenizationSpoke.TokenizedRedeem memory p = ITokenizationSpoke.TokenizedRedeem({
      owner: alice,
      shares: 1000e18,
      receiver: alice,
      nonce: daiTokenizationSpoke.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(daiTokenizationSpoke, p));
    SpokeActions.approve({vault: daiTokenizationSpoke, owner: alice, amount: p.shares});
    vm.prank(alice);
    daiTokenizationSpoke.mint(p.shares, alice);

    daiTokenizationSpoke.redeemWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'redeemWithSig');
  }

  function test_permit() public {
    EIP712Types.Permit memory p = EIP712Types.Permit({
      owner: alice,
      spender: bob,
      value: 1000e18,
      nonce: daiTokenizationSpoke.nonces(alice),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, _getTypedDataHash(daiTokenizationSpoke, p));

    vm.expectEmit(address(daiTokenizationSpoke));
    emit IERC20.Approval(p.owner, p.spender, p.value);

    daiTokenizationSpoke.permit(p.owner, p.spender, p.value, p.deadline, v, r, s);
    vm.snapshotGasLastCall(NAMESPACE, 'permit');

    assertEq(daiTokenizationSpoke.allowance(p.owner, p.spender), p.value);
  }
}
