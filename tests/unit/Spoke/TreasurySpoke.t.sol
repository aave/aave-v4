// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract TreasurySpokeTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using WadRayMath for uint256;

  function test_initial_state() public view {
    assertEq(address(treasurySpoke.HUB()), address(hub));
    for (uint256 i; i < hub.getAssetCount(); ++i) {
      assertEq(treasurySpoke.getSuppliedAmount(i), 0);
      assertEq(treasurySpoke.getSuppliedShares(i), 0);
    }
  }

  function test_supply_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.supply(daiAssetId, 1);
  }

  function test_withdraw_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);

    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    vm.prank(caller);
    treasurySpoke.withdraw(daiAssetId, 1, address(1));
  }

  function test_supply(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);
    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));

    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);
  }

  /// treasury supplies to earn interest
  function test_withdraw_fuzz_amount_interestOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    updateLiquidityFee(hub, daiAssetId, 0);

    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));
    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, daiAssetId), 100e18, true);

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

  /// treasury does not supply but earn fees
  function test_withdraw_fuzz_amount_feesOnly(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    assertEq(treasurySpoke.getSuppliedShares(daiAssetId), 0);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, daiAssetId), 100e18, true);

    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(daiAssetId), 0);
    uint256 fees = treasurySpoke.getSuppliedAmount(daiAssetId);

    Utils.withdraw(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, fees, address(treasurySpoke));
  }

  /// treasury supplies to earn interest and fees
  function test_withdraw_fuzz_amount_interestAndFees(uint256 amount) public {
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    Utils.supply(_treasurySpoke(), daiAssetId, TREASURY_ADMIN, amount, address(treasurySpoke));
    assertEq(treasurySpoke.getSuppliedAmount(daiAssetId), amount);

    uint256 suppliedSharesBefore = treasurySpoke.getSuppliedShares(daiAssetId);
    uint256 suppliedAssetsBefore = treasurySpoke.getSuppliedAmount(daiAssetId);

    // create debt
    _openDebtPosition(spoke1, getReserveIdByAssetId(spoke1, daiAssetId), 100e18, true);

    skip(365 days);

    assertGe(treasurySpoke.getSuppliedShares(daiAssetId), suppliedSharesBefore);
    uint256 interestAndFees = treasurySpoke.getSuppliedAmount(daiAssetId) - suppliedAssetsBefore;

    Utils.withdraw(
      _treasurySpoke(),
      daiAssetId,
      TREASURY_ADMIN,
      amount + interestAndFees,
      address(treasurySpoke)
    );
  }

  function _treasurySpoke() internal view returns (ISpoke) {
    return ISpoke(address(treasurySpoke));
  }

  // todo: test that supplying from treasury does not create any issue. existing fees are added to the supply amount
  // todo: add test for 100% liquidity fee
}
