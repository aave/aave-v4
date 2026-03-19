// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/helpers/position-manager/signature-gateway/SignatureGatewayHelpers.sol';
import 'tests/setup/Base.t.sol';

/// forge-config: default.isolate = true
contract NativeTokenGateway_Gas_Tests is Base {
  string internal NAMESPACE = 'NativeTokenGateway.Operations';

  NativeTokenGateway public nativeTokenGateway;

  function setUp() public virtual override {
    super.setUp();

    nativeTokenGateway = new NativeTokenGateway(address(tokenList.weth), address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(nativeTokenGateway), true);
    vm.prank(address(ADMIN));
    nativeTokenGateway.registerSpoke(address(spoke1), true);
    vm.prank(bob);
    spoke1.setUserPositionManager(address(nativeTokenGateway), true);

    deal(address(tokenList.weth), MAX_SUPPLY_AMOUNT);
    deal(bob, MAX_SUPPLY_AMOUNT_WETH);
  }

  function test_supplyNative() public {
    uint256 amount = 100e18;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

    vm.prank(bob);
    nativeTokenGateway.supplyNative{value: amount}(address(spoke1), _wethReserveId(spoke1), amount);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyNative');
  }

  function test_supplyAndCollateralNative() public {
    uint256 amount = 100e18;
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

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
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: MAX_SUPPLY_AMOUNT_WETH,
      onBehalfOf: bob
    });
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: amount,
      onBehalfOf: bob
    });

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

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: bobSupplyAmount,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: aliceSupplyAmount,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

    vm.prank(bob);
    nativeTokenGateway.borrowNative(address(spoke1), _wethReserveId(spoke1), borrowAmount);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowNative');
  }

  function test_repayNative() public {
    uint256 aliceSupplyAmount = 10e18;
    uint256 bobSupplyAmount = 100000e18;
    uint256 borrowAmount = 10e18;
    uint256 repayAmount = 5e18;

    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: _daiReserveId(spoke1),
      caller: bob,
      amount: bobSupplyAmount,
      onBehalfOf: bob
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: alice,
      amount: aliceSupplyAmount,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: _wethReserveId(spoke1),
      caller: bob,
      amount: 1e18,
      onBehalfOf: bob
    });

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
contract SignatureGateway_Gas_Tests is Base, SignatureGatewayHelpers {
  string internal NAMESPACE = 'SignatureGateway.Operations';
  uint192 internal nonceKey = 0;

  ISignatureGateway public gateway;

  function setUp() public virtual override {
    super.setUp();
    gateway = ISignatureGateway(new SignatureGateway(ADMIN));

    vm.prank(address(ADMIN));
    gateway.registerSpoke(address(spoke1), true);
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(alice);
    gateway.useNonce(nonceKey);
  }

  function test_supplyWithSig() public {
    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: p.reserveId,
      owner: alice,
      spender: address(gateway),
      amount: p.amount
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount,
      onBehalfOf: alice
    });

    gateway.supplyWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyWithSig');
  }

  function test_withdrawWithSig() public {
    ISignatureGateway.Withdraw memory p = ISignatureGateway.Withdraw({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    SpokeActions.supply({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: 200e18,
      onBehalfOf: alice
    });
    SpokeActions.withdraw({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: 100e18,
      onBehalfOf: alice
    });

    gateway.withdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_borrowWithSig() public {
    ISignatureGateway.Borrow memory p = ISignatureGateway.Borrow({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount * 4,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount,
      onBehalfOf: alice
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.borrowWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowWithSig');
  }

  function test_repayWithSig() public {
    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      amount: 100e18,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    SpokeActions.supplyCollateral({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount * 10,
      onBehalfOf: alice
    });
    SpokeActions.borrow({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount * 3,
      onBehalfOf: alice
    });
    SpokeActions.approve({
      spoke: spoke1,
      reserveId: p.reserveId,
      owner: alice,
      spender: address(gateway),
      amount: p.amount * 2
    });
    SpokeActions.repay({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: p.amount,
      onBehalfOf: alice
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.repayWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'repayWithSig');
  }

  function test_setUsingAsCollateralWithSig() public {
    ISignatureGateway.SetUsingAsCollateral memory p = ISignatureGateway.SetUsingAsCollateral({
      spoke: address(spoke1),
      reserveId: _wethReserveId(spoke1),
      useAsCollateral: true,
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    SpokeActions.supply({
      spoke: spoke1,
      reserveId: p.reserveId,
      caller: alice,
      amount: 1e18,
      onBehalfOf: alice
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    gateway.setUsingAsCollateralWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralWithSig');
  }

  function test_updateUserRiskPremiumWithSig() public {
    ISignatureGateway.UpdateUserRiskPremium memory p = ISignatureGateway.UpdateUserRiskPremium({
      spoke: address(spoke1),
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    gateway.updateUserRiskPremiumWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremiumWithSig');
  }

  function test_updateUserDynamicConfigWithSig() public {
    ISignatureGateway.UpdateUserDynamicConfig memory p = ISignatureGateway.UpdateUserDynamicConfig({
      spoke: address(spoke1),
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, p));

    vm.prank(alice);
    spoke1.updateUserDynamicConfig(alice);

    gateway.updateUserDynamicConfigWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfigWithSig');
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), true);
    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke1.nonces(alice, nonceKey), // note: this typed sig is forwarded to spoke
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), false);

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
