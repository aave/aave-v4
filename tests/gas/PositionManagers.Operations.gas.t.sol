// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// forge-config: default.isolate = true
contract PositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManagerBase.Operations';

  PositionManagerBaseWrapper public positionManager;
  uint192 internal nonceKey = 0;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new PositionManagerBaseWrapper(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);

    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate(address(positionManager), true);

    ISpoke.SetUserPositionManagers memory p = ISpoke.SetUserPositionManagers({
      onBehalfOf: alice,
      updates: updates,
      nonce: spoke1.nonces(alice, nonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), false);

    positionManager.setSelfAsUserPositionManagerWithSig({
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

/// forge-config: default.isolate = true
contract GiverPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'GiverPositionManager.Operations';

  GiverPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new GiverPositionManager(address(ADMIN));
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);
  }

  function test_supplyOnBehalfOf() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    vm.prank(bob);
    positionManager.supplyOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'supplyOnBehalfOf');
  }

  function test_repayOnBehalfOf() public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;
    uint256 repayAmount = 50e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, 1e18, alice);

    vm.prank(bob);
    positionManager.repayOnBehalfOf(address(spoke1), _daiReserveId(spoke1), repayAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'repayOnBehalfOf');
  }
}

/// forge-config: default.isolate = true
contract TakerPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'TakerPositionManager.Operations';

  TakerPositionManager public positionManager;
  uint192 internal withdrawNonceKey = 0;
  uint192 internal creditNonceKey = 1;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new TakerPositionManager(address(ADMIN));
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
  }

  function test_withdrawOnBehalfOf() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, UINT256_MAX);

    Utils.supply(spoke1, _daiReserveId(spoke1), alice, mintAmount_DAI, alice);
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawOnBehalfOf: partial');

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, UINT256_MAX);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawOnBehalfOf: full');
  }

  function test_borrowOnBehalfOf() public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    uint256 borrowAmount = 750e18;

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, borrowAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), borrowAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowOnBehalfOf');
  }

  function test_approveWithdraw() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'approveWithdraw');
  }

  function test_approveWithdrawWithSig() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.useNonce(withdrawNonceKey);

    ITakerPositionManager.WithdrawPermit memory p = ITakerPositionManager.WithdrawPermit({
      spoke: address(spoke1),
      reserveId: _daiReserveId(spoke1),
      owner: alice,
      spender: bob,
      amount: amount,
      nonce: positionManager.nonces(alice, withdrawNonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes32 digest = _typedDataHash(
      positionManager,
      vm.eip712HashStruct('WithdrawPermit', abi.encode(p))
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'approveWithdrawWithSig');
  }

  function test_renounceWithdrawAllowance() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);

    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceWithdrawAllowance');
  }

  function test_approveBorrow() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'approveBorrow');
  }

  function test_approveBorrowWithSig() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.useNonce(creditNonceKey);

    ITakerPositionManager.BorrowPermit memory p = ITakerPositionManager.BorrowPermit({
      spoke: address(spoke1),
      reserveId: _daiReserveId(spoke1),
      owner: alice,
      spender: bob,
      amount: amount,
      nonce: positionManager.nonces(alice, creditNonceKey),
      deadline: vm.getBlockTimestamp()
    });
    bytes32 digest = _typedDataHash(
      positionManager,
      vm.eip712HashStruct('BorrowPermit', abi.encode(p))
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.prank(vm.randomAddress());
    positionManager.approveBorrowWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'approveBorrowWithSig');
  }

  function test_renounceBorrowAllowance() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveBorrow(address(spoke1), _daiReserveId(spoke1), bob, amount);

    vm.prank(bob);
    positionManager.renounceBorrowAllowance(address(spoke1), _daiReserveId(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceBorrowAllowance');
  }

  function _typedDataHash(
    ITakerPositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}

/// forge-config: default.isolate = true
contract ConfigPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'ConfigPositionManager.Operations';

  ConfigPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new ConfigPositionManager(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
  }

  function test_setGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setGlobalPermission');
  }

  function test_setCanSetUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setCanSetUsingAsCollateralPermission');
  }

  function test_setCanUpdateUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setCanUpdateUserRiskPremiumPermission');
  }

  function test_setCanUpdateUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setCanUpdateUserDynamicConfigPermission');
  }

  function test_renounceGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceGlobalPermission');
  }

  function test_renounceCanUpdateUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setCanSetUsingAsCollateralPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceCanUpdateUsingAsCollateralPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceCanUpdateUsingAsCollateralPermission');
  }

  function test_renounceCanUpdateUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceCanUpdateUserRiskPremiumPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceCanUpdateUserRiskPremiumPermission');
  }

  function test_renounceCanUpdateUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceCanUpdateUserDynamicConfigPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceCanUpdateUserDynamicConfigPermission');
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      true,
      alice
    );
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralOnBehalfOf');
  }

  function test_updateUserRiskPremiumOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserRiskPremiumOnBehalfOf');
  }

  function test_updateUserDynamicConfigOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'updateUserDynamicConfigOnBehalfOf');
  }
}
