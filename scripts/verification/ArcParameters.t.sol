// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ArcParameters} from 'scripts/config/ArcParameters.sol';

import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {Test} from 'forge-std/Test.sol';

/// @title ArcParametersTest
/// @author Aave Labs
/// @notice Pins every value in `ArcParameters` to the ARFC tables, so a governance revision shows
///         up as a failing test rather than a silent drift, and checks each one against the
///         validation the Hub and Spoke apply.
contract ArcParametersTest is Test {
  using PercentageMath for uint256;

  /// @dev `AssetInterestRateStrategy` bounds.
  uint256 internal constant MIN_OPTIMAL_RATIO = 1_00;
  uint256 internal constant MAX_OPTIMAL_RATIO = 99_00;
  uint256 internal constant MAX_ALLOWED_DRAWN_RATE = 1000_00;
  /// @dev `Spoke.HEALTH_FACTOR_LIQUIDATION_THRESHOLD`.
  uint256 internal constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;

  function test_interestRateCurves() public pure {
    _assertAssetParams(ArcParameters.Asset.USDC, 90_00, 0, 4_10, 10_00, 10_00, 10_000_000);
    _assertAssetParams(ArcParameters.Asset.EURC, 90_00, 0, 5_50, 50_00, 10_00, 9_000_000);
    // base rate is 25 BPS, or 0.25%
    _assertAssetParams(ArcParameters.Asset.CIRBTC, 80_00, 25, 4_00, 60_00, 20_00, 160);
    _assertAssetParams(ArcParameters.Asset.WETH, 90_00, 0, 2_20, 8_00, 15_00, 6_000);
  }

  function test_mainSpokeReserves() public pure {
    ArcParameters.Spoke main = ArcParameters.Spoke.MAIN;

    _assertReserveParams(ArcParameters.Asset.CIRBTC, main, 78_00, 107_22, 10_00, 1_100, 220);
    _assertReserveParams(
      ArcParameters.Asset.USDC,
      main,
      78_00,
      105_55,
      10_00,
      56_000_000,
      51_000_000
    );
    _assertReserveParams(ArcParameters.Asset.WETH, main, 83_00, 105_55, 10_00, 24_000, 4_800);
    // EURC is borrowable on Main at a 0.00% collateral factor, so no bonus or fee is published
    _assertReserveParams(ArcParameters.Asset.EURC, main, 0, 100_00, 0, 20_000_000, 18_000_000);
  }

  function test_forexSpokeReserves() public pure {
    ArcParameters.Spoke forex = ArcParameters.Spoke.FOREX;

    _assertReserveParams(
      ArcParameters.Asset.EURC,
      forex,
      90_00,
      102_00,
      10_00,
      10_000_000,
      9_000_000
    );
    _assertReserveParams(
      ArcParameters.Asset.USDC,
      forex,
      90_00,
      102_00,
      10_00,
      13_000_000,
      11_000_000
    );

    // the ARFC lists neither on the Forex spoke
    assertFalse(ArcParameters.reserveParams(ArcParameters.Asset.CIRBTC, forex).listed, 'cirBTC');
    assertFalse(ArcParameters.reserveParams(ArcParameters.Asset.WETH, forex).listed, 'wETH');
  }

  /// @notice Six of the eight asset and spoke pairs are listed, spread three on Main to two on Forex
  /// plus EURC on Main.
  function test_listedPairCount() public pure {
    uint256 listed;
    for (uint256 a; a < ArcParameters.assetCount(); ++a) {
      for (uint256 s; s < ArcParameters.spokeCount(); ++s) {
        if (ArcParameters.reserveParams(ArcParameters.Asset(a), ArcParameters.Spoke(s)).listed) {
          ++listed;
        }
      }
    }
    assertEq(listed, 6, 'listed pairs');
  }

  function test_liquidationConfigs() public pure {
    ISpoke.LiquidationConfig memory main = ArcParameters.liquidationConfig(
      ArcParameters.Spoke.MAIN
    );
    assertEq(main.targetHealthFactor, 1.24e18, 'main target health factor');
    assertEq(main.healthFactorForMaxBonus, 0.90e18, 'main health factor for max bonus');
    assertEq(main.liquidationBonusFactor, 90_00, 'main liquidation bonus factor');

    ISpoke.LiquidationConfig memory forex = ArcParameters.liquidationConfig(
      ArcParameters.Spoke.FOREX
    );
    assertEq(forex.targetHealthFactor, 1.0442e18, 'forex target health factor');
    assertEq(forex.healthFactorForMaxBonus, 0.99e18, 'forex health factor for max bonus');
    assertEq(forex.liquidationBonusFactor, 100_00, 'forex liquidation bonus factor');
  }

  /// @notice Every rate curve passes the bounds `AssetInterestRateStrategy` enforces.
  function test_rateCurvesAreValid() public pure {
    for (uint256 a; a < ArcParameters.assetCount(); ++a) {
      ArcParameters.AssetParams memory params = ArcParameters.assetParams(ArcParameters.Asset(a));

      assertGe(params.optimalUsageRatio, MIN_OPTIMAL_RATIO, 'optimal usage ratio floor');
      assertLe(params.optimalUsageRatio, MAX_OPTIMAL_RATIO, 'optimal usage ratio ceiling');
      assertLe(
        uint256(params.baseDrawnRate) +
          params.rateGrowthBeforeOptimal +
          params.rateGrowthAfterOptimal,
        MAX_ALLOWED_DRAWN_RATE,
        'max drawn rate'
      );
      assertLe(params.liquidityFee, PercentageMath.PERCENTAGE_FACTOR, 'liquidity fee');
    }
  }

  /// @notice Every listed pair passes `Spoke._validateDynamicReserveConfig`, whose collateral factor
  ///         and max liquidation bonus check is the one a hand-entered parameter set can trip.
  function test_reserveParamsAreValid() public pure {
    for (uint256 a; a < ArcParameters.assetCount(); ++a) {
      for (uint256 s; s < ArcParameters.spokeCount(); ++s) {
        ArcParameters.ReserveParams memory params = ArcParameters.reserveParams(
          ArcParameters.Asset(a),
          ArcParameters.Spoke(s)
        );
        if (!params.listed) continue;

        assertLt(
          params.collateralFactor,
          PercentageMath.PERCENTAGE_FACTOR,
          'collateral factor ceiling'
        );
        assertGe(
          params.maxLiquidationBonus,
          PercentageMath.PERCENTAGE_FACTOR,
          'max liquidation bonus floor'
        );
        assertLt(
          uint256(params.maxLiquidationBonus).percentMulUp(params.collateralFactor),
          PercentageMath.PERCENTAGE_FACTOR,
          'collateral factor against max liquidation bonus'
        );
        assertLe(params.liquidationFee, PercentageMath.PERCENTAGE_FACTOR, 'liquidation fee');
      }
    }
  }

  /// @notice Every liquidation config passes `Spoke.updateLiquidationConfig`.
  function test_liquidationConfigsAreValid() public pure {
    for (uint256 s; s < ArcParameters.spokeCount(); ++s) {
      ISpoke.LiquidationConfig memory config = ArcParameters.liquidationConfig(
        ArcParameters.Spoke(s)
      );

      assertGe(
        config.targetHealthFactor,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        'target health factor'
      );
      assertLt(
        config.healthFactorForMaxBonus,
        HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        'health factor for max bonus'
      );
      assertLe(
        config.liquidationBonusFactor,
        PercentageMath.PERCENTAGE_FACTOR,
        'liquidation bonus factor'
      );
    }
  }

  /// @notice Every draw cap is at or below its add cap.
  function test_drawCapsWithinAddCaps() public pure {
    for (uint256 a; a < ArcParameters.assetCount(); ++a) {
      for (uint256 s; s < ArcParameters.spokeCount(); ++s) {
        ArcParameters.ReserveParams memory params = ArcParameters.reserveParams(
          ArcParameters.Asset(a),
          ArcParameters.Spoke(s)
        );
        if (!params.listed) continue;
        assertLe(params.drawCap, params.addCap, 'draw cap within add cap');
      }
    }
  }

  /// @notice USDC, EURC and cirBTC decimals are the values observed on Arc mainnet. wETH's 18 is the
  ///         conventional value, since no wrapped ETH is deployed there.
  function test_underlyingDecimals() public pure {
    assertEq(ArcParameters.underlyingDecimals(ArcParameters.Asset.USDC), 6, 'USDC');
    assertEq(ArcParameters.underlyingDecimals(ArcParameters.Asset.EURC), 6, 'EURC');
    assertEq(ArcParameters.underlyingDecimals(ArcParameters.Asset.CIRBTC), 8, 'cirBTC');
    assertEq(ArcParameters.underlyingDecimals(ArcParameters.Asset.WETH), 18, 'wETH');
  }

  /// @notice Share token naming matches the convention read off the Ethereum and Avalanche V4 CORE
  ///         tokenization spokes: `Wrapped Aave Core USDC` / `waCoreUSDC`, no chain marker, and the
  ///         underlying's own symbol casing preserved.
  function test_tokenizationShareNaming() public pure {
    assertEq(ArcParameters.tokenizationShareName('USDC'), 'Wrapped Aave Core USDC');
    assertEq(ArcParameters.tokenizationShareSymbol('USDC'), 'waCoreUSDC');

    assertEq(ArcParameters.tokenizationShareName('EURC'), 'Wrapped Aave Core EURC');
    assertEq(ArcParameters.tokenizationShareSymbol('EURC'), 'waCoreEURC');

    // casing comes straight from the token, as in Ethereum's waCorecbBTC and Avalanche's waCoreBTCb
    assertEq(ArcParameters.tokenizationShareName('cirBTC'), 'Wrapped Aave Core cirBTC');
    assertEq(ArcParameters.tokenizationShareSymbol('cirBTC'), 'waCorecirBTC');

    assertEq(ArcParameters.tokenizationShareName('wETH'), 'Wrapped Aave Core wETH');
    assertEq(ArcParameters.tokenizationShareSymbol('wETH'), 'waCorewETH');
  }

  function test_symbolsMatchConfigKeys() public pure {
    assertEq(ArcParameters.symbol(ArcParameters.Asset.USDC), 'USDC');
    assertEq(ArcParameters.symbol(ArcParameters.Asset.EURC), 'EURC');
    assertEq(ArcParameters.symbol(ArcParameters.Asset.CIRBTC), 'cirBTC');
    assertEq(ArcParameters.symbol(ArcParameters.Asset.WETH), 'wETH');
  }

  function _assertAssetParams(
    ArcParameters.Asset asset,
    uint16 optimalUsageRatio,
    uint32 baseDrawnRate,
    uint32 slope1,
    uint32 slope2,
    uint256 liquidityFee,
    uint256 tokenizationAddCap
  ) internal pure {
    ArcParameters.AssetParams memory params = ArcParameters.assetParams(asset);
    string memory name = ArcParameters.symbol(asset);

    assertEq(params.optimalUsageRatio, optimalUsageRatio, string.concat(name, ' Uoptimal'));
    assertEq(params.baseDrawnRate, baseDrawnRate, string.concat(name, ' base'));
    assertEq(params.rateGrowthBeforeOptimal, slope1, string.concat(name, ' slope 1'));
    assertEq(params.rateGrowthAfterOptimal, slope2, string.concat(name, ' slope 2'));
    assertEq(params.liquidityFee, liquidityFee, string.concat(name, ' liquidity fee'));
    assertEq(
      params.tokenizationAddCap,
      tokenizationAddCap,
      string.concat(name, ' tokenization add cap')
    );
  }

  function _assertReserveParams(
    ArcParameters.Asset asset,
    ArcParameters.Spoke spoke,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee,
    uint40 addCap,
    uint40 drawCap
  ) internal pure {
    ArcParameters.ReserveParams memory params = ArcParameters.reserveParams(asset, spoke);
    string memory name = ArcParameters.symbol(asset);

    assertTrue(params.listed, string.concat(name, ' listed'));
    assertTrue(params.borrowable, string.concat(name, ' borrowable'));
    assertEq(params.collateralFactor, collateralFactor, string.concat(name, ' collateral factor'));
    assertEq(params.maxLiquidationBonus, maxLiquidationBonus, string.concat(name, ' max bonus'));
    assertEq(params.liquidationFee, liquidationFee, string.concat(name, ' liquidation fee'));
    assertEq(params.addCap, addCap, string.concat(name, ' add cap'));
    assertEq(params.drawCap, drawCap, string.concat(name, ' draw cap'));
  }
}
