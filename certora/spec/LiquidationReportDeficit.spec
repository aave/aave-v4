/**
 * @title Liquidation Report Deficit Specification
 * @notice Verify conditions under which deficit is reported during liquidation
 * @dev This spec verifies when deficit reporting occurs based on collateral and debt values
 */

import "./SpokeHealthFactor.spec";


////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // pure functions - safe to assume NONDET
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => bonusGhost;

    function LiquidationLogic._calculateDebtToTargetHealthFactor(LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) internal returns (uint256) => NONDET;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

ghost uint256 bonusGhost {
    axiom bonusGhost >= PERCENTAGE_FACTOR;
}



////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title More than one collateral - no report deficit
 * @link_property deficit reporting integrity
 */
rule moreThanOneCollateral_noReportDeficit(uint256 reserveId, address userLiquidated, address liquidator) {
    env e;
    setup();
    require e.msg.sender == liquidator;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;
    require currentTime == e.block.timestamp;
    require currentUser == userLiquidated;

    require !deficitReportedFlag;
    mathint collateralIDValueBefore = collateralIDValue(collateralReserveId_1);
    require totalCollateralValueGhost == collateralIDValueBefore + collateralIDValue(collateralReserveId_2) + collateralIDValue(collateralReserveId_3);

    mathint totalCollateralValueBefore = totalCollateralValueGhost;

    liquidationCall(e, collateralReserveId_1, debtReserveId, userLiquidated, debtToCover, receiveShares);
    assert totalCollateralValueBefore > collateralIDValueBefore => !deficitReportedFlag;
}


/**
 * @title More collateral than debt - no report deficit
 * @link_property deficit reporting integrity
 */
rule moreCollateralThenDebt_noReportDeficit(uint256 reserveId, address userLiquidated, address liquidator) {
    env e;
    setup();
    require e.msg.sender == liquidator;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;
    require currentTime == e.block.timestamp;
    require currentUser == userLiquidated;

    require !deficitReportedFlag;
    mathint debtValueBefore = totalDebtValueGhost;
    require totalCollateralValueGhost == collateralIDValue(collateralReserveId_1) + collateralIDValue(collateralReserveId_2) + collateralIDValue(collateralReserveId_3);
    require totalDebtValueGhost == debtIDValue(debtReserveId_1) + debtIDValue(debtReserveId_2) + debtIDValue(debtReserveId_3);

    mathint totalCollateralValueBefore = totalCollateralValueGhost;

    liquidationCall(e, collateralReserveId_1, debtReserveId, userLiquidated, debtToCover, receiveShares);
    assert totalCollateralValueBefore > debtValueBefore => !deficitReportedFlag;
}
