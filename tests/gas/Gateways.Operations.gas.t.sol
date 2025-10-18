// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';

/// forge-config: default.isolate = true
contract NativeTokenGateway_Gas_Tests is Base {
  string internal NAMESPACE = 'NativeTokenGateway.Operations';

  NativeTokenGateway public nativeTokenGateway;

  function setUp() public virtual override {
    super.setUp();
    initEnvironment();

    nativeTokenGateway = new NativeTokenGateway(address(tokenList.weth), address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(nativeTokenGateway), true);
    vm.prank(address(ADMIN));
    nativeTokenGateway.registerSpoke(address(spoke1), true);
    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    deal(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
    deal(bob, mintAmount_WETH);
  }

  function test_supplyNative() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, amount, bob);

    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(address(spoke1), _wethReserveId(spoke1), amount);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyNative');
  }

  function test_supplyAndCollateralNative() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, amount, bob);

    vm.prank(bob);
    nativeTokenGateway.supplyAsCollateralNative{value: amount}(
      address(spoke1),
      _wethReserveId(spoke1),
      amount
    );
    vm.snapshotGasLastCall(NAMESPACE, 'supplyAsCollateralNative');
  }

  function test_withdrawNative() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, mintAmount_WETH, bob);
    Utils.withdraw(spoke1, _wethReserveId(spoke1), bob, amount, bob);

    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke1), _wethReserveId(spoke1), amount);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawNative: partial');

    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke1), _wethReserveId(spoke1), UINT256_MAX);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawNative: full');
  }

  function test_borrowNative() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 5e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);

    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(spoke1), _wethReserveId(spoke1), borrowAmount);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowNative');
  }

  function test_repayNative() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.supply(spoke1, _wethReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, borrowAmount, bob);
    Utils.repay(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);

    vm.prank(bob);
    nativeTokenGateway.repayNative{value: repayAmount}(
      address(spoke1),
      _wethReserveId(spoke1),
      repayAmount
    );
    vm.snapshotGasLastCall(NAMESPACE, 'repayNative');
  }
}

/// forge-config: default.isolate = true
contract SignatureGateway_Gas_Tests is SignatureGatewayBaseTest {
  string internal NAMESPACE = 'SignatureGateway.Operations';

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(alice);
    gateway.useNonce();
  }

  function test_supplyWithSig() public {
    EIP712Types.Supply memory p = EIP712Types.Supply({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount);
    Utils.supply(spoke1, p.reserveId, alice, p.amount, alice);

    gateway.supplyWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyWithSig');
  }

  function test_withdrawWithSig() public {
    EIP712Types.Withdraw memory p = EIP712Types.Withdraw({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    Utils.supply(spoke1, p.reserveId, alice, 200e18, alice);
    Utils.withdraw(spoke1, p.reserveId, alice, 100e18, alice);

    gateway.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_borrowWithSig() public {
    EIP712Types.Borrow memory p = EIP712Types.Borrow({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 4, alice);
    Utils.borrow(spoke1, p.reserveId, alice, p.amount, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.borrowWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowWithSig');
  }

  function test_repayWithSig() public {
    EIP712Types.Repay memory p = EIP712Types.Repay({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    Utils.supplyCollateral(spoke1, p.reserveId, alice, p.amount * 10, alice);
    Utils.borrow(spoke1, p.reserveId, alice, p.amount * 3, alice);
    Utils.approve(spoke1, p.reserveId, alice, address(gateway), p.amount * 2);
    Utils.repay(spoke1, p.reserveId, alice, p.amount, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.repayWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'repayWithSig');
  }

  function test_setUsingAsCollateralWithSig() public {
    EIP712Types.SetUsingAsCollateral memory p = EIP712Types.SetUsingAsCollateral({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      useAsCollateral: true,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    Utils.supply(spoke1, p.reserveId, alice, 1e18, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.setUsingAsCollateralWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralWithSig');
  }

  function test_updateUserRiskPremiumWithSig() public {
    EIP712Types.UpdateUserRiskPremium memory p = EIP712Types.UpdateUserRiskPremium({
      spoke: address(spoke1),
      user: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    gateway.updateUserRiskPremiumWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremiumWithSig');
  }

  function test_updateUserDynamicConfigWithSig() public {
    EIP712Types.UpdateUserDynamicConfig memory p = EIP712Types.UpdateUserDynamicConfig({
      spoke: address(spoke1),
      user: alice,
      nonce: gateway.nonces(alice),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.prank(alice);
    spoke1.updateUserDynamicConfig(alice);

    gateway.updateUserDynamicConfigWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfigWithSig');
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce();
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(gateway),
      user: alice,
      approve: true,
      nonce: spoke1.nonces(alice), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), false);

    gateway.setSelfAsUserPositionManagerWithSig(address(spoke1), p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setSelfAsUserPositionManagerWithSig');
  }
}
