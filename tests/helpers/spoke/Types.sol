// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title Types
/// @notice Shared struct definitions for spoke-level test helpers.
abstract contract Types {
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

  struct DynamicConfigEntry {
    uint32 key;
    bool enabled;
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

  struct ReserveSetupParams {
    uint256 reserveId;
    uint256 supplyAmount;
    uint256 borrowAmount;
    address supplier;
    address borrower;
  }

  struct TokenBalances {
    uint256 spokeBalance;
    uint256 hubBalance;
  }

  struct SharesAndAmount {
    uint256 amount;
    uint256 shares;
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

  struct UserSnapshot {
    uint256 tokenBalance;
    uint256 suppliedShares;
    uint256 suppliedAmount;
    uint256 drawnDebt;
    uint256 premiumDebt;
    uint256 totalDebt;
    ISpoke.UserPosition position;
  }

  struct ReserveSnapshot {
    uint256 totalSuppliedShares;
    uint256 totalSuppliedAmount;
    uint256 totalDrawnDebt;
    uint256 totalPremiumDebt;
    uint256 totalDebt;
  }
}
