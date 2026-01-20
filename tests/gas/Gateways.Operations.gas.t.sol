// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/Base.t.sol';
import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import 'tests/unit/misc/SignatureGateway/SignatureGateway.Permit2.Base.t.sol';
import {BatchEIP712} from 'src/position-manager/libraries/BatchEIP712.sol';

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
  uint192 internal nonceKey = 0;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(alice);
    gateway.useNonce(nonceKey);
  }

  function test_supplyWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    ISignatureGateway.SupplyAction memory action = ISignatureGateway.SupplyAction({
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline(),
      params: ISignatureGateway.SupplyParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    gateway.supplyWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyWithSig');
  }

  function test_withdrawWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    ISignatureGateway.WithdrawAction memory action = ISignatureGateway.WithdrawAction({
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline(),
      params: ISignatureGateway.WithdrawParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    Utils.supply(spoke1, reserveId, alice, 200e18, alice);
    Utils.withdraw(spoke1, reserveId, alice, 100e18, alice);

    gateway.withdrawWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawWithSig');
  }

  function test_borrowWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    ISignatureGateway.BorrowAction memory action = ISignatureGateway.BorrowAction({
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline(),
      params: ISignatureGateway.BorrowParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });
    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 4, alice);
    Utils.borrow(spoke1, reserveId, alice, amount, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    gateway.borrowWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowWithSig');
  }

  function test_repayWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    ISignatureGateway.RepayAction memory action = ISignatureGateway.RepayAction({
      onBehalfOf: alice,
      nonce: gateway.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline(),
      params: ISignatureGateway.RepayParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });
    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 10, alice);
    Utils.borrow(spoke1, reserveId, alice, amount * 3, alice);
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount * 2);
    Utils.repay(spoke1, reserveId, alice, amount, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    gateway.repayWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'repayWithSig');
  }

  function test_setUsingAsCollateralWithSig() public {
    uint256 reserveId = _wethReserveId(spoke1);
    ISignatureGateway.SetUsingAsCollateralAction memory action = ISignatureGateway
      .SetUsingAsCollateralAction({
        onBehalfOf: alice,
        nonce: gateway.nonces(alice, nonceKey),
        deadline: _warpBeforeRandomDeadline(),
        params: ISignatureGateway.SetUsingAsCollateralParams({
          spoke: address(spoke1),
          reserveId: reserveId,
          useAsCollateral: true
        })
      });
    Utils.supply(spoke1, reserveId, alice, 1e18, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    gateway.setUsingAsCollateralWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralWithSig');
  }

  function test_updateUserRiskPremiumWithSig() public {
    ISignatureGateway.UpdateUserRiskPremiumAction memory action = ISignatureGateway
      .UpdateUserRiskPremiumAction({
        user: alice,
        nonce: gateway.nonces(alice, nonceKey),
        deadline: _warpBeforeRandomDeadline(),
        params: ISignatureGateway.UpdateUserRiskPremiumParams({spoke: address(spoke1)})
      });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    vm.prank(alice);
    spoke1.updateUserRiskPremium(alice);

    gateway.updateUserRiskPremiumWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremiumWithSig');
  }

  function test_updateUserDynamicConfigWithSig() public {
    ISignatureGateway.UpdateUserDynamicConfigAction memory action = ISignatureGateway
      .UpdateUserDynamicConfigAction({
        user: alice,
        nonce: gateway.nonces(alice, nonceKey),
        deadline: _warpBeforeRandomDeadline(),
        params: ISignatureGateway.UpdateUserDynamicConfigParams({spoke: address(spoke1)})
      });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(gateway, action));

    vm.prank(alice);
    spoke1.updateUserDynamicConfig(alice);

    gateway.updateUserDynamicConfigWithSig(action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfigWithSig');
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(gateway), true);
    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      user: alice,
      updates: updates,
      nonce: spoke1.nonces(alice, nonceKey), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), false);

    gateway.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      user: p.user,
      approve: p.updates[0].approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });
    vm.snapshotGasLastCall(NAMESPACE, 'setSelfAsUserPositionManagerWithSig');
  }
}

