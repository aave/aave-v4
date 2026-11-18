/**
 * @title LiquidationLogic_debtToLiquidate Library Specification
 * @notice Formal verification of LiquidationLogic.calculateDebtToLiquidate function.
 * @dev This spec verifies properties of debt liquidation calculations, ensuring correct handling of drawn shares and premium debt.
 *
 * Verification Scope:
 * - Balance constraints: Ensuring debt to liquidate does not exceed available balances.
 * - Priority ordering: Verifying that premium debt is liquidated before drawn shares.
 */

import "../common.spec";
import "../symbolicRepresentation/Math_CVL.spec";

using LiquidationLogicHarness as harness;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function calculateDebtToLiquidate(
        LiquidationLogic.CalculateDebtToLiquidateParams params
    ) external returns (uint256, uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Sanity check for calculateDebtToLiquidate
 * @link_property LiquidationLogic library integrity
 */
rule sanityCheck() {
    LiquidationLogic.CalculateDebtToLiquidateParams params;
    uint256 drawnShares;
    uint256 premiumDebt;
    (drawnShares, premiumDebt) = harness.calculateDebtToLiquidate(params);
    satisfy true;
}

/**
 * @title Verify that debt to liquidate does not exceed balance
 * @link_property LiquidationLogic library integrity
 */
rule debtToLiquidateNotExceedBalance() {
    LiquidationLogic.CalculateDebtToLiquidateParams params;

    uint256 drawnShares;
    uint256 premiumDebt;
    (drawnShares, premiumDebt) = harness.calculateDebtToLiquidate(params);

    assert drawnShares <= params.drawnShares;
    assert premiumDebt <= params.premiumDebtRay;
}

/**
 * @title Verify that premium debt is liquidated first
 * @notice If drawnSharesToLiquidate > 0, then premiumDebtRayToLiquidate must equal params.premiumDebtRay
 * @link_property LiquidationLogic library integrity
 */
rule premiumDebtLiquidatedFirst() {
    LiquidationLogic.CalculateDebtToLiquidateParams params;

    uint256 drawnShares;
    uint256 premiumDebt;
    (drawnShares, premiumDebt) = harness.calculateDebtToLiquidate(params);

    assert drawnShares > 0 => premiumDebt == params.premiumDebtRay;
}
