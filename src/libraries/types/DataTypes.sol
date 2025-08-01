// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {IHub} from 'src/interfaces/IHub.sol';

library DataTypes {
  // Hub types
  // todo pack
  struct SpokeData {
    uint256 addedShares;
    uint256 drawnShares;
    uint256 premiumShares;
    uint256 premiumOffset; // todo make signed
    uint256 realizedPremium;
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    address underlying;
    uint8 decimals;
    uint256 addedShares;
    uint256 liquidity;
    uint256 drawnShares;
    uint256 premiumShares;
    uint256 premiumOffset; // todo make signed
    uint256 realizedPremium;
    uint256 drawnIndex;
    uint256 drawnRate;
    uint256 lastUpdateTimestamp;
    uint256 deficit;
    DataTypes.AssetConfig config;
  }

  struct SpokeConfig {
    bool active;
    uint256 addCap;
    uint256 drawCap;
  }

  struct AssetConfig {
    address feeReceiver;
    uint256 liquidityFee;
    address irStrategy;
  }

  // Spoke types
  struct Reserve {
    uint256 reserveId;
    uint256 assetId;
    ReserveConfig config;
    uint16 dynamicConfigKey; // key of the last reserve config
    uint8 decimals;
    address underlying;
    IHub hub;
  }

  struct ReserveConfig {
    bool frozen;
    bool paused;
    bool borrowable;
    uint256 collateralRisk; // BPS TODO: use smaller uint
  }

  struct DynamicReserveConfig {
    uint16 collateralFactor;
    uint256 liquidationBonus; // BPS, 100_00 represent a 0% bonus TODO: use smaller uint
    uint256 liquidationFee; // BPS TODO: use smaller uint
  }

  struct UserPosition {
    uint256 suppliedShares;
    uint256 drawnShares;
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 realizedPremium;
    uint16 configKey; // key of the last user config
  }

  struct PositionManagerConfig {
    bool active;
    mapping(address user => bool approved) approval;
  }

  struct PositionStatus {
    mapping(uint256 slot => uint256 status) map;
  }

  struct NotifyRiskPremiumUpdateVars {
    bool premiumIncrease;
    uint256 reserveCount;
    uint256 reserveId;
    uint256 assetId;
    IHub hub;
    DataTypes.PremiumDelta premiumDelta;
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

  struct LiquidationConfig {
    uint256 closeFactor; // BPS, HF value to restore to during a liquidation, TODO: use smaller uint
    uint256 healthFactorForMaxBonus; // health factor under which liquidation bonus is max, TODO: use smaller uint
    uint256 liquidationBonusFactor; // BPS, as a percentage of effective lb, TODO: use smaller uint
  }

  struct PremiumDelta {
    int256 sharesDelta;
    int256 offsetDelta;
    int256 realizedDelta;
  }

  struct LiquidationCallLocalVars {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationFeeAmount;
    uint256 userCollateralBalance;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 totalDebt;
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
    uint256 userCollateralBalanceInBaseCurrency;
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
    address collateralUnderlying;
    address debtUnderlying;
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