/// forge-config: default.isolate = true
contract SignatureGatewayBatch_Gas_Tests is SignatureGatewayBaseTest {
  using BatchEIP712 for *;

  string internal NAMESPACE = 'SignatureGateway.BatchOperations';
  uint192 internal nonceKey = 0;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
    vm.prank(alice);
    gateway.useNonce(nonceKey);
  }

  function _getBatchDigest(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 structHash = BatchEIP712.hashBatch(
      actionTypes,
      actionData,
      onBehalfOf,
      nonce,
      deadline
    );
    return keccak256(abi.encodePacked('\x19\x01', gateway.DOMAIN_SEPARATOR(), structHash));
  }

  function test_executeBatchWithSig_singleSupply() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(
      ISignatureGateway.SupplyParams({spoke: address(spoke1), reserveId: reserveId, amount: amount})
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'executeBatchWithSig: 1 action (supply)');
  }

  function test_executeBatchWithSig_supplyAndSetCollateral() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(
      ISignatureGateway.SupplyParams({spoke: address(spoke1), reserveId: reserveId, amount: amount})
    );
    actionData[1] = abi.encode(
      ISignatureGateway.SetUsingAsCollateralParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        useAsCollateral: true
      })
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);
    Utils.supplyCollateral(spoke1, reserveId, alice, amount, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'executeBatchWithSig: 2 actions (supply+setCollateral)');
  }

  function test_executeBatchWithSig_supplyWithdraw() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 supplyAmount = 100e18;
    uint256 withdrawAmount = 50e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    Utils.supply(spoke1, reserveId, alice, supplyAmount * 2, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(
      ISignatureGateway.SupplyParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: supplyAmount
      })
    );
    actionData[1] = abi.encode(
      ISignatureGateway.WithdrawParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: withdrawAmount
      })
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), supplyAmount);
    Utils.withdraw(spoke1, reserveId, alice, withdrawAmount, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'executeBatchWithSig: 2 actions (supply+withdraw)');
  }

  function test_executeBatchWithSig_borrowRepay() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 borrowAmount = 100e18;
    uint256 repayAmount = 50e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 10, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(
      ISignatureGateway.BorrowParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: borrowAmount
      })
    );
    actionData[1] = abi.encode(
      ISignatureGateway.RepayParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: repayAmount
      })
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), repayAmount);
    Utils.repay(spoke1, reserveId, alice, repayAmount, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'executeBatchWithSig: 2 actions (borrow+repay)');
  }

  function test_executeBatchWithSig_threeActions() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    Utils.supply(spoke1, reserveId, alice, amount * 3, alice);

    uint8[] memory actionTypes = new uint8[](3);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](3);
    actionData[0] = abi.encode(
      ISignatureGateway.SupplyParams({spoke: address(spoke1), reserveId: reserveId, amount: amount})
    );
    actionData[1] = abi.encode(
      ISignatureGateway.SetUsingAsCollateralParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        useAsCollateral: true
      })
    );
    actionData[2] = abi.encode(
      ISignatureGateway.WithdrawParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount / 2
      })
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);
    Utils.setUsingAsCollateral(spoke1, reserveId, alice, true, alice);
    Utils.withdraw(spoke1, reserveId, alice, amount / 2, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(
      NAMESPACE,
      'executeBatchWithSig: 3 actions (supply+setCollateral+withdraw)'
    );
  }

  function test_executeBatchWithSig_fiveActions() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, nonceKey);

    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 10, alice);
    Utils.borrow(spoke1, reserveId, alice, amount, alice);

    uint8[] memory actionTypes = new uint8[](5);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[3] = uint8(ISignatureGateway.ActionType.Repay);
    actionTypes[4] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](5);
    actionData[0] = abi.encode(
      ISignatureGateway.SupplyParams({spoke: address(spoke1), reserveId: reserveId, amount: amount})
    );
    actionData[1] = abi.encode(
      ISignatureGateway.SetUsingAsCollateralParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        useAsCollateral: true
      })
    );
    actionData[2] = abi.encode(
      ISignatureGateway.BorrowParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount / 2
      })
    );
    actionData[3] = abi.encode(
      ISignatureGateway.RepayParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount / 4
      })
    );
    actionData[4] = abi.encode(
      ISignatureGateway.WithdrawParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount / 4
      })
    );

    bytes memory signature = _sign(
      alicePk,
      _getBatchDigest(actionTypes, actionData, alice, nonce, deadline)
    );
    Utils.approve(spoke1, reserveId, alice, address(gateway), amount + amount / 4);
    Utils.borrow(spoke1, reserveId, alice, amount / 2, alice);
    Utils.repay(spoke1, reserveId, alice, amount / 4, alice);
    Utils.withdraw(spoke1, reserveId, alice, amount / 4, alice);

    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'executeBatchWithSig: 5 actions');
  }
}

/// forge-config: default.isolate = true
contract SignatureGatewayPermit2_Gas_Tests is SignatureGatewayPermit2BaseTest {
  string internal NAMESPACE = 'SignatureGateway.Operations';

  function setUp() public virtual override {
    super.setUp();
    vm.prank(alice);
    gateway.useNonce(100);
  }

  function test_supplyWithPermit2() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = vm.getBlockTimestamp() + 1 hours;
    uint256 gatewayNonce = gateway.nonces(alice, 100);

    ISignatureGateway.SupplyAction memory action = ISignatureGateway.SupplyAction({
      onBehalfOf: alice,
      nonce: gatewayNonce,
      deadline: deadline,
      params: ISignatureGateway.SupplyParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: amount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    bytes memory signature = _getPermit2SupplySignature(permit, action, alicePk);

    _approvePermit2(spoke1, reserveId, alice);
    Utils.supply(spoke1, reserveId, alice, amount, alice);

    gateway.supplyWithPermit2(permit, action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyWithPermit2');
  }

  function test_repayWithPermit2() public {
    uint256 reserveId = _wethReserveId(spoke1);
    uint256 amount = 100e18;
    uint256 deadline = vm.getBlockTimestamp() + 1 hours;
    uint256 gatewayNonce = gateway.nonces(alice, 100);

    Utils.supplyCollateral(spoke1, reserveId, alice, amount * 10, alice);
    Utils.borrow(spoke1, reserveId, alice, amount * 3, alice);
    Utils.repay(spoke1, reserveId, alice, amount, alice);

    ISignatureGateway.RepayAction memory action = ISignatureGateway.RepayAction({
      onBehalfOf: alice,
      nonce: gatewayNonce,
      deadline: deadline,
      params: ISignatureGateway.RepayParams({
        spoke: address(spoke1),
        reserveId: reserveId,
        amount: amount
      })
    });

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: amount
      }),
      nonce: _randomUnusedPermit2Nonce(alice),
      deadline: deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, action, alicePk);

    _approvePermit2(spoke1, reserveId, alice);

    gateway.repayWithPermit2(permit, action, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'repayWithPermit2');
  }
}
