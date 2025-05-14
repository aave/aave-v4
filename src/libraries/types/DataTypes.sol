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
    uint256 baseDebtIndex;
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

  // TODO: liquidationProtocolFee
  struct ReserveConfig {
    bool active;
    bool frozen;
    bool paused;
    bool borrowable;
    bool collateral;
    uint256 decimals; // TODO: use smaller uint8
    uint256 collateralFactor; // BPS TODO: use smaller uint
    uint256 liquidationBonus; // BPS, 100_00 represent a 0% bonus TODO: use smaller uint
    uint256 liquidityPremium; // BPS TODO: use smaller uint
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

  struct LiquidationConfig {
    uint256 closeFactor; // BPS, HF value to restore to during a liquidation, TODO: use smaller uint
    uint256 healthFactorBonusThreshold; // health factor under which liquidation bonus is max, TODO: use smaller uint
    uint256 liquidationBonusFactor; // BPS, as a percentage of effective lb, TODO: use smaller uint
  }
}
