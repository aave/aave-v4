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

    skip(100);

    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(address(spoke1), _wethReserveId(spoke1), amount);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyNative');
  }

  function test_supplyAndCollateralNative() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _wethReserveId(spoke1), bob, amount, bob);

    skip(100);

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

    skip(100);

    vm.prank(bob);
    nativeTokenGateway.withdrawNative(address(spoke1), _wethReserveId(spoke1), amount);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawNative: partial');

    skip(100);

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

    skip(100);

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

    skip(100);

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
  uint192 internal nonceKey = 0;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(alice);
    gateway.useNonce(nonceKey);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, 10_000e18, bob);
    Utils.supplyCollateral(spoke1, _wethReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _wethReserveId(spoke1), bob, 1e18, bob);

    skip(100);
  }

  function test_supplyWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    skip(100);

    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.supplyWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyWithSig');
  }

  function test_withdrawWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    Utils.supply(spoke1, reserveId, alice, amount * 2, alice);
    Utils.withdraw(spoke1, reserveId, alice, amount, alice);

    skip(100);

    ISignatureGateway.Withdraw memory p = ISignatureGateway.Withdraw({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_borrowWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 4, alice);
    Utils.borrow(spoke1, reserveId, alice, amount, alice);

    skip(100);

    ISignatureGateway.Borrow memory p = ISignatureGateway.Borrow({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.borrowWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowWithSig');
  }

  function test_repayWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 10, alice);
    Utils.borrow(spoke1, reserveId, alice, amount * 3, alice);
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount * 2);
    Utils.repay(spoke1, reserveId, alice, amount, alice);

    skip(100);

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.repayWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'repayWithSig');
  }

  function test_setUsingAsCollateralWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    Utils.supply(spoke1, reserveId, alice, 1e18, alice);

    skip(100);

    ISignatureGateway.SetUsingAsCollateral memory p = ISignatureGateway.SetUsingAsCollateral({
      spoke: address(spoke1),
      reserveId: reserveId,
      useAsCollateral: true,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.setUsingAsCollateralWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralWithSig');
  }

  function test_updateUserRiskPremiumWithSig() public {
    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    skip(100);

    ISignatureGateway.UpdateUserRiskPremium memory p = ISignatureGateway.UpdateUserRiskPremium({
      spoke: address(spoke1),
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.updateUserRiskPremiumWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremiumWithSig');
  }

  function test_updateUserDynamicConfigWithSig() public {
    vm.prank(alice);
    spoke1.updateUserDynamicConfig(alice);

    skip(100);

    ISignatureGateway.UpdateUserDynamicConfig memory p = ISignatureGateway.UpdateUserDynamicConfig({
      spoke: address(spoke1),
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.updateUserDynamicConfigWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfigWithSig');
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), false);

    skip(100);

    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), true);
    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke1.nonces(alice, nonceKey), // note: this typed sig is forwarded to spoke
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      onBehalfOf: p.onBehalfOf,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });
    vm.snapshotGasLastCall(NAMESPACE, 'setSelfAsUserPositionManagerWithSig');
  }
}
