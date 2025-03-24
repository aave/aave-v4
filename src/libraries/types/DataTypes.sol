// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';

library DataTypes {
  // Liquidity Hub types
  // todo pack
  struct SpokeData {
    uint256 suppliedShares;
    uint256 baseDrawnShares;
    uint256 premiumDrawnShares;
    uint256 premiumOffset; // todo make signed
    uint256 unrealisedPremium;
    uint256 lastUpdateTimestamp; // todo: unneeded?
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    uint256 suppliedShares;
    uint256 availableLiquidity;
    uint256 baseDrawnShares;
    uint256 premiumDrawnShares;
    uint256 premiumOffset; // todo make signed
    uint256 unrealisedPremium;
    uint256 baseDrawnAssets;
    uint256 baseBorrowRate;
    uint256 lastUpdateTimestamp;
    uint256 id; // todo remove
    DataTypes.AssetConfig config;
  }

  struct SpokeConfig {
    uint256 drawCap;
    uint256 supplyCap;
  }

  struct AssetConfig {
    bool active;
    bool frozen;
    bool paused;
    uint256 decimals;
    IReserveInterestRateStrategy irStrategy;
  }

  // Spoke types
  struct CalculateInterestRatesParams {
    bool usingVirtualBalance;
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalDebt;
    uint256 reserveFactor; // likely not required
    uint256 assetId;
    uint256 virtualUnderlyingBalance;
  }

  struct Reserve {
    uint256 reserveId;
    uint256 assetId;
    address asset;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    ReserveConfig config;
  }

  struct ReserveConfig {
    bool active;
    bool frozen;
    bool paused;
    bool borrowable;
    bool collateral;
    uint256 decimals;
    uint256 collateralFactor; // BPS
    uint256 liquidationBonus; // TODO: liquidationProtocolFee
    uint256 liquidityPremium; // BPS
  }

  struct UserPosition {
    bool usingAsCollateral;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 riskPremium;
    uint256 lastUpdateTimestamp;
  }

  struct UserData {
    /**
     * ray-extended risk premium bps of user
     * for example, if risk premium bps is 15_50 (15.5%),
     * then this value is 1550_000000000000000000000000000 (1550 * 1e27),
     * stored with high precision to be equivalent with other RPs (Asset, Spoke/Reserve)
     * since they have to maintain a running weighted average
     * todo optimize: user RP doesn't need to be stored in full precision as described above
     */
    uint256 riskPremium;
    // todo supplied/borrowed (2d) bitmap
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 assetId;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 reserveId;
    uint256 reservePrice;
    uint256 liquidityPremium;
    uint256 collateralReserveCount;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtCounterInBaseCurrency;
    uint256 collateralCounterInBaseCurrency;
    uint256 avgCollateralFactor;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }
}
