// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/libraries/babylon-liquidation-logic/BabylonLiquidationLogic.Base.t.sol';

contract BabylonLiquidationLogicLiquidationAmountsTest is BabylonLiquidationLogicBaseTest {
  using MathUtils for uint256;
  using WadRayMath for uint256;

  // supply share price is 1.25, collateral is $1 with 6 decimals, debt is $2000 with 18 decimals,
  // drawn index is 1.6, liquidation bonus is 120%
  // user debt: 3 drawn shares * 1.6 + 0.5 premium = 5.3
  IHub public collateralReserveHub;
  uint256 public collateralAssetId;

  function setUp() public override {
    super.setUp();
    collateralReserveHub = hub1;
    collateralAssetId = usdxAssetId;
  }

  function test_calculateLiquidationAmounts_fuzz_CapNotEnforced(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    BabylonLiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    params.maxRemovableShares = bound(
      params.maxRemovableShares,
      expectedLiquidationAmounts.collateralSharesToLiquidate,
      UINT256_MAX
    );

    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        params
      );

    assertEq(liquidationAmounts, expectedLiquidationAmounts);
    _assertSizingInvariants(params, liquidationAmounts);
  }

  function test_calculateLiquidationAmounts_fuzz_CapEnforced(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    BabylonLiquidationLogic.LiquidationAmounts
      memory rawLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    vm.assume(rawLiquidationAmounts.collateralSharesToLiquidate > 0);
    params.maxRemovableShares = bound(
      params.maxRemovableShares,
      0,
      rawLiquidationAmounts.collateralSharesToLiquidate - 1
    );
    BabylonLiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateCappedLiquidationAmounts(params);

    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        params
      );

    assertEq(liquidationAmounts, expectedLiquidationAmounts);
    _assertSizingInvariants(params, liquidationAmounts);
  }

  /// @dev A zero cap removes no collateral; the repayment is resized to zero whenever the priced
  /// removal was positive, and kept otherwise so debt can still be repaid against no collateral.
  function test_calculateLiquidationAmounts_fuzz_ZeroCap(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params
  ) public {
    params = _bound(params);
    params.maxRemovableShares = 0;
    BabylonLiquidationLogic.LiquidationAmounts
      memory expectedLiquidationAmounts = _calculateRawLiquidationAmounts(params);
    if (expectedLiquidationAmounts.collateralSharesToLiquidate > 0) {
      expectedLiquidationAmounts = BabylonLiquidationLogic.LiquidationAmounts(0, 0, 0);
    }

    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        params
      );

    assertEq(liquidationAmounts, expectedLiquidationAmounts);
  }

  function test_calculateLiquidationAmounts_PremiumOnly() public {
    _mockFixedSharePrice();
    // debtToCover 0.3 < premium 0.5: premium repaid partially, no drawn debt touched
    // collateral to liquidate = 0.3 * 120% * $2000 / $1 = 720 -> 720 / 1.25 = 576 shares
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 0.3e18, maxRemovableShares: UINT256_MAX})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 576e6,
        drawnSharesToLiquidate: 0,
        premiumDebtRayToLiquidate: 0.3e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_PremiumAndDrawn() public {
    _mockFixedSharePrice();
    // debtToCover 2.1: premium 0.5 fully repaid, drawn shares = (2.1 - 0.5) / 1.6 = 1
    // collateral to liquidate = 2.1 * 120% * $2000 / $1 = 5040 -> 4032 shares
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 2.1e18, maxRemovableShares: UINT256_MAX})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 4032e6,
        drawnSharesToLiquidate: 1e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_FullDebt() public {
    _mockFixedSharePrice();
    // debtToCover 10 > debt 5.3: the whole position is repaid, drawn shares clamp at 3
    // collateral to liquidate = 5.3 * 120% * $2000 / $1 = 12720 -> 10176 shares
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 10e18, maxRemovableShares: UINT256_MAX})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 10176e6,
        drawnSharesToLiquidate: 3e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_CapEnforced() public {
    _mockFixedSharePrice();
    // unbounded removal for a 2.1 cover is 4032 shares; the cap is half of it
    // repayment = 2016 shares * 1.25 * $1 / (120% * $2000) = 1.05
    // premium 0.5 repaid first, drawn shares = (1.05 - 0.5) / 1.6 = 0.34375
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 2.1e18, maxRemovableShares: 2016e6})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 2016e6,
        drawnSharesToLiquidate: 0.34375e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  /// @dev A cap equal to the priced removal is not enforced: the unbounded sizing stands.
  function test_calculateLiquidationAmounts_CapEqualsUnboundedRemoval() public {
    _mockFixedSharePrice();
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 2.1e18, maxRemovableShares: 4032e6})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 4032e6,
        drawnSharesToLiquidate: 1e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_CapEnforced_PremiumOnly() public {
    _mockFixedSharePrice();
    // the cap prices to 240 shares * 1.25 * $1 / (120% * $2000) = 0.125 < premium 0.5
    // only premium is repaid, no drawn debt touched
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 2.1e18, maxRemovableShares: 240e6})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 240e6,
        drawnSharesToLiquidate: 0,
        premiumDebtRayToLiquidate: 0.125e18 * 1e27
      })
    );
  }

  /// @dev A repayment whose priced removal floors to zero shares is still sized: debt is repaid
  /// against no collateral.
  function test_calculateLiquidationAmounts_ZeroCollateral() public {
    _mockFixedSharePrice();
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 1, maxRemovableShares: UINT256_MAX})
      );

    assertEq(
      liquidationAmounts,
      BabylonLiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 0,
        drawnSharesToLiquidate: 0,
        premiumDebtRayToLiquidate: 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_ZeroCap() public {
    _mockFixedSharePrice();
    // the priced removal is positive, so the cap resizes the repayment to zero
    BabylonLiquidationLogic.LiquidationAmounts
      memory liquidationAmounts = babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
        _getParams({debtToCover: 2.1e18, maxRemovableShares: 0})
      );

    assertEq(liquidationAmounts, BabylonLiquidationLogic.LiquidationAmounts(0, 0, 0));
  }

  /// @dev The 1.25 supply share price the hand-derived cases are computed with.
  function _mockFixedSharePrice() internal {
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });
  }

  /// @dev Rules that hold for every sizing: the cap is never exceeded, premium debt goes first,
  /// and the repayment stays within the user's debt.
  function _assertSizingInvariants(
    BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory params,
    BabylonLiquidationLogic.LiquidationAmounts memory liquidationAmounts
  ) internal pure {
    assertLe(
      liquidationAmounts.collateralSharesToLiquidate,
      params.maxRemovableShares,
      'invariant: cap exceeded'
    );
    assertLe(
      liquidationAmounts.premiumDebtRayToLiquidate,
      params.premiumDebtRay,
      'invariant: premium exceeded'
    );
    assertLe(
      liquidationAmounts.drawnSharesToLiquidate,
      params.drawnShares,
      'invariant: drawn shares exceeded'
    );
    if (liquidationAmounts.drawnSharesToLiquidate > 0) {
      assertEq(
        liquidationAmounts.premiumDebtRayToLiquidate,
        params.premiumDebtRay,
        'invariant: drawn debt repaid before the premium is cleared'
      );
    }
  }

  function _getParams(
    uint256 debtToCover,
    uint256 maxRemovableShares
  ) internal view returns (BabylonLiquidationLogic.CalculateLiquidationAmountsParams memory) {
    return
      BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
        collateralReserveHub: collateralReserveHub,
        collateralReserveAssetId: collateralAssetId,
        collateralAssetUnit: 1e6,
        collateralAssetPrice: 1e8,
        drawnShares: 3e18,
        premiumDebtRay: 0.5e18 * 1e27,
        drawnIndex: 1.6e27,
        debtAssetUnit: 1e18,
        debtAssetPrice: 2000e8,
        liquidationBonus: 120_00,
        debtToCover: debtToCover,
        maxRemovableShares: maxRemovableShares
      });
  }
}
