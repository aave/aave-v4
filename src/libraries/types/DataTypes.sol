// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.10;

import {IHub} from 'src/interfaces/IHub.sol';

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
    IHub hub;
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
    uint32 liquidationBonus; // BPS, 100_00 represent a 0% bonus
    uint16 liquidationFee; // BPS
  }

  struct LiquidationConfig {
    uint128 closeFactor; // WAD, HF value to restore to during a liquidation
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

  struct NotifyRiskPremiumUpdateVars {
    bool premiumIncrease;
    uint256 reserveCount;
    uint256 reserveId;
    uint256 assetId;
    IHub hub;
    DataTypes.PremiumDelta premiumDelta;
  }

  struct PremiumDelta {
    int256 sharesDelta;
    int256 offsetDelta;
    int256 realizedDelta;
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 assetId;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 reserveId;
    uint256 reservePrice;
    uint256 collateralRisk;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtCounterInBaseCurrency;
    uint256 collateralCounterInBaseCurrency;
    uint256 avgCollateralFactor;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }

  struct LiquidationCallLocalVars {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationFeeAmount;
    uint256 borrowerCollateralBalance;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 totalBorrowerReserveDebt;
    uint256 debtToRestoreCloseFactor;
    uint256 healthFactor;
    uint256 liquidationBonus;
    uint256 drawnDebtToLiquidate;
    uint256 premiumDebtToLiquidate;
    uint256 closeFactor;
    uint256 collateralFactor;
    uint256 collateralAssetPrice;
    uint256 collateralAssetUnit;
    uint256 liquidationFee;
    bool hasDeficit;
  }

  struct CalculateAvailableCollateralToLiquidate {
    uint256 borrowerCollateralBalanceInBaseCurrency;
    uint256 baseCollateral;
    uint256 maxCollateralToLiquidate;
    uint256 collateralAmount;
    uint256 debtAmountNeeded;
    uint256 collateralToLiquidateInBaseCurrency;
    uint256 debtToLiquidateInBaseCurrency;
    bool hasDeficit;
  }

  struct ExecuteLiquidationLocalVars {
    uint256 i;
    address user;
    uint256 debtAssetId;
    uint256 collateralAssetId;
    uint256 debtReserveId;
    uint256 collateralReserveId;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 accruedPremium;
    uint256 collateralToLiquidate;
    uint256 liquidationFeeAmount;
    uint256 liquidationFeeShares;
    uint256 drawnDebtToLiquidate;
    uint256 premiumDebtToLiquidate;
    uint256 restoredShares;
    uint256 withdrawnShares;
    uint256 newUserRiskPremium;
    uint256 totalLiquidationFeeShares;
    uint256 usersLength;
    uint256 liquidatedSuppliedShares;
    DataTypes.PremiumDelta premiumDelta;
    bool hasDeficit;
    IHub collateralReserveHub;
    IHub debtReserveHub;
  }

  struct ExecuteRepayLocalVars {
    IHub hub;
    uint256 assetId;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 accruedPremium;
    uint256 drawnDebtRestored;
    uint256 premiumDebtRestored;
    uint256 userPremiumShares;
    uint256 userPremiumOffset;
    uint256 newUserRiskPremium;
    uint256 restoredShares;
  }
}
