// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/flashloan-spoke/FlashLoanSpoke.Base.t.sol';

contract FlashLoanSpokeRoundingTest is FlashLoanSpokeBaseTest {
  using WadRayMath for uint256;

  /// @dev Drawing `amount` then restoring its drawn shares costs `amount` plus less than `index / RAY + 1`,
  /// and costs exactly `amount` only when `amount * RAY` is a multiple of the index.
  function test_rounding_fuzz(uint256 amount, uint256 index) public pure {
    index = bound(index, WadRayMath.RAY, 10 * WadRayMath.RAY);
    amount = bound(amount, 1, 1e30);

    uint256 drawnShares = amount.rayDivUp(index);
    uint256 rounding = drawnShares.rayMulUp(index) - amount;

    assertLt(rounding * WadRayMath.RAY, index + WadRayMath.RAY);
    assertEq(rounding == 0, (amount * WadRayMath.RAY) % index == 0);
    if (index < 2 * WadRayMath.RAY) {
      assertLe(rounding, 2);
    }
  }

  /// @dev Restoring `amount` leaves at most one drawn share, and restoring the cost of any number of drawn
  /// shares clears exactly them.
  function test_dustShares_fuzz(uint256 amount, uint256 dustShares, uint256 index) public pure {
    index = bound(index, WadRayMath.RAY, 10 * WadRayMath.RAY);
    amount = bound(amount, 1, 1e30);
    dustShares = bound(dustShares, 1, 1e30);

    assertLe(amount.rayDivUp(index) - amount.rayDivDown(index), 1);
    assertEq(dustShares.rayMulUp(index).rayDivDown(index), dustShares);
  }

  /// @dev Without fee, the premium is exactly the Hub rounding at the current drawn index.
  function test_flashLoanSimple_noFee_premiumIsRounding_fuzz(
    uint256 amount,
    uint256 elapsed
  ) public {
    skip(bound(elapsed, 0, 10 * 365 days));
    amount = bound(amount, 1, hub1.getAssetLiquidity(daiAssetId));
    vm.prank(ADMIN);
    flashLoanSpoke.updateAssetConfig(dai, 0, true);

    uint256 index = hub1.getAssetDrawnIndex(daiAssetId);
    uint256 rounding = _rounding(daiAssetId, amount);
    assertLt(rounding * WadRayMath.RAY, index + WadRayMath.RAY);
    assertEq(rounding == 0, (amount * WadRayMath.RAY) % index == 0);
    uint256 receiverBefore = IERC20(dai).balanceOf(address(receiver));

    vm.prank(alice);
    flashLoanSpoke.flashLoanSimple(address(receiver), dai, amount, PARAMS);

    _assertNoPosition(daiAssetId);
    assertEq(IERC20(dai).balanceOf(address(receiver)), receiverBefore - rounding);
  }
}
