// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubPostconditionsSpec} from '../../hub-suite/specs/HubPostconditionsSpec.t.sol';

/// @title PostconditionsSpec
/// @notice Postconditions specification for the protocol
/// @dev Contains spoke postcondition strings. Hub postcondition strings are inherited from HubPostconditionsSpec.
abstract contract PostconditionsSpec is HubPostconditionsSpec {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    SPOKE DEBT ORDERING                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_SP_B =
    'GPOST_SP_B: Premium debt of an individual user can only decrease by calling repay or liquidationCall when premium debt is not zero';

  string constant GPOST_SP_B2 =
    'GPOST_SP_B2: Drawn debt of an individual user can only decrease by calling repay or liquidationCall and if premium debt is zero after the action';

  string constant HSPOST_SP_C = 'HSPOST_SP_C: User liability should decrease after repayment';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      SPOKE RISK                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_SP_A =
    "GPOST_SP_A: Stored (user.premiumDrawnShares/user.baseDrawnShares) & calculated user risk premium (calculation based on user's position, via spoke.calculateUserAccountData) are the same right after an operation";

  string constant GPOST_SP_E =
    'GPOST_SP_E: DynamicRiskConfiguration for a user position is updated to latest reserve state whenever an action can potentially make their position less healthy';
  // - Updates on: borrow, withdraw, disableAsCollateral, updateUserDynamicConfig.
  // - Unchanged on: supply, repay, liquidate, updateUserRiskPremium, setUserPositionManager.
  // - Enabling collateral updates only the relevant reserve's dynamic config.

  string constant HSPOST_SP_F =
    'HSPOST_SP_F: Total debt of a user should not change after updateUserRiskPremium';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                    SPOKE SOLVENCY                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant HSPOST_SP_D = 'HSPOST_SP_D: Unhealthy user cannot borrow more';

  string constant GPOST_SP_H = 'GPOST_SP_H: Unhealthy user cannot withdraw active collateral';

  string constant HSPOST_SP_I =
    'HSPOST_SP_I: User is healthy after borrow/withdraw/updateUserDynamicConfig';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   SPOKE LIQUIDATION                                        //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant HSPOST_SP_LIQ_A =
    "HSPOST_SP_LIQ_A: Liquidation cannot result in an amount of liquidated debt > user's total debt position";

  string constant HSPOST_SP_LIQ_B =
    "HSPOST_SP_LIQ_B: Liquidation cannot result in an amount of seized collateral (sold collateral + liquidation bonus) > user's collateral position";

  string constant HSPOST_SP_LIQ_C =
    'HSPOST_SP_LIQ_C: Liquidator is always forced to repay all the debt of a user if debt value is below DUST_DEBT_LIQUIDATION_THRESHOLD';

  string constant HSPOST_SP_LIQ_D =
    'HSPOST_SP_LIQ_D: Liquidation cannot result in an amount of liquidated debt > debtToCover';

  string constant HSPOST_SP_LIQ_E = 'HSPOST_SP_LIQ_E: Only unhealthy user can be liquidated';

  string constant HSPOST_SP_LIQ_G =
    'HSPOST_SP_LIQ_G: After liquidation, if debt remains, health factor should improve toward target';

  string constant GPOST_SP_LIQ_G =
    'GPOST_SP_LIQ_G: Only liquidations can deteriorate the health factor of an already unhealthy account';

  string constant GPOST_SP_LIQ_H =
    'GPOST_SP_LIQ_H: Only a supply, repay, liquidationCall & updateUserRiskPremium can leave an account in an unhealthy state';
}
