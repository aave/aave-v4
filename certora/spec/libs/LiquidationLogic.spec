/**
 * @title LiquidationLogic Library Specification
 * @notice Formal verification of LiquidationLogic._calculateLiquidationAmounts function.
 * @dev This spec verifies properties of liquidation amount calculations, ensuring correct handling of debt and collateral liquidation.
 *
 * Verification Scope:
 * - Balance constraints: Ensuring liquidation amounts do not exceed available balances.
 * - Value relationships: Verifying collateral and debt value relationships during liquidation.
 * - Debt priority: Ensuring premium debt is liquidated before drawn shares.
 */

import "../symbolicRepresentation/SymbolicHub.spec";
import "../common.spec";
import "../symbolicRepresentation/Math_CVL.spec";

using LiquidationLogicHarness as harness;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => LiquidationLogicBonusGhost;
    function SpokeUtils.toValue(uint256 amount, uint256 decimals, uint256 price) internal returns (uint256) => toValueCVL(amount, decimals, price);
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

ghost uint256 LiquidationLogicBonusGhost {
    axiom LiquidationLogicBonusGhost >= PERCENTAGE_FACTOR;
}

ghost uint256 computedDebtRayToLiquidateGhost;
ghost bool isDebtRayToLiquidateRecomputedGhost;

function store(uint256 val) returns (uint256) {
    computedDebtRayToLiquidateGhost = val;
    isDebtRayToLiquidateRecomputedGhost = true;
    return val;
}

ghost uint256 collateralToLiquidateRecomputedGhost;
ghost bool isCollateralToLiquidateRecomputedRecomputedGhost;

function storeCollateralToLiquidateRecomputed(uint256 val) returns (uint256) {
    collateralToLiquidateRecomputedGhost = val;
    isCollateralToLiquidateRecomputedRecomputedGhost = true;
    return val;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Sanity check - function can succeed
 */
rule sanityCheck() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    satisfy true;
}

/**
 * @title Debt to liquidate cannot exceed user's current debt shares
 * @link_property LiquidationLogic library integrity
 */
rule debtToLiquidateNotExceedBalance() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    assert result.drawnSharesToLiquidate <= params.drawnShares;
}

/**
 * @title Debt to liquidate (in assets) cannot exceed debt to cover
 * @link_property LiquidationLogic library integrity
 */
rule debtToLiquidateNotExceedDebtToCover() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    mathint debtAssetsToLiquidate = mulDivUpCVL(result.drawnSharesToLiquidate, params.drawnIndex, RAY);
    assert debtAssetsToLiquidate <= params.debtToCover;
}

/**
 * @title Collateral to liquidator cannot exceed collateral to liquidate
 * @link_property LiquidationLogic library integrity
 */
rule collateralToLiquidatorNotExceedTotal() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    assert result.collateralSharesToLiquidator <= result.collateralSharesToLiquidate;
    assert result.collateralSharesToLiquidate <= params.suppliedShares;
}


/**
 * @title Collateral to liquidate value less than debt to liquidate value
 * @notice Assumes liquidationBonus is none (PERCENTAGE_FACTOR)
 * @link_property LiquidationLogic library integrity
 */
rule collateralToLiquidateValueLessThanDebtToLiquidate() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;
    require params.debtAssetDecimals == 18;
    require params.collateralAssetDecimals == 18;
    require params.debtAssetPrice > 0;
    require params.collateralAssetPrice > 0;
    require params.drawnIndex >= RAY;

    // no bonus
    require LiquidationLogicBonusGhost == PERCENTAGE_FACTOR;

    // proved in Spoke.spec rule drawnSharesZero
    // liquidation also obeys this rule as if it returns all shares it returns all premium debt
    // rule: drawnSharesZeroed_premiumDebtRayZeroed
    require params.drawnShares == 0 => params.premiumDebtRay == 0;

    require params.totalDebtValueRay >= ((params.drawnShares * params.drawnIndex) + params.premiumDebtRay) * params.debtAssetPrice;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    mathint debtValueLiquidatedRay = (result.drawnSharesToLiquidate * params.drawnIndex + result.premiumDebtRayToLiquidate) * params.debtAssetPrice;

    mathint collateralValueLiquidatedRay = result.collateralSharesToLiquidate * shareToAssetsRatio[params.collateralReserveAssetId][e.block.timestamp] * params.collateralAssetPrice;

    assert collateralValueLiquidatedRay <= debtValueLiquidatedRay;
}



/**
 * @title Collateral to liquidate value less than debt to liquidate value (general case)
 * @notice Assumes liquidationBonus is none (PERCENTAGE_FACTOR)
 * @dev Handles different decimal configurations (12 + 16 decimals)
 * @link_property LiquidationLogic library integrity
 */
rule collateralToLiquidateValueLessThanDebtToLiquidate_general() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;
    require params.debtAssetDecimals == 12;
    require params.collateralAssetDecimals == 16;
    require params.debtAssetPrice > 0;
    require params.collateralAssetPrice > 0;
    require params.drawnIndex >= RAY;

    // no bonus
    require LiquidationLogicBonusGhost == PERCENTAGE_FACTOR;

    // proved in Spoke.spec rule drawnSharesZero
    // liquidation also obeys this rule as if it returns all shares it returns all premium debt
    // rule: drawnSharesZeroed_premiumDebtRayZeroed
    require params.drawnShares == 0 => params.premiumDebtRay == 0;

    require params.totalDebtValueRay >= ((params.drawnShares * params.drawnIndex) + params.premiumDebtRay) * params.debtAssetPrice;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    mathint debtValueLiquidatedRay = (((result.drawnSharesToLiquidate * params.drawnIndex) + result.premiumDebtRayToLiquidate) * params.debtAssetPrice) / limitedExp(10, params.debtAssetDecimals);

    mathint collateralValueLiquidatedRay = (result.collateralSharesToLiquidate * shareToAssetsRatio[params.collateralReserveAssetId][e.block.timestamp] * params.collateralAssetPrice) / limitedExp(10, params.collateralAssetDecimals);

    assert collateralValueLiquidatedRay <= debtValueLiquidatedRay;
}

/**
 * @title Drawn shares zeroed implies premium debt ray zeroed
 * @notice Proved in Spoke rule: drawnSharesZero
 * @link_property LiquidationLogic library integrity
 */
rule drawnSharesZeroed_premiumDebtRayZeroed() {
    env e;
    LiquidationLogic.CalculateLiquidationAmountsParams params;
    require params.debtAssetPrice > 0;
    require params.collateralAssetPrice > 0;
    require params.drawnIndex >= RAY;
    // proved in Spoke rule: drawnSharesZero
    require params.drawnShares == 0 => params.premiumDebtRay == 0;

    require params.totalDebtValueRay >= (mulDivUpCVL(params.drawnShares, params.drawnIndex, RAY) + divRayUpCVL(params.premiumDebtRay)) * params.debtAssetPrice;

    LiquidationLogic.LiquidationAmounts result = harness.calculateLiquidationAmounts(e, params);

    assert result.drawnSharesToLiquidate == params.drawnShares => result.premiumDebtRayToLiquidate == params.premiumDebtRay;
    // first repay all premium debt
    assert result.drawnSharesToLiquidate != 0 => result.premiumDebtRayToLiquidate == params.premiumDebtRay;
}

