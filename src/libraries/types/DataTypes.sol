// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library DataTypes {
  // Liquidity Hub types
  struct SpokeData {
    uint256 suppliedShares; // share
    uint256 baseDebt; // asset
    uint256 outstandingPremium; // asset
    uint256 baseBorrowIndex; // in ray
    uint256 riskPremium; // weighted average risk premium in ray
    uint256 lastUpdateTimestamp;
    DataTypes.SpokeConfig config;
  }

  struct Asset {
    uint256 id;
    uint256 suppliedShares; // share
    uint256 availableLiquidity; // asset
    uint256 baseDebt; // asset
    uint256 outstandingPremium; // asset
    uint256 baseBorrowIndex; // in ray
    uint256 baseBorrowRate; // in ray
    uint256 riskPremium; // weighted average risk premium of all spokes with ray precision
    uint256 lastUpdateTimestamp;
    DataTypes.AssetConfig config;
  }

  struct SpokeConfig {
    uint256 drawCap; // asset denominated
    uint256 supplyCap; // asset denominated
  }

  struct AssetConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    address irStrategy; // todo use interface
  }

  // Spoke types
  struct CalculateInterestRatesParams {
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalDebt;
    uint256 reserveFactor; // likely not required
    uint256 assetId;
    uint256 virtualUnderlyingBalance;
    bool usingVirtualBalance;
  }

  struct Reserve {
    uint256 assetId;
    address asset;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 lastUpdateTimestamp;
    uint256 riskPremium; // weighted average risk premium of all users with ray precision
    ReserveConfig config;
  }

  struct ReserveConfig {
    uint256 lt; // 1e4 == 100%, BPS
    uint256 lb; // TODO: liquidationProtocolFee
    uint256 liquidityPremium; // BPS
    bool borrowable;
    bool collateral;
  }

  struct UserConfig {
    bool usingAsCollateral;
    uint256 baseDebt;
    uint256 outstandingPremium;
    uint256 suppliedShares;
    uint256 baseBorrowIndex;
    uint256 riskPremium;
    uint256 lastUpdateTimestamp;
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 reserveId;
    uint256 reservePrice;
    uint256 liquidityPremium;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 avgLiquidationThreshold;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }
}
