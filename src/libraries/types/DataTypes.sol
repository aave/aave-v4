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
    uint256 realizedPremium;
    uint256 lastUpdateTimestamp; // todo: unneeded?
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    uint256 suppliedShares;
    uint256 availableLiquidity;
    uint256 baseDrawnShares;
    uint256 premiumDrawnShares;
    uint256 premiumOffset; // todo make signed
    uint256 realizedPremium;
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
    uint256 suppliedShares;
    uint256 baseDrawnShares;
    uint256 premiumDrawnShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
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
    uint256 suppliedShares;
    uint256 baseDrawnShares;
    uint256 premiumDrawnShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
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
