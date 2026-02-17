// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title TestTypes
/// @notice Canonical shared struct definitions for the Aave V4 test suite.
///         All test base contracts inherit from here to avoid duplicate definitions.
abstract contract TestTypes {
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

  struct SharesAndAmount {
    uint256 amount;
    uint256 shares;
  }

  struct TokenBalances {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct ReserveSetupParams {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    address supplier;
    address borrower;
  }

  struct DynamicConfigEntry {
    uint32 key;
    bool enabled;
  }

  struct ReserveIds {
    uint256 dai;
    uint256 weth;
    uint256 usdx;
    uint256 wbtc;
  }
}
