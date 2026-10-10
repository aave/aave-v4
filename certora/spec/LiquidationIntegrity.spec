/**
 * @title Liquidation Integrity Specification
 * @notice Verify that what returned from calculateLiquidationAmounts is the actual change to the user position
 * @dev This spec ensures that the liquidation amounts calculated match the actual state changes
 */

import "./Liquidation.spec";


////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function LiquidationLogic._calculateLiquidationAmounts(LiquidationLogic.CalculateLiquidationAmountsParams memory params) internal returns (LiquidationLogic.LiquidationAmounts memory) => calculateLiquidationAmountsCVL(params);
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

ghost uint256 ghostDrawnSharesToLiquidate;
ghost uint256 ghostPremiumDebtRayToLiquidate;
ghost uint256 ghostCollateralSharesToLiquidate;
ghost uint256 ghostCollateralSharesToLiquidator;
ghost bool totalMoreThanDebtValue;

////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////


definition premiumDebtCVL(address user, uint256 reserveId, env e) returns mathint =
    (spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e)) - spoke._userPositions[user][reserveId].premiumOffsetRay;


function calculateLiquidationAmountsCVL(LiquidationLogic.CalculateLiquidationAmountsParams params) returns (LiquidationLogic.LiquidationAmounts) {
    LiquidationLogic.LiquidationAmounts result;
    require result.drawnSharesToLiquidate == ghostDrawnSharesToLiquidate;
    require result.premiumDebtRayToLiquidate == ghostPremiumDebtRayToLiquidate;
    require result.collateralSharesToLiquidate == ghostCollateralSharesToLiquidate;
    require result.collateralSharesToLiquidator == ghostCollateralSharesToLiquidator;
    // rule drawnSharesZeroed_premiumDebtRayZeroed in LiquidationLogic.spec
    require params.drawnShares == ghostDrawnSharesToLiquidate => params.premiumDebtRay == ghostPremiumDebtRayToLiquidate;

    uint256 debtInAssets = require_uint256(mulDivUpCVL(params.drawnShares, params.drawnIndex, RAY) + divRayUpCVL(params.premiumDebtRay));
    mathint debtValue = toValueCVL(debtInAssets, params.debtAssetDecimals, params.debtAssetPrice);
    if (params.totalDebtValueRay < debtValue) {
        totalMoreThanDebtValue = true;
    }

    return result;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Liquidation integrity - calculated amounts match actual state changes
 * @link_property liquidation call integrity
 */
rule liquidationIntegrity(uint256 reserveId, address userLiquidated) {
    env e;
    setup();
    // help grounding
    uint256 nextBorrowingId = nextBorrowingCVL(spoke._reserveCount);
    require nextBorrowingId == reserveId || reserveId == nextBorrowingCVL(spoke._reserveCount);

    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;

    require reserveId == debtReserveId;
    require !deficitReportedFlag;

    uint256 drawnSharesBefore = spoke._userPositions[userLiquidated][debtReserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[userLiquidated][debtReserveId].premiumShares;
    mathint premiumOffsetRayBefore = premiumDebtCVL(userLiquidated, debtReserveId, e);
    uint256 suppliedSharesBefore = spoke._userPositions[userLiquidated][collateralReserveId].suppliedShares;

    liquidationCall(e, collateralReserveId, debtReserveId, userLiquidated, debtToCover, receiveShares);

    // in case of no report deficit, the drawn shares and premium debt should reduce by exactly the returned value from calculateLiquidationAmounts
    assert !deficitReportedFlag => spoke._userPositions[userLiquidated][debtReserveId].drawnShares == (drawnSharesBefore - ghostDrawnSharesToLiquidate);
    assert !deficitReportedFlag => premiumDebtCVL(userLiquidated, debtReserveId, e) == (premiumOffsetRayBefore - ghostPremiumDebtRayToLiquidate);
    // in case of report deficit, the drawn shares and premium debt should be zero
    assert deficitReportedFlag => premiumDebtCVL(userLiquidated, debtReserveId, e) == 0 && spoke._userPositions[userLiquidated][debtReserveId].drawnShares == 0;
    // the collateral shares should reduce by exactly the returned value from calculateLiquidationAmounts
    assert spoke._userPositions[userLiquidated][collateralReserveId].suppliedShares == (suppliedSharesBefore - ghostCollateralSharesToLiquidate);
}
