/**
 * @title Liquidation Specification
 * @notice Specification for liquidation operations and properties
 * @dev This spec verifies liquidation call properties including health factor checks, debt monotonicity, and account isolation.
 *
 * Verification Scope:
 * - Health factor validation: Healthy accounts cannot be liquidated.
 * - Debt monotonicity: Debt decreases during successful liquidation.
 * - Account isolation: Only the liquidated account's debt changes.
 * - Pause behavior: Liquidation fails when paused.
 */

import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicPositionStatus.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // based on spec LiquidationLogic_Bonus.spec
    function LiquidationLogic.calculateLiquidationBonus(uint256, uint256, uint256, uint256) internal returns (uint256) => NONDET;

    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory) => processUserAccountDataCVL(user, refreshConfig);

    // pure function - safe to assume NONDET
    function LiquidationLogic._calculateDebtToTargetHealthFactor(LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory) internal returns (uint256) => NONDET;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

persistent ghost mapping(address => uint256) ghostHealthFactor {
    init_state axiom forall address user. ghostHealthFactor[user] == 0;
}

////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

function processUserAccountDataCVL(address user, bool refreshConfig) returns (ISpoke.UserAccountData) {
    ISpoke.UserAccountData userAccountData;
    require userAccountData.healthFactor == ghostHealthFactor[user];
    require userAccountData.activeCollateralCount <= reserveCountGhost;
    return userAccountData;
}

definition HEALTH_FACTOR_LIQUIDATION_THRESHOLD() returns uint256 = 10 ^ 18;

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Sanity check - liquidation call can succeed
 */
rule sanityCheck() {
    env e;
    setup();
    calldataarg args;
    liquidationCall(e, args);
    satisfy true;
}

/**
 * @title Borrowing flag set if and only if drawn shares exist
 * @notice Assuming one user's borrowing flag is set at a time - proven in LiquidationUserIntegrity.spec
 * @link_property liquidation call integrity, borrowing flag integrity
 */
rule borrowingFlagSetIFFdrawnShares_liquidationCall(uint256 reserveId, address user) {
    env e;
    setup();
    require userGhost == user;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;

    require spoke._userPositions[user][reserveId].drawnShares > 0 <=> isBorrowing[user][reserveId];
    liquidationCall(e, collateralReserveId, debtReserveId, user, debtToCover, receiveShares);
    assert spoke._userPositions[user][reserveId].drawnShares > 0 <=> isBorrowing[user][reserveId];
}

/**
 * @title Healthy account cannot be liquidated
 * @link_property liquidation call integrity, health check validity
 */
rule healthyAccountCannotBeLiquidated(uint256 reserveId, address user) {
    env e;
    setup();
    require userGhost == user;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;
    require ghostHealthFactor[user] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    liquidationCall@withrevert(e, collateralReserveId, debtReserveId, user, debtToCover, receiveShares);
    assert lastReverted;
}   

/**
 * @title When paused (collateral or debt) then no liquidation
 * @link_property liquidation call integrity,pause behavior
 */
rule paused_noLiquidation(uint256 reserveId, address userLiquidated, address liquidator) {
    env e;
    setup();
    require e.msg.sender == liquidator;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;
    require liquidator != spoke._reserves[collateralReserveId].hub;
    require pausedGhost;
    liquidationCall@withrevert(e, collateralReserveId, debtReserveId, userLiquidated, debtToCover, receiveShares);
    assert lastReverted;
}

/**
 * @title Monotonicity of debt decrease during liquidation
 * @notice If collateral increases for the liquidator, then debt must decrease for the liquidated user
 * @link_property liquidation call integrity
 */
rule monotonicityOfDebtDecrease_collateralIncrease(uint256 reserveId, address userLiquidated, address liquidator) {
    env e;
    setup();
    require e.msg.sender == liquidator;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;
    require liquidator != spoke._reserves[collateralReserveId].hub;

    require spoke._userPositions[userLiquidated][debtReserveId].drawnShares > 0 <=> isBorrowing[userLiquidated][debtReserveId];

    address underlyingCollateral = spoke._reserves[collateralReserveId].underlying;
    require underlyingCollateral == assetUnderlying[spoke._reserves[collateralReserveId].assetId];

    uint256 beforeDrawnShares = spoke._userPositions[userLiquidated][debtReserveId].drawnShares;
    uint256 beforeUnderlyingCollateralBalance = tokenBalanceOf(underlyingCollateral, liquidator);
    uint256 beforeCollateral = spoke._userPositions[liquidator][collateralReserveId].suppliedShares;

    mathint beforePremiumDebt = (spoke._userPositions[userLiquidated][debtReserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[debtReserveId].assetId, e)) - spoke._userPositions[userLiquidated][debtReserveId].premiumOffsetRay;

    liquidationCall(e, collateralReserveId, debtReserveId, userLiquidated, debtToCover, receiveShares);

    uint256 afterDrawnShares = spoke._userPositions[userLiquidated][debtReserveId].drawnShares;
    uint256 afterUnderlyingCollateralBalance = tokenBalanceOf(underlyingCollateral, liquidator);
    uint256 afterCollateral = spoke._userPositions[liquidator][collateralReserveId].suppliedShares;

    mathint afterPremiumDebt = (spoke._userPositions[userLiquidated][debtReserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[debtReserveId].assetId, e)) - spoke._userPositions[userLiquidated][debtReserveId].premiumOffsetRay;

    assert (beforeCollateral < afterCollateral || beforeUnderlyingCollateralBalance < afterUnderlyingCollateralBalance) =>
           (afterDrawnShares < beforeDrawnShares || afterPremiumDebt < beforePremiumDebt);
    satisfy (beforeCollateral < afterCollateral || beforeUnderlyingCollateralBalance < afterUnderlyingCollateralBalance);
}   



/**
 * @title No change to other accounts during liquidation
 * @notice In the liquidated account debt can be decreased to zero on report deficit, however other collateral cannot change at all
 * @link_property liquidation call integrity
 */
rule noChangeToOtherAccounts_liquidationCall(uint256 reserveId, address userLiquidated, address liquidator, address user) {
    env e;
    setup();
    require e.msg.sender == liquidator;
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 debtToCover;
    bool receiveShares;

    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    liquidationCall(e, collateralReserveId, debtReserveId, userLiquidated, debtToCover, receiveShares);

    assert spoke._userPositions[user][reserveId].drawnShares != drawnSharesBefore => (user == userLiquidated);
    assert spoke._userPositions[user][reserveId].premiumShares != premiumSharesBefore => (user == userLiquidated);
    assert spoke._userPositions[user][reserveId].premiumOffsetRay != premiumOffsetRayBefore => (user == userLiquidated);
    assert spoke._userPositions[user][reserveId].suppliedShares != suppliedSharesBefore =>
            (reserveId == collateralReserveId &&
             ((user == userLiquidated && spoke._userPositions[user][reserveId].suppliedShares < suppliedSharesBefore) ||
              (user == liquidator && spoke._userPositions[user][reserveId].suppliedShares > suppliedSharesBefore && receiveShares && !frozenGhost)));
}