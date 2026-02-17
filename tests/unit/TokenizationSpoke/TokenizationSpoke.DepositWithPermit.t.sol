// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/TokenizationSpoke/TokenizationSpoke.Base.t.sol';

contract TokenizationSpokeDepositWithPermitTest is TokenizationSpokeBaseTest {
  ITokenizationSpoke public vault;
  TestnetERC20 public asset;

  function setUp() public virtual override {
    super.setUp();
    vault = daiVault;
    asset = TestnetERC20(vault.asset());
  }

  function test_depositWithPermit_forwards_correct_call() public {
    address owner = vm.randomAddress();
    address receiver = vm.randomAddress();
    address spender = address(vault);
    uint256 maxAssets = vault.maxDeposit(receiver);
    uint256 value = maxAssets == type(uint256).max
      ? vm.randomUint(1, MAX_SUPPLY_AMOUNT)
      : vm.randomUint(1, maxAssets);
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    asset.mint(owner, value);
    vm.prank(owner);
    asset.approve(address(vault), value);

    vm.expectCall(
      address(asset),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1
    );
    vm.prank(owner);
    vault.depositWithPermit(value, receiver, deadline, v, r, s);
  }

  function test_depositWithPermit_ignores_permit_reverts() public {
    vm.mockCallRevert(address(asset), TestnetERC20.permit.selector, vm.randomBytes(64));

    address owner = vm.randomAddress();
    address receiver = vm.randomAddress();
    uint256 maxAssets = vault.maxDeposit(receiver);
    uint256 assets = maxAssets == type(uint256).max
      ? vm.randomUint(1, MAX_SUPPLY_AMOUNT)
      : vm.randomUint(1, maxAssets);

    asset.mint(owner, assets);
    vm.prank(owner);
    asset.approve(address(vault), assets);

    vm.prank(owner);
    vault.depositWithPermit(
      assets,
      receiver,
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_depositWithPermit() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    address receiver = vm.randomAddress();
    uint256 maxAssets = vault.maxDeposit(receiver);
    uint256 assets = maxAssets == type(uint256).max
      ? vm.randomUint(1, MAX_SUPPLY_AMOUNT)
      : vm.randomUint(1, maxAssets);

    asset.mint(user, assets);
    assertEq(asset.allowance(user, address(vault)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(vault),
      value: assets,
      deadline: _warpBeforeRandomDeadline(),
      nonce: asset.nonces(user)
    });

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(asset, params));

    uint256 expectedShares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), assets);

    vm.expectEmit(address(asset));
    emit IERC20.Approval(user, address(vault), params.value);

    vm.expectEmit(address(vault));
    emit IERC4626.Deposit(user, receiver, assets, expectedShares);

    vm.prank(user);
    uint256 shares = vault.depositWithPermit(assets, receiver, params.deadline, v, r, s);

    assertEq(shares, expectedShares);
    assertEq(asset.allowance(user, address(vault)), 0);
    assertEq(vault.balanceOf(receiver), expectedShares);
  }

  function test_depositWithPermit_works_with_existing_allowance() public {
    address user = vm.randomAddress();
    address receiver = vm.randomAddress();
    uint256 maxAssets = vault.maxDeposit(receiver);
    uint256 assets = maxAssets == type(uint256).max
      ? vm.randomUint(1, MAX_SUPPLY_AMOUNT)
      : vm.randomUint(1, maxAssets);

    asset.mint(user, assets);

    vm.prank(user);
    asset.approve(address(vault), assets);

    vm.prank(user);
    uint256 shares = vault.depositWithPermit(
      assets,
      receiver,
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );

    uint256 expectedShares = IHub(vault.hub()).previewAddByAssets(vault.assetId(), assets);
    assertEq(shares, expectedShares);
    assertEq(vault.balanceOf(receiver), expectedShares);
    assertEq(asset.allowance(user, address(vault)), 0);
  }
}
