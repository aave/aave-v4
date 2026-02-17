// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub, IHubBase} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title TestTypes
/// @notice Canonical shared struct definitions for the Aave V4 test suite.
///         All test base contracts inherit from here to avoid duplicate definitions.
abstract contract TestTypes {
  // ──────────────────────────────────────────────────────────────
  //  Core protocol test structs (from Base.t.sol)
  // ──────────────────────────────────────────────────────────────

  struct Decimals {
    uint8 usdx;
    uint8 dai;
    uint8 wbtc;
    uint8 usdy;
    uint8 weth;
    uint8 usdz;
  }

  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
    TestnetERC20 usdy;
    TestnetERC20 usdz;
  }

  struct SpokeInfo {
    ReserveInfo weth;
    ReserveInfo wbtc;
    ReserveInfo dai;
    ReserveInfo usdx;
    ReserveInfo usdy;
    ReserveInfo usdz;
    uint256 MAX_ALLOWED_ASSET_ID;
  }

  struct ReserveInfo {
    uint256 reserveId;
    ISpoke.ReserveConfig reserveConfig;
    ISpoke.DynamicReserveConfig dynReserveConfig;
  }

  /// @notice Debt data struct from Base.t.sol.
  struct Debts {
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 premiumDebtRay;
    uint256 totalDebt;
  }

  /// @notice Canonical debt data struct — merges Base.Debts and SpokeBase.DebtData.
  ///         Identical to Debts; prefer this name for new code.
  struct DebtData {
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 premiumDebtRay;
    uint256 totalDebt;
  }

  struct AssetPosition {
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 premium;
    uint40 lastUpdateTimestamp;
    uint256 liquidity;
    uint256 drawnIndex;
    uint256 drawnRate;
  }

  struct SpokePosition {
    uint256 reserveId;
    uint256 assetId;
    uint256 addedShares;
    uint256 addedAmount;
    uint256 drawnShares;
    uint256 drawn;
    uint256 premiumShares;
    int256 premiumOffsetRay;
    uint256 premium;
  }

  struct Reserve {
    uint256 reserveId;
    IHub hub;
    uint16 assetId;
    uint8 decimals;
    uint24 collateralRisk;
    bool paused;
    bool frozen;
    bool borrowable;
    bool receiveSharesEnabled;
    uint32 dynamicConfigKey;
  }

  // ──────────────────────────────────────────────────────────────
  //  SpokeBase structs
  // ──────────────────────────────────────────────────────────────

  struct TestData {
    SpokePosition data;
    uint256 addedAmount;
  }

  struct TestUserData {
    ISpoke.UserPosition data;
    uint256 suppliedAmount;
  }

  struct TokenData {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct TestReserve {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    address supplier;
    address borrower;
  }

  struct TestReturnValues {
    uint256 amount;
    uint256 shares;
  }

  struct UserActionData {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 userBalanceBefore;
    uint256 userBalanceAfter;
    ISpoke.UserPosition userPosBefore;
    uint256 premiumDebtRayBefore;
  }

  struct BorrowTestData {
    uint256 daiReserveId;
    uint256 wethReserveId;
    uint256 usdxReserveId;
    uint256 wbtcReserveId;
    UserActionData daiAlice;
    UserActionData wethAlice;
    UserActionData usdxAlice;
    UserActionData wbtcAlice;
    UserActionData daiBob;
    UserActionData wethBob;
    UserActionData usdxBob;
    UserActionData wbtcBob;
  }

  struct SupplyBorrowLocal {
    uint256 collateralReserveAssetId;
    uint256 borrowReserveAssetId;
    uint256 collateralSupplyShares;
    uint256 borrowSupplyShares;
    uint256 reserveSharesBefore;
    uint256 userSharesBefore;
    uint256 borrowerDrawnDebtBefore;
    uint256 reserveDrawnDebtBefore;
    uint256 borrowerDrawnDebtAfter;
    uint256 reserveDrawnDebtAfter;
  }

  struct RepayMultipleLocal {
    uint256 borrowAmount;
    uint256 repayAmount;
    ISpoke.UserPosition posBefore;
    ISpoke.UserPosition posAfter;
    uint256 baseRestored;
    uint256 premiumRestored;
  }

  struct CalculateRiskPremiumLocal {
    uint256 reserveCount;
    uint256 totalDebtValue;
    uint256 healthFactor;
    uint256 activeCollateralCount;
    uint32 dynamicConfigKey;
    uint256 collateralFactor;
    uint256 collateralValue;
    ISpoke.UserPosition pos;
    uint256 riskPremium;
    uint256 utilizedSupply;
    uint256 idx;
  }

  struct Action {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 repayAmount;
    uint40 skipTime;
  }

  struct AssetInfo {
    uint256 borrowAmount;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    uint256 suppliedShares;
  }

  struct UserAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
    uint256 suppliedShares;
    uint256 repayAmount;
    uint256 baseRestored;
    uint256 premiumRestored;
    address user;
  }

  struct UserBorrowAction {
    uint256 supplyAmount;
    uint256 borrowAmount;
  }

  struct UserAssetInfo {
    AssetInfo daiInfo;
    AssetInfo wethInfo;
    AssetInfo usdxInfo;
    AssetInfo wbtcInfo;
    address user;
  }

  struct ReserveIds {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
  }

  struct DynamicConfig {
    uint32 key;
    bool enabled;
  }

  // ──────────────────────────────────────────────────────────────
  //  HubBase structs
  // ──────────────────────────────────────────────────────────────

  struct TestAddParams {
    uint256 drawnAmount;
    uint256 drawnShares;
    uint256 assetAddedAmount;
    uint256 assetAddedShares;
    uint256 spoke1AddedAmount;
    uint256 spoke1AddedShares;
    uint256 spoke2AddedAmount;
    uint256 spoke2AddedShares;
    uint256 availableLiq;
    uint256 bobBalance;
    uint256 aliceBalance;
  }

  struct HubData {
    IHub.Asset daiData;
    IHub.Asset daiData1;
    IHub.Asset daiData2;
    IHub.Asset daiData3;
    IHub.Asset wethData;
    IHub.SpokeData spoke1WethData;
    IHub.SpokeData spoke1DaiData;
    IHub.SpokeData spoke2WethData;
    IHub.SpokeData spoke2DaiData;
    uint256 timestamp;
    uint256 accruedBase;
    uint256 initialLiquidity;
    uint256 initialAddShares;
    uint256 add2Amount;
    uint256 expectedAdd2Shares;
  }

  // ──────────────────────────────────────────────────────────────
  //  SpokeLiquidationCallBase structs
  // ──────────────────────────────────────────────────────────────

  struct CheckedLiquidationCallParams {
    ISpoke spoke;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    address user;
    uint256 debtToCover;
    address liquidator;
    bool isSolvent;
    bool receiveShares;
  }

  struct BalanceInfo {
    uint256 collateralErc20Balance;
    uint256 suppliedInSpoke;
    uint256 addedInHub;
    uint256 debtErc20Balance;
    uint256 borrowedFromSpoke;
    uint256 drawnFromHub;
  }

  struct AccountsInfo {
    ISpoke.UserAccountData userAccountData;
    BalanceInfo userBalanceInfo;
    BalanceInfo collateralHubBalanceInfo;
    BalanceInfo debtHubBalanceInfo;
    BalanceInfo liquidatorBalanceInfo;
    BalanceInfo collateralFeeReceiverBalanceInfo;
    BalanceInfo debtFeeReceiverBalanceInfo;
    BalanceInfo spokeBalanceInfo;
    uint256 userLastRiskPremium;
  }

  struct LiquidationMetadata {
    uint256 debtRayToTarget;
    uint256 collateralAssetsToLiquidate;
    uint256 collateralAssetsToLiquidator;
    uint256 collateralSharesToLiquidate;
    uint256 collateralSharesToLiquidator;
    uint256 debtAssetsToLiquidate;
    uint256 debtRayToLiquidate;
    uint256 drawnSharesToLiquidate;
    uint256 premiumDebtRayToLiquidate;
    uint256 debtAssetsToRestore;
    uint256 liquidationBonus;
    bool fullDebtReserveLiquidated;
    bool hasDeficit;
  }

  struct ExpectEventsAndCallsParams {
    uint256 userDrawnDebt;
    uint256 userPremiumDebt;
    uint256 drawnAmountToRestore;
    int256 realizedDelta;
    IHubBase.PremiumDelta premiumDelta;
    ISpoke.UserPosition userReservePosition;
    ISpoke.UserPosition userDebtPosition;
    IHub collateralHub;
    IHub debtHub;
    uint256 debtAssetId;
    uint256 collateralAssetId;
  }
}
