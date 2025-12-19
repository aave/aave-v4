// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// forge-config: default.isolate = true
contract PositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManagerBase.Operations';

  PositionManagerBaseWrapper public positionManager;
  uint192 internal nonceKey = 0;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new PositionManagerBaseWrapper(address(ADMIN));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(positionManager),
      user: alice,
      approve: true,
      nonce: spoke1.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), false);

    positionManager.setSelfAsUserPositionManagerWithSig({
      spoke: address(spoke1),
      user: p.user,
      approve: p.approve,
      nonce: p.nonce,
      deadline: p.deadline,
      signature: signature
    });
    vm.snapshotGasLastCall(NAMESPACE, 'setSelfAsUserPositionManagerWithSig');
  }
}

/// forge-config: default.isolate = true
contract SupplyRepayPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'SupplyRepayPositionManager.Operations';

  SupplyRepayPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new SupplyRepayPositionManager(address(ADMIN));
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
contract AllowancePositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'AllowancePositionManager.Operations';

  AllowancePositionManager public positionManager;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    (alice, alicePk) = makeAddrAndKey('alice');

    positionManager = new AllowancePositionManager(address(ADMIN));
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

  /// forge-config: default.isolate = false
  function test_withdrawOnBehalfOf_WithTemporaryWithdrawAllowance() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(
      address(spoke1),
      _daiReserveId(spoke1),
      bob,
      UINT256_MAX
    );

    Utils.supply(spoke1, _daiReserveId(spoke1), alice, mintAmount_DAI, alice);
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), amount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawOnBehalfOf: partial (with temporary allowance)');

    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(
      address(spoke1),
      _daiReserveId(spoke1),
      bob,
      UINT256_MAX
    );

    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(address(spoke1), _daiReserveId(spoke1), UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'withdrawOnBehalfOf: full (with temporary allowance)');
  }

  function test_borrowOnBehalfOf() public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    uint256 borrowAmount = 750e18;

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), _daiReserveId(spoke1), bob, borrowAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), borrowAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowOnBehalfOf');
  }

  /// forge-config: default.isolate = false
  function test_borrowOnBehalfOf_WithTemporaryDelegateCredit() public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    uint256 borrowAmount = 750e18;

    vm.prank(alice);
    positionManager.temporaryDelegateCredit(
      address(spoke1),
      _daiReserveId(spoke1),
      bob,
      borrowAmount
    );

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(bob);
    positionManager.borrowOnBehalfOf(address(spoke1), _daiReserveId(spoke1), borrowAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'borrowOnBehalfOf (with temporary allowance)');
  }

  function test_approveWithdraw() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'approveWithdraw');
  }

  function test_approveWithdrawWithSig() public {
    uint256 amount = 100e18;

    EIP712Types.WithdrawPermit memory p = EIP712Types.WithdrawPermit({
      spoke: address(spoke1),
      reserveId: _daiReserveId(spoke1),
      owner: alice,
      spender: bob,
      amount: amount,
      nonce: positionManager.nonces(alice, _randomNonceKey()),
      deadline: _warpBeforeRandomDeadline()
    });
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes32 digest = _typedDataHash(
      positionManager,
      vm.eip712HashStruct('WithdrawPermit', abi.encode(p))
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'approveWithdrawWithSig');
  }

  function test_temporaryApproveWithdraw() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'temporaryApproveWithdraw');
  }

  function test_renounceWithdrawAllowance() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(address(spoke1), _daiReserveId(spoke1), bob, amount);

    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(address(spoke1), _daiReserveId(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceWithdrawAllowance');
  }

  function test_creditDelegation() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'delegateCredit');
  }

  function test_creditDelegationWithSig() public {
    uint256 amount = 100e18;

    EIP712Types.CreditDelegation memory p = EIP712Types.CreditDelegation({
      spoke: address(spoke1),
      reserveId: _daiReserveId(spoke1),
      owner: alice,
      spender: bob,
      amount: amount,
      nonce: positionManager.nonces(alice, _randomNonceKey()),
      deadline: _warpBeforeRandomDeadline()
    });
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes32 digest = _typedDataHash(
      positionManager,
      vm.eip712HashStruct('CreditDelegation', abi.encode(p))
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.prank(vm.randomAddress());
    positionManager.delegateCreditWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'delegateCreditWithSig');
  }

  function test_temporaryDelegateCredit() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.temporaryDelegateCredit(address(spoke1), _daiReserveId(spoke1), bob, amount);
    vm.snapshotGasLastCall(NAMESPACE, 'temporaryDelegateCredit');
  }

  function test_renounceCreditDelegation() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.delegateCredit(address(spoke1), _daiReserveId(spoke1), bob, amount);

    vm.prank(bob);
    positionManager.renounceCreditDelegation(address(spoke1), _daiReserveId(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceCreditDelegation');
  }

  function _typedDataHash(
    IAllowancePositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}

/// forge-config: default.isolate = true
contract PositionConfigPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionConfigPositionManager.Operations';

  PositionConfigPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new PositionConfigPositionManager(address(ADMIN));

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

  function test_setUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setUsingAsCollateralPermission');
  }

  function test_setUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserRiskPremiumPermission');
  }

  function test_setUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(address(spoke1), bob, true);
    vm.snapshotGasLastCall(NAMESPACE, 'setUserDynamicConfigPermission');
  }

  function test_renounceGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceGlobalPermission');
  }

  function test_renounceUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceUsingAsCollateralPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceUsingAsCollateralPermission');
  }

  function test_renounceUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceUserRiskPremiumPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceUserRiskPremiumPermission');
  }

  function test_renounceUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(address(spoke1), bob, true);

    vm.prank(bob);
    positionManager.renounceUserDynamicConfigPermission(address(spoke1), alice);
    vm.snapshotGasLastCall(NAMESPACE, 'renounceUserDynamicConfigPermission');
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
