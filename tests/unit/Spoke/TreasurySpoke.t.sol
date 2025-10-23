// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TreasurySpokeTest is SpokeBase {
  MockERC20 internal _testToken;

  function setUp() public virtual override {
    super.setUp();
    _testToken = new MockERC20();
  }

  function test_deploy_reverts_on_invalid_params() public {
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new TreasurySpoke(address(0));
  }

  function test_initial_state() public view {
    for (uint256 i; i < hub1.getAssetCount(); ++i) {
      assertEq(treasurySpoke.getSuppliedAmount(address(hub1), i), 0);
      assertEq(treasurySpoke.getSuppliedShares(address(hub1), i), 0);
    }
    assertEq(Ownable2Step(address(treasurySpoke)).owner(), TREASURY_ADMIN);
    assertEq(Ownable2Step(address(treasurySpoke)).pendingOwner(), address(0));
  }

  function test_supply_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.supply(address(hub1), daiAssetId, 1, caller);
  }

  function test_withdraw_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.withdraw(address(hub1), daiAssetId, 1, vm.randomAddress());
  }

  function test_supply(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), daiAssetId, amount, TREASURY_ADMIN);

    assertEq(treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId), amount);
  }

  /// treasury supplies to earn interest
  function test_withdraw_fuzz_amount_interestOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateLiquidityFee(hub1, daiAssetId, 0);

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), daiAssetId, amount, TREASURY_ADMIN);
    assertEq(treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(address(hub1), daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertEq(suppliedSharesBefore, treasurySpoke.getSuppliedShares(address(hub1), daiAssetId));
    uint256 interest = treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId) -
      suppliedAssetsBefore;
    vm.assume(interest > 0); // assume only cases where the initial amount generates interest

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), daiAssetId, amount + interest, TREASURY_ADMIN);
  }

  /// treasury does not supply but earn fees
  function test_withdraw_fuzz_amount_feesOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    assertEq(treasurySpoke.getSuppliedShares(address(hub1), daiAssetId), 0);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(address(hub1), daiAssetId), 0);
    uint256 fees = treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId);

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), daiAssetId, fees, TREASURY_ADMIN);
  }

  /// treasury supplies to earn interest and fees
  function test_withdraw_fuzz_amount_interestAndFees(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.supply(address(hub1), daiAssetId, amount, TREASURY_ADMIN);
    assertEq(treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(address(hub1), daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(address(hub1), daiAssetId), suppliedSharesBefore);
    uint256 interestAndFees = treasurySpoke.getSuppliedAmount(address(hub1), daiAssetId) -
      suppliedAssetsBefore;

    vm.prank(TREASURY_ADMIN);
    treasurySpoke.withdraw(address(hub1), daiAssetId, amount + interestAndFees, TREASURY_ADMIN);
  }

  function test_transfer_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.transfer(vm.randomAddress(), vm.randomAddress(), 1);
  }

  function test_transfer_revertsWith_InsufficientBalance(uint256 amount) public {
    vm.assume(amount > 0);
    address token = address(new MockERC20());

    vm.prank(TREASURY_ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(
        IERC20Errors.ERC20InsufficientBalance.selector,
        address(treasurySpoke),
        0,
        amount
      )
    );
    treasurySpoke.transfer(token, vm.randomAddress(), amount);
  }

  function test_transfer_fuzz(address recipient, uint256 amount, uint256 transferAmount) public {
    vm.assume(recipient != address(0));
    vm.assume(recipient != address(treasurySpoke));
    amount = bound(amount, 1, type(uint128).max);
    transferAmount = bound(transferAmount, 1, amount);

    _testToken.mint(address(treasurySpoke), amount);

    vm.expectEmit(address(_testToken));
    emit IERC20.Transfer(address(treasurySpoke), recipient, transferAmount);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.transfer(address(_testToken), recipient, transferAmount);

    assertEq(_testToken.balanceOf(address(treasurySpoke)), amount - transferAmount);
    assertEq(_testToken.balanceOf(recipient), transferAmount);
  }

  function test_withdraw_maxLiquidityFee() public {
    test_withdraw_fuzz_maxLiquidityFee(_daiReserveId(spoke1), 1000e18, 340 days);
  }

  function test_withdraw_fuzz_maxLiquidityFee(
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime
  ) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, 100_00);

    assertEq(treasurySpoke.getSuppliedShares(address(hub1), reserveId), 0);

    // create debt
    address tempUser = _openDebtPosition(spoke1, reserveId, amount, true);

    skip(skipTime);

    uint256 fees = treasurySpoke.getSuppliedAmount(address(hub1), assetId);

    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      hub1.getAssetTotalOwed(assetId) - amount,
      3,
      'treasury spoke supplied amount on hub'
    );
    assertApproxEqAbs(
      fees,
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      3,
      'treasury spoke supplied amount on spoke'
    );

    if (fees > 0) {
      IERC20 asset = getAssetUnderlyingByReserveId(spoke1, reserveId);
      uint256 balanceBefore = asset.balanceOf(TREASURY_ADMIN);

      deal(address(asset), tempUser, UINT256_MAX);
      Utils.repay(spoke1, reserveId, tempUser, UINT256_MAX, tempUser);
      vm.prank(TREASURY_ADMIN);
      treasurySpoke.withdraw(address(hub1), assetId, fees, TREASURY_ADMIN);

      assertEq(balanceBefore + fees, asset.balanceOf(TREASURY_ADMIN), 'Treasury admin balance');
      assertEq(
        0,
        hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
        'treasury spoke remaining supplied amount'
      );
    }
  }

  function test_getters() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = daiAssetId;
    uint256 amount = 10_000e18;
    uint256 skipTime = 322 days;

    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, 100_00);

    // create debt
    _openDebtPosition(spoke1, reserveId, amount, true);

    skip(skipTime);

    uint256 fees = treasurySpoke.getSuppliedAmount(address(hub1), assetId);

    assertApproxEqAbs(
      treasurySpoke.getSuppliedAmount(address(hub1), reserveId),
      fees,
      1,
      'reserve supplied assets'
    );
    assertApproxEqAbs(
      treasurySpoke.getSuppliedShares(address(hub1), reserveId),
      hub1.previewAddByAssets(assetId, fees),
      1,
      'reserve supplied shares'
    );
  }

  function _treasurySpoke() internal view returns (ISpoke) {
    return ISpoke(address(treasurySpoke));
  }
}
