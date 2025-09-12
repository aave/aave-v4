// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {IHubBase} from 'src/interfaces/IHubBase.sol';

library DataTypes {
  // Hub types
  struct SpokeData {
    //
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 realizedPremium;
    uint128 drawnShares;
    //
    uint128 addedShares;
    uint56 addCap;
    uint56 drawCap;
    bool active;
  }

  struct Asset {
    //
    uint128 liquidity;
    uint128 addedShares;
    //
    uint128 deficit;
    uint128 swept;
    //
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 drawnIndex;
    uint128 drawnShares;
    //
    uint128 realizedPremium;
    uint16 liquidityFee;
    uint40 lastUpdateTimestamp;
    uint8 decimals;
    //
    address underlying;
    //
    uint96 drawnRate;
    address irStrategy;
    //
    address reinvestmentController;
    //
    address feeReceiver;
  }

  struct SpokeConfig {
    bool active;
    uint56 addCap;
    uint56 drawCap;
  }

  struct AssetConfig {
    address feeReceiver;
    uint16 liquidityFee;
    address irStrategy;
    address reinvestmentController;
  }

  // Spoke types
  struct Reserve {
    address underlying;
    //
    IHubBase hub;
    uint16 assetId;
    uint8 decimals;
    uint16 dynamicConfigKey; // key of the last reserve config
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk;
  }

  struct DynamicReserveConfig {
    uint16 collateralFactor;
    uint32 maxLiquidationBonus; // BPS, 100_00 represent a 0% bonus
    uint16 liquidationFee; // BPS
  }

  struct LiquidationConfig {
    uint128 targetHealthFactor; // WAD, HF value to restore to during a liquidation
    uint64 healthFactorForMaxBonus; // WAD, health factor under which liquidation bonus is max
    uint16 liquidationBonusFactor; // BPS, as a percentage of effective lb
  }

  struct UserPosition {
    //
    uint128 drawnShares;
    uint128 realizedPremium;
    //
    uint128 premiumShares;
    uint128 premiumOffset;
    //
    uint128 suppliedShares;
    uint16 configKey; // key of the last user config
  }

  struct PositionManagerConfig {
    bool active;
    mapping(address user => bool approved) approval;
  }

  struct PositionStatus {
    mapping(uint256 slot => uint256 status) map;
  }

  struct ReserveConfig {
    bool paused;
    bool frozen;
    bool borrowable;
    uint24 collateralRisk; // BPS
  }

  struct PremiumDelta {
    int256 sharesDelta;
    int256 offsetDelta;
    int256 realizedDelta;
  }

  struct UserAccountData {
    uint256 userRiskPremium;
    uint256 avgCollateralFactor;
    uint256 healthFactor;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 suppliedCollateralsCount; // number of reserves with collateral factor > 0, enabled as collateral and strictly positive supplied amount
    uint256 borrowedReservesCount; // number of reserves with strictly positive debt
  }

  struct LiquidateUserParams {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address oracle;
    address user;
    uint256 debtToCover;
    uint256 healthFactor;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 accruedPremium;
    uint256 totalDebtInBaseCurrency;
    address liquidator;
    uint256 suppliedCollateralsCount;
    uint256 borrowedReservesCount;
  }
}
