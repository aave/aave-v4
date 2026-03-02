// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TreasurySpokeTest is SpokeBase {
  MockERC20 internal _testToken;

  function setUp() public virtual override {
    super.setUp();
    _testToken = new MockERC20();

    // Register treasurySpoke as a spoke for all hub1 assets so it can call hub1.add/remove
    vm.startPrank(ADMIN);
    uint256 assetCount = hub1.getAssetCount();
    for (uint256 i = 0; i < assetCount; ++i) {
      hub1.addSpoke(
        i,
        address(treasurySpoke),
        IHub.SpokeConfig({
          active: true,
          halted: false,
          addCap: type(uint40).max,
          drawCap: type(uint40).max,
          riskPremiumThreshold: 0
        })
      );
    }
    vm.stopPrank();
  }

  function test_deploy_reverts_on_invalid_params() public {
    vm.expectRevert(ISpoke.InvalidAddress.selector);
    new TreasurySpoke(vm.randomAddress(), address(0));

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
    new TreasurySpoke(address(0), vm.randomAddress());
  }

  function test_initial_state() public view {
    assertEq(address(treasurySpoke.HUB()), address(hub1));
    for (uint256 i; i < hub1.getAssetCount(); ++i) {
      assertEq(treasurySpoke.getSuppliedAmount(i), 0);
      assertEq(treasurySpoke.getSuppliedShares(i), 0);
    }
    assertEq(Ownable2Step(address(treasurySpoke)).owner(), TREASURY_ADMIN);
    assertEq(Ownable2Step(address(treasurySpoke)).pendingOwner(), address(0));
  }

  function test_supply_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.supply(daiAssetId, 1, caller);
  }

  function test_withdraw_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.withdraw(daiAssetId, 1, vm.randomAddress());
  }

  function test_supply(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));

    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);
  }

  /// treasury supplies to earn interest
  function test_withdraw_fuzz_amount_interestOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateLiquidityFee(hub1, daiAssetId, 0);

    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));
    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    assertEq(suppliedSharesBefore, treasurySpoke.getSuppliedShares(daiAssetId));
    uint256 interest = treasurySpoke.getSuppliedAmount(daiAssetId) - suppliedAssetsBefore;
    vm.assume(interest > 0); // assume only cases where the initial amount generates interest

    Utils.withdraw(
      _treasurySpoke(),
      daiAssetId,
      TREASURY_ADMIN,
      amount + interest,
      address(treasurySpoke)
    );
  }

  /// treasury does not supply but fees accumulate in realizedFees (tokenizedSpoke is address(0))
  function test_withdraw_fuzz_amount_feesOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    assertEq(treasurySpoke.getSuppliedShares(daiAssetId), 0);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);
    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0, 'fees not yet accrued');

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub1, daiAssetId);
    assertGt(expectedFeeAmount, 0, 'should have unrealized fees');

    // mintFeeShares is a no-op when tokenizedSpoke == address(0)
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // fees accumulate in realizedFees now (not in treasurySpoke)
    assertGt(hub1.getAsset(daiAssetId).realizedFees, 0, 'realized fees should be non-zero');
    // TreasurySpoke still has no shares (fees did NOT auto-flow to it)
    assertEq(treasurySpoke.getSuppliedShares(daiAssetId), 0, 'treasury spoke has no shares');
  }

  /// treasury supplies to earn interest (no fees since tokenizedSpoke is address(0))
  function test_withdraw_fuzz_amount_interestAndFees(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));
    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, hub1, daiAssetId), 100e18, true);

    skip(365 days);

    // TreasurySpoke only earns interest (shares unchanged), not auto-minted fees
    assertGe(treasurySpoke.getSuppliedShares(daiAssetId), suppliedSharesBefore);
    uint256 interest = treasurySpoke.getSuppliedAmount(daiAssetId) - suppliedAssetsBefore;
    vm.assume(interest > 0);

    Utils.withdraw(
      _treasurySpoke(),
      daiAssetId,
      TREASURY_ADMIN,
      amount + interest,
      address(treasurySpoke)
    );
  }

  function test_transfer_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.transfer(vm.randomAddress(), vm.randomAddress(), 1);
  }

  function test_transfer_revertsWith_ERC20InsufficientBalance(uint256 amount) public {
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
    amount = bound(amount, 1, type(uint120).max);
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

  /// @dev With max liquidity fee and no tokenizedSpoke, fees accumulate in realizedFees.
  /// TreasurySpoke does not automatically receive fees.
  function test_withdraw_fuzz_maxLiquidityFee(
    uint256 reserveId,
    uint256 amount,
    uint256 skipTime
  ) public {
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    amount = bound(amount, 1, _calculateMaxSupplyAmount(spoke1, reserveId));
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, 100_00);

    assertEq(treasurySpoke.getSuppliedShares(reserveId), 0);

    // create debt
    _openDebtPosition(spoke1, reserveId, amount, true);

    skip(skipTime);
    assertEq(hub1.getAsset(assetId).realizedFees, 0, 'fees not yet accrued'); // fees not yet accrued

    uint256 expectedFeeAmount = _calcUnrealizedFees(hub1, assetId);

    // mintFeeShares is a no-op when tokenizedSpoke == address(0); fees go to realizedFees
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    // Fees accumulate in realizedFees, NOT in treasurySpoke
    assertApproxEqAbs(
      hub1.getAsset(assetId).realizedFees,
      expectedFeeAmount,
      1,
      'fees in realizedFees'
    );
    // TreasurySpoke has no shares (fees did NOT auto-flow to it)
    assertEq(hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)), 0, 'treasury spoke has no supplied amount');
  }

  function test_borrow_revertsWith_UnsupportedAction() public {
    vm.expectRevert(ITreasurySpoke.UnsupportedAction.selector);
    treasurySpoke.borrow(vm.randomUint(), vm.randomUint(), vm.randomAddress());
  }

  function test_repay_revertsWith_UnsupportedAction() public {
    vm.expectRevert(ITreasurySpoke.UnsupportedAction.selector);
    treasurySpoke.repay(vm.randomUint(), vm.randomUint(), vm.randomAddress());
  }

  function test_liquidationCall_revertsWith_UnsupportedAction() public {
    vm.expectRevert(ITreasurySpoke.UnsupportedAction.selector);
    treasurySpoke.liquidationCall(
      vm.randomUint(),
      vm.randomUint(),
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomBool()
    );
  }

  function test_getters() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = daiAssetId;
    uint256 amount = 10_000e18;

    (uint256 drawn, uint256 premium) = treasurySpoke.getUserDebt(reserveId, alice);
    assertEq(drawn, 0);
    assertEq(premium, 0);
    assertEq(treasurySpoke.getUserTotalDebt(reserveId, alice), 0);
    assertEq(treasurySpoke.getUserPremiumDebtRay(reserveId, alice), 0);

    // TreasurySpoke starts with no supplied assets
    assertEq(treasurySpoke.getSuppliedAmount(assetId), 0, 'initial supplied amount');
    assertEq(treasurySpoke.getReserveSuppliedAssets(reserveId), 0, 'initial reserve supplied assets');
    assertEq(treasurySpoke.getReserveSuppliedShares(reserveId), 0, 'initial reserve supplied shares');

    // Supply manually through TreasurySpoke
    Utils.supply(_treasurySpoke(), assetId, TREASURY_ADMIN, amount, address(treasurySpoke));
    assertEq(treasurySpoke.getSuppliedAmount(assetId), amount, 'supplied amount after supply');

    assertApproxEqAbs(
      treasurySpoke.getReserveSuppliedAssets(reserveId),
      amount,
      1,
      'reserve supplied assets after supply'
    );
    assertGt(
      treasurySpoke.getReserveSuppliedShares(reserveId),
      0,
      'reserve supplied shares after supply'
    );

    assertEq(treasurySpoke.getUserSuppliedAssets(reserveId, alice), 0);
    assertEq(treasurySpoke.getUserSuppliedShares(reserveId, alice), 0);
    (drawn, premium) = treasurySpoke.getReserveDebt(reserveId);
    assertEq(drawn, 0);
    assertEq(premium, 0);
    assertEq(treasurySpoke.getReserveTotalDebt(reserveId), 0);
  }

  function _treasurySpoke() internal view returns (ISpoke) {
    return ISpoke(address(treasurySpoke));
  }
}
