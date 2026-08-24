// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/contracts/spoke/libraries/liquidation-logic/LiquidationLogic.Base.t.sol';
import {BabylonLiquidationLogic} from 'src/spoke/libraries/BabylonLiquidationLogic.sol';
import {BabylonLiquidationLogicWrapper} from 'tests/helpers/mocks/BabylonLiquidationLogicWrapper.sol';

contract BabylonLiquidationLogicLiquidationAmountsTest is LiquidationLogicBaseTest {
  BabylonLiquidationLogicWrapper internal babylonLiquidationLogicWrapper;

  function setUp() public virtual override {
    super.setUp();
    babylonLiquidationLogicWrapper = new BabylonLiquidationLogicWrapper();
  }

  function test_calculateLiquidationAmounts_neutralOverrides_matchesCanonical() public {
    // with no cap, the default dust threshold and no bypass, sizing matches the canonical logic
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    LiquidationLogic.LiquidationAmounts memory canonicalAmounts = liquidationLogicWrapper
      .calculateLiquidationAmounts(
        LiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    LiquidationLogic.LiquidationAmounts memory babylonAmounts = babylonLiquidationLogicWrapper
      .calculateLiquidationAmounts(
        BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          overrides: BabylonLiquidationLogic.LiquidationOverrides({
            maxCollateralToRemove: type(uint256).max,
            dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
            bypassTargetHealthFactor: false
          }),
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    _assertLiquidationAmountsEq(babylonAmounts, canonicalAmounts);
  }

  function test_calculateLiquidationAmounts_MaxCollateralToRemove_capBinds() public {
    // uncapped sizing seizes 4800 collateral shares (see the canonical EnoughCollateral test)
    // cap: 3000 assets = 2400 shares, binds
    // resized debt to liquidate = 3000 * $1 / 120% / $2000 = 1.25
    // premiumDebtRayToLiquidate = 0.5
    // drawnSharesToLiquidate = (1.25 - 0.5) / 1.6 = 0.46875
    // bonus collateral shares = 2400 - 2400 / 120% = 400
    // collateral fee shares = 400 * 10% = 40
    // collateral shares to liquidator = 2400 - 40 = 2360
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = babylonLiquidationLogicWrapper
      .calculateLiquidationAmounts(
        BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          overrides: BabylonLiquidationLogic.LiquidationOverrides({
            maxCollateralToRemove: 3000e6,
            dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
            bypassTargetHealthFactor: false
          }),
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    _assertLiquidationAmountsEq(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 2400e6,
        collateralSharesToLiquidator: 2360e6,
        drawnSharesToLiquidate: 0.46875e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_MaxCollateralToRemove_capBindsWithinPremium() public {
    // cap: 600 assets = 480 shares, binds
    // resized debt to liquidate = 600 * $1 / 120% / $2000 = 0.25, below the 0.5 premium
    // premiumDebtRayToLiquidate = 0.25
    // drawnSharesToLiquidate = 0
    // bonus collateral shares = 480 - 480 / 120% = 80
    // collateral fee shares = 80 * 10% = 8
    // collateral shares to liquidator = 480 - 8 = 472
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = babylonLiquidationLogicWrapper
      .calculateLiquidationAmounts(
        BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          overrides: BabylonLiquidationLogic.LiquidationOverrides({
            maxCollateralToRemove: 600e6,
            dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
            bypassTargetHealthFactor: false
          }),
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    _assertLiquidationAmountsEq(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 480e6,
        collateralSharesToLiquidator: 472e6,
        drawnSharesToLiquidate: 0,
        premiumDebtRayToLiquidate: 0.25e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_MaxCollateralToRemove_revertsWith_MustNotLeaveDust()
    public
  {
    // supplied shares: 4500, cap: 5000 assets = 4000 shares, binds
    // remaining collateral = 500 shares = $625, below the dust threshold while debt remains
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
      BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
        collateralReserveHub: collateralReserveHub,
        collateralReserveAssetId: collateralAssetId,
        suppliedShares: 4500e6,
        collateralAssetDecimals: 6,
        collateralAssetPrice: 1e8,
        drawnShares: 3e18,
        premiumDebtRay: 0.5e18 * 1e27,
        drawnIndex: 1.6e27,
        totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
        debtAssetDecimals: 18,
        debtAssetPrice: 2000e8,
        debtToCover: 3e18,
        overrides: BabylonLiquidationLogic.LiquidationOverrides({
          maxCollateralToRemove: 5000e6,
          dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          bypassTargetHealthFactor: false
        }),
        collateralFactor: 50_00,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00,
        maxLiquidationBonus: 120_00,
        targetHealthFactor: 1e18,
        healthFactor: 0.8e18,
        liquidationFee: 10_00
      })
    );
  }

  function test_calculateLiquidationAmounts_BypassTargetHealthFactor() public {
    // target health factor sizing is bypassed: debt to liquidate = min(3, 3 * 1.6 + 0.5) = 3
    // premiumDebtRayToLiquidate = 0.5
    // drawnSharesToLiquidate = (3 - 0.5) / 1.6 = 1.5625
    // collateral to liquidate = 3 * 120% * $2000 / $1 = 7200
    // collateral shares to liquidate = 7200 / 1.25 = 5760
    // bonus collateral shares = 5760 - 5760 / 120% = 960
    // collateral fee shares = 960 * 10% = 96
    // collateral shares to liquidator = 5760 - 96 = 5664
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = babylonLiquidationLogicWrapper
      .calculateLiquidationAmounts(
        BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 3e18,
          overrides: BabylonLiquidationLogic.LiquidationOverrides({
            maxCollateralToRemove: type(uint256).max,
            dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
            bypassTargetHealthFactor: true
          }),
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    _assertLiquidationAmountsEq(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 5760e6,
        collateralSharesToLiquidator: 5664e6,
        drawnSharesToLiquidate: 1.5625e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_ZeroDustThreshold_allowsDebtDust() public {
    // bypassing target health factor, debtToCover 5 leaves 0.3 units of debt ($600):
    // below the default dust threshold, allowed with a zero threshold
    // premiumDebtRayToLiquidate = 0.5
    // drawnSharesToLiquidate = (5 - 0.5) / 1.6 = 2.8125
    // collateral to liquidate = 5 * 120% * $2000 / $1 = 12000
    // collateral shares to liquidate = 12000 / 1.25 = 9600
    // bonus collateral shares = 9600 - 9600 / 120% = 1600
    // collateral fee shares = 1600 * 10% = 160
    // collateral shares to liquidator = 9600 - 160 = 9440
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    LiquidationLogic.LiquidationAmounts memory liquidationAmounts = babylonLiquidationLogicWrapper
      .calculateLiquidationAmounts(
        BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
          collateralReserveHub: collateralReserveHub,
          collateralReserveAssetId: collateralAssetId,
          suppliedShares: 10_000e6,
          collateralAssetDecimals: 6,
          collateralAssetPrice: 1e8,
          drawnShares: 3e18,
          premiumDebtRay: 0.5e18 * 1e27,
          drawnIndex: 1.6e27,
          totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
          debtAssetDecimals: 18,
          debtAssetPrice: 2000e8,
          debtToCover: 5e18,
          overrides: BabylonLiquidationLogic.LiquidationOverrides({
            maxCollateralToRemove: type(uint256).max,
            dustThreshold: 0,
            bypassTargetHealthFactor: true
          }),
          collateralFactor: 50_00,
          healthFactorForMaxBonus: 0.8e18,
          liquidationBonusFactor: 50_00,
          maxLiquidationBonus: 120_00,
          targetHealthFactor: 1e18,
          healthFactor: 0.8e18,
          liquidationFee: 10_00
        })
      );

    _assertLiquidationAmountsEq(
      liquidationAmounts,
      LiquidationLogic.LiquidationAmounts({
        collateralSharesToLiquidate: 9600e6,
        collateralSharesToLiquidator: 9440e6,
        drawnSharesToLiquidate: 2.8125e18,
        premiumDebtRayToLiquidate: 0.5e18 * 1e27
      })
    );
  }

  function test_calculateLiquidationAmounts_DefaultDustThreshold_revertsOnDebtDust() public {
    // same inputs as test_calculateLiquidationAmounts_ZeroDustThreshold_allowsDebtDust with the
    // default dust threshold: the remaining $600 of debt forces a full repayment above debtToCover
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
      BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
        collateralReserveHub: collateralReserveHub,
        collateralReserveAssetId: collateralAssetId,
        suppliedShares: 10_000e6,
        collateralAssetDecimals: 6,
        collateralAssetPrice: 1e8,
        drawnShares: 3e18,
        premiumDebtRay: 0.5e18 * 1e27,
        drawnIndex: 1.6e27,
        totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
        debtAssetDecimals: 18,
        debtAssetPrice: 2000e8,
        debtToCover: 5e18,
        overrides: BabylonLiquidationLogic.LiquidationOverrides({
          maxCollateralToRemove: type(uint256).max,
          dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          bypassTargetHealthFactor: true
        }),
        collateralFactor: 50_00,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00,
        maxLiquidationBonus: 120_00,
        targetHealthFactor: 1e18,
        healthFactor: 0.8e18,
        liquidationFee: 10_00
      })
    );
  }

  function test_calculateLiquidationAmounts_MaxCollateralToRemove_dustBumpExceedsCap_reverts()
    public
  {
    // bypassing target health factor, debtToCover 5 leaves dust debt, bumping the repayment to
    // the full 5.3 units of debt; the corresponding seizure (5.3 * 120% * $2000 / $1 = 12720
    // assets) exceeds the 12000 asset cap, so the capped repayment leaves dust debt again and
    // must revert
    IHub collateralReserveHub = hub1;
    uint256 collateralAssetId = vm.randomUint(0, collateralReserveHub.getAssetCount() - 1);
    _mockSupplySharePrice({
      hub: collateralReserveHub,
      assetId: collateralAssetId,
      totalAddedAssets: 12_500.25e6,
      addedShares: 10_000e6,
      spoke: address(spoke1)
    });

    vm.expectRevert(ISpoke.MustNotLeaveDust.selector);
    babylonLiquidationLogicWrapper.calculateLiquidationAmounts(
      BabylonLiquidationLogic.CalculateLiquidationAmountsParams({
        collateralReserveHub: collateralReserveHub,
        collateralReserveAssetId: collateralAssetId,
        suppliedShares: 15_000e6,
        collateralAssetDecimals: 6,
        collateralAssetPrice: 1e8,
        drawnShares: 3e18,
        premiumDebtRay: 0.5e18 * 1e27,
        drawnIndex: 1.6e27,
        totalDebtValueRay: 10_000e26 * WadRayMath.RAY,
        debtAssetDecimals: 18,
        debtAssetPrice: 2000e8,
        debtToCover: 5e18,
        overrides: BabylonLiquidationLogic.LiquidationOverrides({
          maxCollateralToRemove: 12_000e6,
          dustThreshold: LiquidationLogic.DUST_LIQUIDATION_THRESHOLD,
          bypassTargetHealthFactor: true
        }),
        collateralFactor: 50_00,
        healthFactorForMaxBonus: 0.8e18,
        liquidationBonusFactor: 50_00,
        maxLiquidationBonus: 120_00,
        targetHealthFactor: 1e18,
        healthFactor: 0.8e18,
        liquidationFee: 10_00
      })
    );
  }

  function _assertLiquidationAmountsEq(
    LiquidationLogic.LiquidationAmounts memory a,
    LiquidationLogic.LiquidationAmounts memory b
  ) internal pure {
    assertEq(
      a.collateralSharesToLiquidate,
      b.collateralSharesToLiquidate,
      'collateralSharesToLiquidate'
    );
    assertApproxEqAbs(
      a.collateralSharesToLiquidator,
      b.collateralSharesToLiquidator,
      1,
      'collateralSharesToLiquidator'
    );
    assertEq(a.drawnSharesToLiquidate, b.drawnSharesToLiquidate, 'drawnSharesToLiquidate');
    assertEq(a.premiumDebtRayToLiquidate, b.premiumDebtRayToLiquidate, 'premiumDebtRayToLiquidate');
  }
}
