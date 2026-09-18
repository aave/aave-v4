// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

/// @notice PoC for https://github.com/aave/aave-v4/issues/853.
/// @dev `AssetLogic.getDrawnIndex` compounds `MathUtils.calculateLinearInterest` on every
///      `accrue()` call. Splitting a fixed elapsed period into more permissionlessly-triggered
///      accruals therefore yields a strictly larger drawn (debt) index than a single accrual
///      over the same period at the same nominal annual rate, i.e. realized debt is not
///      invariant to accrual frequency.
contract HubAccrueInterestFrequencyInvarianceTest is Base {
  /// @dev Comfortably above the rounding-to-zero-shares threshold even after the exchange rate
  ///      has moved by several orders of magnitude over the course of the simulated accruals,
  ///      while remaining negligible next to the pool's supplied/borrowed amounts.
  uint256 internal constant POKE_AMOUNT = 1e18;

  address internal poker;

  function setUp() public override {
    super.setUp();
    spokeMintAndApprove();
    poker = address(spoke2);
  }

  /// @dev Pins the drawn rate so the effect isn't confounded by utilization-driven rate changes,
  ///      then caches it onto the asset so both branches start from the same `drawnRate`.
  function _fixDrawnRateAndCache(uint256 rateBps) internal {
    _mockDrawnRateBps(address(irStrategy), rateBps);
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: poker,
      amount: POKE_AMOUNT,
      user: poker
    });
  }

  /// @dev Splits `totalElapsed` into `accrualCount` equal steps, forcing a real `accrue()` at
  ///      the end of each step via a dust-sized `add()`, and returns the resulting drawn debt.
  function _debtAfterForcedAccruals(
    uint256 totalElapsed,
    uint256 accrualCount
  ) internal returns (uint256) {
    uint256 stepElapsed = totalElapsed / accrualCount;
    for (uint256 i = 0; i < accrualCount; ++i) {
      skip(stepElapsed);
      HubActions.add({
        hub: hub1,
        assetId: daiAssetId,
        caller: poker,
        amount: POKE_AMOUNT,
        user: poker
      });
    }
    return _getAssetDrawnDebt(hub1, daiAssetId);
  }

  /// @notice At the protocol's own configured rate ceiling (`MAX_ALLOWED_DRAWN_RATE`, 1000% APR),
  ///         ~180 forced accruals over a year (less than one every two days, well within reach of
  ///         a single unprivileged account paying ordinary gas) inflate the debt to roughly 1500x
  ///         what a single accrual over the same wall-clock year produces, for the same nominal
  ///         annual rate. Nothing here requires per-second or per-block spamming.
  function test_accrueInterest_HighFrequencyForcedAccrual_InflatesDebt_AtMaxRate() public {
    uint256 addAmount = 1_000_000e18;
    uint256 borrowAmount = 500_000e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    _fixDrawnRateAndCache(MAX_ALLOWED_DRAWN_RATE);

    uint256 baseline = vm.snapshotState();

    uint256 debtSingleAccrual = _debtAfterForcedAccruals(365 days, 1);
    vm.revertToState(baseline);

    uint256 debtManyAccruals = _debtAfterForcedAccruals(365 days, 180);
    vm.revertToState(baseline);

    assertGt(
      debtManyAccruals,
      debtSingleAccrual,
      'forced high-frequency accrual must not exceed single-shot accrual for the same elapsed time and nominal rate'
    );
    // Theoretical continuous-compounding limit at 1000% APR is e^10 / 11 =~ 2003x the single-shot
    // debt; 180 discrete forced accruals already realize the large majority of that gap.
    assertGt(
      debtManyAccruals,
      debtSingleAccrual * 1000,
      'expected forced accrual to realize most of the theoretical compounding blow-up'
    );
  }

  /// @notice Same mechanism at a realistic stress-market rate (80% APR, well below the protocol's
  ///         configured ceiling) still yields a clear, non-negligible inflation: ~180 forced
  ///         accruals over a year already land within a rounding error of the theoretical
  ///         continuous-compounding limit (e^0.8 / 1.8 =~ 1.24x the single-shot debt).
  function test_accrueInterest_HighFrequencyForcedAccrual_InflatesDebt_AtRealisticRate() public {
    uint256 realisticRateBps = 80_00; // 80.00% APR
    uint256 addAmount = 1_000_000e18;
    uint256 borrowAmount = 500_000e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    _fixDrawnRateAndCache(realisticRateBps);

    uint256 baseline = vm.snapshotState();

    uint256 debtSingleAccrual = _debtAfterForcedAccruals(365 days, 1);
    vm.revertToState(baseline);

    uint256 debtManyAccruals = _debtAfterForcedAccruals(365 days, 180);
    vm.revertToState(baseline);

    assertGt(
      debtManyAccruals,
      debtSingleAccrual,
      'forced high-frequency accrual must not exceed single-shot accrual for the same elapsed time and nominal rate'
    );
    // 1.20x is a conservative lower bound; the closed-form limit is ~1.2364x.
    assertGt(
      debtManyAccruals,
      (debtSingleAccrual * 120) / 100,
      'expected a clear, non-negligible inflation even at a realistic (non-ceiling) rate'
    );
  }

  /// @notice Monotonicity: for a fixed elapsed period and rate, forcing more accruals never
  ///         produces less debt than forcing fewer. This is the property that a sound debt index
  ///         should violate in the *other* direction only up to rounding, not structurally.
  function test_accrueInterest_fuzz_DebtIsMonotonicInForcedAccrualCount(
    uint8 fewerAccrualsSeed,
    uint8 moreAccrualsExtraSeed
  ) public {
    uint256 fewerAccruals = bound(fewerAccrualsSeed, 1, 60);
    uint256 moreAccruals = fewerAccruals + bound(moreAccrualsExtraSeed, 1, 60);

    uint256 addAmount = 1_000_000e18;
    uint256 borrowAmount = 500_000e18;

    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: addAmount,
      user: address(spoke1)
    });
    HubActions.draw({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      to: address(spoke1),
      amount: borrowAmount
    });

    _fixDrawnRateAndCache(MAX_ALLOWED_DRAWN_RATE);

    uint256 baseline = vm.snapshotState();

    uint256 debtFewer = _debtAfterForcedAccruals(360 days, fewerAccruals);
    vm.revertToState(baseline);

    uint256 debtMore = _debtAfterForcedAccruals(360 days, moreAccruals);
    vm.revertToState(baseline);

    assertGe(
      debtMore,
      debtFewer,
      'debt for the same elapsed time and rate must not decrease when accrual is forced more often'
    );
  }
}
