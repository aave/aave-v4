// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';
import {MockERC20} from 'tests/mocks/MockERC20.sol';
import {IERC20Errors} from 'src/dependencies/openzeppelin/IERC20Errors.sol';

contract TreasurySpokeTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using WadRayMath for uint256;

  MockERC20 internal testToken;

  function setUp() public virtual override {
    super.setUp();
    testToken = new MockERC20();
  }

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

  function test_transfer_revertsWith_Unauthorized(address caller) public {
    vm.assume(caller != TREASURY_ADMIN);
    vm.prank(caller);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, caller));
    treasurySpoke.transfer(address(testToken), vm.randomAddress(), 1);
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

  function test_transfer_fuzz_all(address recipient, uint256 amount) public {
    vm.assume(recipient != address(0));
    vm.assume(recipient != address(treasurySpoke));
    amount = bound(amount, 1, 1000000e18);

    testToken.mint(address(treasurySpoke), amount);
    vm.expectEmit(address(testToken));
    emit IERC20.Transfer(address(treasurySpoke), recipient, amount);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.transfer(address(testToken), recipient, amount);

    assertEq(testToken.balanceOf(address(treasurySpoke)), 0);
    assertEq(testToken.balanceOf(recipient), amount);
  }

  function test_transfer_fuzz_partialAmount(address recipient, uint256 transferAmount) public {
    vm.assume(recipient != address(0));
    vm.assume(recipient != address(treasurySpoke));

    uint256 totalAmount = 1000e18;
    transferAmount = bound(transferAmount, 1, totalAmount - 1);

    testToken.mint(address(treasurySpoke), totalAmount);
    vm.expectEmit(address(testToken));
    emit IERC20.Transfer(address(treasurySpoke), recipient, transferAmount);
    vm.prank(TREASURY_ADMIN);
    treasurySpoke.transfer(address(testToken), recipient, transferAmount);

    assertEq(testToken.balanceOf(address(treasurySpoke)), totalAmount - transferAmount);
    assertEq(testToken.balanceOf(recipient), transferAmount);
  }

  // todo: test that supplying from treasury does not create any issue. existing fees are added to the supply amount
  // todo: add test for 100% liquidity fee
}
