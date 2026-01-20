// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/gas/Spoke.Operations.base.gas.t.sol';

/// forge-config: default.isolate = true
contract SpokeOperations_Gas_Tests is SpokeOperationsGasBase {
  function test_supply() public {
    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: 0 borrows, collateral disabled');

    spoke.supply(reserveId.usdx, 1000e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: second action, same reserve');

    spoke.supply(reserveId.weth, 1000e18, alice);

    spoke.setUsingAsCollateral(reserveId.weth, true, alice);
    spoke.supply(reserveId.weth, 1e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supply: 0 borrows, collateral enabled');
    vm.stopPrank();
  }

  function test_usingAsCollateral() public {
    vm.prank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 0 borrows, enable');

    spoke.supply(reserveId.usdx, 10000e6, alice);
    spoke.borrow(reserveId.dai, 100e18, alice);
    skip(100);

    spoke.setUsingAsCollateral(reserveId.weth, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 1 borrow, enable');

    spoke.setUsingAsCollateral(reserveId.weth, false, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 1 borrow, disable');

    spoke.borrow(reserveId.weth, 0.1e18, alice);
    skip(100);

    spoke.setUsingAsCollateral(reserveId.wbtc, true, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 2 borrows, enable');

    spoke.setUsingAsCollateral(reserveId.wbtc, false, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'usingAsCollateral: 2 borrows, disable');
    vm.stopPrank();
  }

  function test_withdraw() public {
    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 100e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);

    spoke.withdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 0 borrows, partial');

    skip(100);

    spoke.withdraw(reserveId.usdx, UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 0 borrows, full');

    spoke.supply(reserveId.usdx, 10000e6, alice);
    spoke.borrow(reserveId.dai, 1e18, alice);
    skip(100);

    spoke.withdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 1 borrow, partial');
    spoke.borrow(reserveId.weth, 1e18, alice);

    spoke.withdraw(reserveId.usdx, 1e6, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: 2 borrows, partial');
    spoke.supply(reserveId.weth, 1000e18, alice);

    spoke.withdraw(reserveId.weth, UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdraw: non collateral');
    vm.stopPrank();
  }

  function test_borrow() public {
    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);
    spoke.setUsingAsCollateral(reserveId.dai, true, bob);
    spoke.borrow(reserveId.dai, 500e18, bob);
    skip(100);
    spoke.borrow(reserveId.dai, 1e18, bob);
    vm.stopPrank();

    skip(100);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);

    spoke.borrow(reserveId.dai, 500e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrow: first');

    skip(100);

    spoke.borrow(reserveId.dai, 1e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrow: second action, same reserve');
    vm.stopPrank();
  }

  function test_repay() public {
    vm.prank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    spoke.borrow(reserveId.dai, 500e18, alice);

    spoke.repay(reserveId.dai, 200e18, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'repay: partial');

    spoke.repay(reserveId.dai, type(uint256).max, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'repay: full');
    vm.stopPrank();
  }

  function test_updateRiskPremium() public {
    vm.prank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);

    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 2000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);

    spoke.borrow(reserveId.dai, 500e18, alice);
    skip(100);

    spoke.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremium: 1 borrow');

    spoke.borrow(reserveId.usdx, 500e6, alice);
    skip(100);

    spoke.updateUserRiskPremium(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremium: 2 borrows');
    vm.stopPrank();
  }

  function test_updateUserDynamicConfig() public {
    vm.startPrank(alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    _updateLiquidationFee(spoke, reserveId.usdx, 10_00);

    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfig: 1 collateral');

    spoke.setUsingAsCollateral(reserveId.dai, true, alice);
    _updateLiquidationFee(spoke, reserveId.dai, 15_00);

    spoke.updateUserDynamicConfig(alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfig: 2 collaterals');
    vm.stopPrank();
  }

  function test_multicall_ops() public {
    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 1000e18, bob);
    spoke.supply(reserveId.usdx, 1000e6, bob);
    spoke.supply(reserveId.wbtc, 1e18, bob);

    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeCall(ISpokeBase.supply, (reserveId.dai, 1000e18, bob));
    calls[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId.dai, true, bob));

    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'supply + enable collateral (multicall)');

    // supplyWithPermit (dai)
    tokenList.dai.approve(address(spoke), 0);
    (, uint256 bobPk) = makeAddrAndKey('bob');
    EIP712Types.Permit memory permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 1000e6,
      nonce: tokenList.dai.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPk, _getTypedDataHash(tokenList.dai, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.dai, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(ISpokeBase.supply, (reserveId.dai, permit.value, permit.owner));
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + supply (multicall)');

    spoke.borrow(reserveId.usdx, 500e6, bob);

    // repayWithPermit (usdx)
    tokenList.usdx.approve(address(spoke), 0);
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 500e6,
      nonce: tokenList.usdx.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.usdx, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.usdx, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(ISpokeBase.repay, (reserveId.usdx, permit.value, permit.owner));
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + repay (multicall)');

    // supplyWithPermitAndEnableCollateral (wbtc)
    calls = new bytes[](3);
    tokenList.wbtc.approve(address(spoke), 0);
    (, bobPk) = makeAddrAndKey('bob');
    permit = EIP712Types.Permit({
      owner: bob,
      spender: address(spoke),
      value: 1000e6,
      nonce: tokenList.wbtc.nonces(bob),
      deadline: vm.getBlockTimestamp()
    });
    (v, r, s) = vm.sign(bobPk, _getTypedDataHash(tokenList.wbtc, permit));
    calls[0] = abi.encodeCall(
      ISpoke.permitReserve,
      (reserveId.wbtc, permit.owner, permit.value, permit.deadline, v, r, s)
    );
    calls[1] = abi.encodeCall(ISpokeBase.supply, (reserveId.wbtc, permit.value, permit.owner));
    calls[2] = abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId.wbtc, true, permit.owner));
    spoke.multicall(calls);
    vm.snapshotGasLastCall(NAMESPACE, 'permitReserve + supply + enable collateral (multicall)');

    vm.stopPrank();
  }

  function test_setUserPositionManagersWithSig() public {
    (address user, uint256 userPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    vm.label(user, 'user');
    address positionManager = vm.randomAddress();
    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(positionManager, true);

    uint192 nonceKey = _randomNonceKey();
    vm.prank(user);
    spoke.useNonce(nonceKey);

    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(positionManager, true);

    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      user: user,
      updates: updates,
      nonce: spoke.nonces(user, nonceKey),
      deadline: vm.randomUint(vm.getBlockTimestamp(), MAX_SKIP_TIME)
    });
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(spoke, p));
    bytes memory signature = abi.encodePacked(r, s, v);

    spoke.setUserPositionManagersWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserPositionManagersWithSig: enable');

    p.updates[0].approve = false;
    p.nonce = spoke.nonces(user, nonceKey);
    (v, r, s) = vm.sign(userPk, _getTypedDataHash(spoke, p));
    signature = abi.encodePacked(r, s, v);

    spoke.setUserPositionManagersWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserPositionManagersWithSig: disable');
  }
}

/// forge-config: default.isolate = true
contract SpokeOperations_Basic_ZeroRiskPremium_Gas_Tests is SpokeOperations_Gas_Tests {
  function _afterSetUp() internal override {
    NAMESPACE = 'Spoke.Operations.ZeroRiskPremium';

    _updateCollateralRisk(spoke, reserveId.dai, 0);
    _updateCollateralRisk(spoke, reserveId.weth, 0);
    _updateCollateralRisk(spoke, reserveId.usdx, 0);
    _updateCollateralRisk(spoke, reserveId.wbtc, 0);
  }
}
