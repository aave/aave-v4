// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ArcParameters
/// @author Aave Labs
/// @notice The Arc risk parameters published by LlamaRisk, transcribed from the ARFC.
/// @dev Source: https://governance.aave.com/t/arfc-deploy-aave-v4-on-arc/25170, LlamaRisk post #3
/// of 19 June 2026, as revised by the Changelog in that post (cirBTC collateral factor to 78%,
/// USDC slope 1 to 4.10%, wETH slope 1 to 2.20%, cirBTC base to 0.25% / slope 2 to 60% /
/// liquidity fee to 20%). LlamaRisk describes the set as preliminary and revisable, so re-read the
/// post's Changelog before a real run: `tests/deployments/ArcParameters.t.sol` pins every value
/// here so a revision shows up as a failing test rather than a silent drift.
///
/// All percentages are in BPS, written as `<percent>_<hundredths>`: 4.10% is `4_10` and 90.00% is
/// `90_00`. Values below 1% are written as plain BPS, since Solidity rejects a separator in a
/// leading-zero decimal literal. Caps are in whole token units, which is what the Hub compares
/// against after scaling by the asset's decimals.
library ArcParameters {
  /// @notice The assets in the ARFC parameter tables.
  enum Asset {
    USDC,
    EURC,
    CIRBTC,
    WETH
  }

  /// @notice The borrowing spokes, in the order `config/arc.json` declares `spokeLabels`.
  enum Spoke {
    MAIN,
    FOREX
  }

  /// @notice Hub-side parameters, which are per asset rather than per reserve.
  /// @dev optimalUsageRatio The optimal usage ratio, in BPS.
  /// @dev baseDrawnRate The base drawn rate, in BPS.
  /// @dev rateGrowthBeforeOptimal Slope 1, in BPS.
  /// @dev rateGrowthAfterOptimal Slope 2, in BPS.
  /// @dev liquidityFee The liquidity fee, in BPS.
  /// @dev tokenizationAddCap The add cap of the asset's tokenization spoke, in whole token units.
  struct AssetParams {
    uint16 optimalUsageRatio;
    uint32 baseDrawnRate;
    uint32 rateGrowthBeforeOptimal;
    uint32 rateGrowthAfterOptimal;
    uint256 liquidityFee;
    uint40 tokenizationAddCap;
  }

  /// @notice Spoke-side parameters, which are per asset and spoke pair.
  /// @dev listed False for pairs the ARFC does not list, such as cirBTC on the Forex spoke.
  /// @dev collateralFactor The collateral factor, in BPS.
  /// @dev maxLiquidationBonus The max liquidation bonus, in BPS, where `100_00` is a 0.00% bonus.
  /// @dev liquidationFee The liquidation fee, in BPS.
  /// @dev borrowable Whether the reserve is borrowable.
  /// @dev addCap The add cap, in whole token units.
  /// @dev drawCap The draw cap, in whole token units.
  struct ReserveParams {
    bool listed;
    uint16 collateralFactor;
    uint32 maxLiquidationBonus;
    uint16 liquidationFee;
    bool borrowable;
    uint40 addCap;
    uint40 drawCap;
  }

  /// @dev `PercentageMath.PERCENTAGE_FACTOR`, the `maxLiquidationBonus` value meaning a 0.00% bonus.
  uint32 internal constant NO_LIQUIDATION_BONUS = 100_00;

  /// @dev The hub name as it appears in tokenization spoke share tokens. Arc runs a single hub,
  /// labelled `core` in the deploy inputs.
  string internal constant HUB_NAME = 'Core';

  /// @dev Values the ARFC does not specify, taken from the live Ethereum and Avalanche V4 CORE
  /// markets rather than defaulted. Both agree on all three, read on-chain from their `main` and
  /// `forex` spokes:
  ///   - `receiveSharesEnabled` is true, so a liquidator may take collateral shares.
  ///   - `riskPremiumThreshold` is 0. This is the strictest value, not a neutral one: `Hub` requires
  ///     `premiumShares <= drawnShares.percentMulUp(threshold)` unless it equals
  ///     `MAX_RISK_PREMIUM_THRESHOLD`, so 0 forbids any risk premium. Both markets also leave
  ///     `SPOKE_USER_POSITION_UPDATER_ROLE` unheld, so neither uses risk premium at all.
  ///   - `collateralRisk` is 0.
  bool internal constant RECEIVE_SHARES_ENABLED = true;
  uint24 internal constant RISK_PREMIUM_THRESHOLD = 0;
  uint24 internal constant COLLATERAL_RISK = 0;

  /// @notice The number of assets in the parameter tables.
  function assetCount() internal pure returns (uint256) {
    return 4;
  }

  /// @notice The number of borrowing spokes in the parameter tables.
  function spokeCount() internal pure returns (uint256) {
    return 2;
  }

  /// @notice The symbol of an asset, used as its key in config/arc-config.json.
  /// @param asset The asset.
  /// @return The asset symbol.
  function symbol(Asset asset) internal pure returns (string memory) {
    if (asset == Asset.USDC) return 'USDC';
    if (asset == Asset.EURC) return 'EURC';
    if (asset == Asset.CIRBTC) return 'cirBTC';
    return 'wETH';
  }

  /// @notice The decimals the asset's underlying token is expected to have on Arc.
  /// @dev Checked against the token at configuration time, to catch an address that has code but is
  /// not the intended asset. Circle's Arc documentation publishes a testnet-only EURC address, and
  /// that address has been mistaken for the mainnet deployment more than once, so the underlying is
  /// not taken on trust.
  ///
  /// wETH's 18 is the conventional value, not one read off the token supplied for Arc, which is
  /// itself unverified. If that token turns out to carry different decimals this check fires, which
  /// is the intent.
  /// @param asset The asset.
  /// @return The expected decimals.
  function underlyingDecimals(Asset asset) internal pure returns (uint8) {
    if (asset == Asset.USDC) return 6;
    if (asset == Asset.EURC) return 6;
    if (asset == Asset.CIRBTC) return 8;
    return 18;
  }

  /// @notice The ERC20 name of a tokenization spoke share token.
  /// @dev Matches the convention deployed on Ethereum and Avalanche V4, read off-chain from their
  /// CORE tokenization spokes: `Wrapped Aave Core USDC` with symbol `waCoreUSDC`. The hub name is
  /// in the string and the chain is not — Avalanche's USDC share token carries the same name and
  /// symbol as Ethereum's, so collisions across chains are part of the convention rather than
  /// something to work around.
  ///
  /// The asset segment is the underlying's own `symbol()`, casing untouched, which is why Ethereum
  /// has `waCorecbBTC` and `waCoreUSDt` and Avalanche has `waCoreWETHe` and `waCoreBTCb`. Taking it
  /// from the token rather than from a table here keeps that property and avoids guessing whether
  /// Arc's wrapped ether calls itself `wETH` or `WETH`.
  /// @param assetSymbol The underlying token's ERC20 symbol.
  /// @return The share token name.
  function tokenizationShareName(string memory assetSymbol) internal pure returns (string memory) {
    return string.concat('Wrapped Aave ', HUB_NAME, ' ', assetSymbol);
  }

  /// @notice The ERC20 symbol of a tokenization spoke share token.
  /// @param assetSymbol The underlying token's ERC20 symbol.
  /// @return The share token symbol.
  function tokenizationShareSymbol(
    string memory assetSymbol
  ) internal pure returns (string memory) {
    return string.concat('wa', HUB_NAME, assetSymbol);
  }

  /// @notice The Hub-side parameters of an asset: its rate curve, liquidity fee and tokenization cap.
  /// @param asset The asset.
  /// @return The Hub-side parameters.
  function assetParams(Asset asset) internal pure returns (AssetParams memory) {
    if (asset == Asset.USDC) {
      return
        AssetParams({
          optimalUsageRatio: 90_00,
          baseDrawnRate: 0,
          rateGrowthBeforeOptimal: 4_10,
          rateGrowthAfterOptimal: 10_00,
          liquidityFee: 10_00,
          tokenizationAddCap: 10_000_000
        });
    }
    if (asset == Asset.EURC) {
      return
        AssetParams({
          optimalUsageRatio: 90_00,
          baseDrawnRate: 0,
          rateGrowthBeforeOptimal: 5_50,
          rateGrowthAfterOptimal: 50_00,
          liquidityFee: 10_00,
          tokenizationAddCap: 9_000_000
        });
    }
    if (asset == Asset.CIRBTC) {
      return
        AssetParams({
          optimalUsageRatio: 80_00,
          // 0.25%, which the `<percent>_<hundredths>` form cannot spell: a leading zero decimal
          // literal may not take a separator
          baseDrawnRate: 25,
          rateGrowthBeforeOptimal: 4_00,
          rateGrowthAfterOptimal: 60_00,
          liquidityFee: 20_00,
          tokenizationAddCap: 160
        });
    }
    return
      AssetParams({
        optimalUsageRatio: 90_00,
        baseDrawnRate: 0,
        rateGrowthBeforeOptimal: 2_20,
        rateGrowthAfterOptimal: 8_00,
        liquidityFee: 15_00,
        tokenizationAddCap: 6_000
      });
  }

  /// @notice The Spoke-side parameters of an asset on a spoke.
  /// @dev EURC on the Main spoke is borrowable at a 0.00% collateral factor, so the ARFC leaves its
  /// bonus and fee blank; they are set to the neutral values a 0.00% collateral factor makes
  /// unreachable. Pairs the ARFC does not list come back with `listed` false.
  /// @param asset The asset.
  /// @param spoke The spoke.
  /// @return The Spoke-side parameters.
  function reserveParams(Asset asset, Spoke spoke) internal pure returns (ReserveParams memory) {
    if (spoke == Spoke.MAIN) {
      if (asset == Asset.CIRBTC) {
        return
          ReserveParams({
            listed: true,
            collateralFactor: 78_00,
            maxLiquidationBonus: 107_22,
            liquidationFee: 10_00,
            borrowable: true,
            addCap: 1_100,
            drawCap: 220
          });
      }
      if (asset == Asset.USDC) {
        return
          ReserveParams({
            listed: true,
            collateralFactor: 78_00,
            maxLiquidationBonus: 105_55,
            liquidationFee: 10_00,
            borrowable: true,
            addCap: 56_000_000,
            drawCap: 51_000_000
          });
      }
      if (asset == Asset.WETH) {
        return
          ReserveParams({
            listed: true,
            collateralFactor: 83_00,
            maxLiquidationBonus: 105_55,
            liquidationFee: 10_00,
            borrowable: true,
            addCap: 24_000,
            drawCap: 4_800
          });
      }
      return
        ReserveParams({
          listed: true,
          collateralFactor: 0,
          maxLiquidationBonus: NO_LIQUIDATION_BONUS,
          liquidationFee: 0,
          borrowable: true,
          addCap: 20_000_000,
          drawCap: 18_000_000
        });
    }

    if (asset == Asset.EURC) {
      return
        ReserveParams({
          listed: true,
          collateralFactor: 90_00,
          maxLiquidationBonus: 102_00,
          liquidationFee: 10_00,
          borrowable: true,
          addCap: 10_000_000,
          drawCap: 9_000_000
        });
    }
    if (asset == Asset.USDC) {
      return
        ReserveParams({
          listed: true,
          collateralFactor: 90_00,
          maxLiquidationBonus: 102_00,
          liquidationFee: 10_00,
          borrowable: true,
          addCap: 13_000_000,
          drawCap: 11_000_000
        });
    }

    // cirBTC and wETH are not listed on the Forex spoke
    return
      ReserveParams({
        listed: false,
        collateralFactor: 0,
        maxLiquidationBonus: NO_LIQUIDATION_BONUS,
        liquidationFee: 0,
        borrowable: false,
        addCap: 0,
        drawCap: 0
      });
  }

  /// @notice The dynamic liquidation bonus configuration of a spoke.
  /// @param spoke The spoke.
  /// @return The liquidation configuration.
  function liquidationConfig(Spoke spoke) internal pure returns (ISpoke.LiquidationConfig memory) {
    if (spoke == Spoke.MAIN) {
      return
        ISpoke.LiquidationConfig({
          targetHealthFactor: 1.24e18,
          healthFactorForMaxBonus: 0.90e18,
          liquidationBonusFactor: 90_00
        });
    }
    return
      ISpoke.LiquidationConfig({
        targetHealthFactor: 1.0442e18,
        healthFactorForMaxBonus: 0.99e18,
        liquidationBonusFactor: 100_00
      });
  }
}
