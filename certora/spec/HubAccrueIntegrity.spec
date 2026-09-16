/**
 * @title Hub Accrue Integrity Specification
 * @notice Prove unit test properties of AssetLogic.accrue() function
 * @dev This is proven on HubHarness which exposes accrue() as an external function
 */

import "./HubBase.spec";

using HubHarness as hub;
using MathWrapper as mathWrapper;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // envfree functions
    function mathWrapper.SECONDS_PER_YEAR() external returns (uint256) envfree;
}


////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

definition emptyAsset(uint256 assetId) returns bool =
    hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].liquidity == 0 &&
        hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].deficitRay == 0 &&
        hub._assets[assetId].swept == 0 &&
        hub._assets[assetId].premiumShares == 0 &&
        hub._assets[assetId].premiumOffsetRay == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].drawnIndex == 0 &&
        hub._assets[assetId].drawnRate == 0 &&
        hub._assets[assetId].lastUpdateTimestamp == 0 &&
        ( forall address spoke. 
            hub._spokes[assetId][spoke].addedShares == 0 &&
            hub._spokes[assetId][spoke].drawnShares == 0 &&
            hub._spokes[assetId][spoke].premiumShares == 0  &&
            hub._spokes[assetId][spoke].premiumOffsetRay == 0 
        ) && 
        hub._assets[assetId].underlying == 0;



////////////////////////////////////////////////////////////////////////////
//                                  RULES                                 //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Two invocations of accrue() at the same block result in a state exactly the same as the first execution
 * @link_property accrue integrity
 */
rule runningTwiceIsEquivalentToOne() {
    env e;
    uint256 assetId;
    accrueInterest(e, assetId);
    storage afterOne = lastStorage;
    accrueInterest(e, assetId);
    assert lastStorage == afterOne;
}

/**
 * @title Once baseDebtIndex is set it is at least RAY
 * @notice Proved also in invariant baseDebtIndexMin on all Hub functions
 * @link_property accrue integrity
 */
rule baseDebtIndexMin_accrue() {
    env e;
    uint256 assetId;
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= RAY;

    accrueInterest(e, assetId);
    assert hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= RAY;
}

/**
 * @title lastUpdateTimestamp is updated to the current block timestamp
 * @link_property accrue integrity
 */
rule lastUpdateTimestamp_updatedToCurrentBlockTimestamp() {
    env e;
    uint256 assetId;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;
    accrueInterest(e, assetId);
    assert hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp;
}


/**
 * @title When accrue is called, no change to other fields beside lastUpdateTimestamp, drawnIndex and realizedFees 
 * @link_property accrue integrity
 */
rule noChangeToOtherFields_accrue(uint256 assetId) {
    env e;
    storage beforeStorage = lastStorage;
    uint256 beforeTimestamp = hub._assets[assetId].lastUpdateTimestamp;
    uint256 beforeIndex = hub._assets[assetId].drawnIndex;
    uint256 beforeRealizedFees = hub._assets[assetId].realizedFees;

    accrueInterest(e, assetId);
    havoc hub._assets[assetId].lastUpdateTimestamp;
    havoc hub._assets[assetId].drawnIndex;
    havoc hub._assets[assetId].realizedFees;
    require hub._assets[assetId].lastUpdateTimestamp == beforeTimestamp;
    require hub._assets[assetId].drawnIndex == beforeIndex;
    require hub._assets[assetId].realizedFees == beforeRealizedFees;
    assert lastStorage == beforeStorage;
}

/**
 * @title BaseDebtIndex is increasing on block change when baseRate is at least SECONDS_PER_YEAR and index is set
 * @assumption baseRate is at least SECONDS_PER_YEAR
 * @link_property accrue integrity
 */
rule baseDebtIndex_increasing(uint256 assetId) {
    // Proved in invariant baseDebtIndexMin and baseDebtIndexMin_accrue
    require hub._assets[assetId].drawnIndex >= RAY;

    uint256 before = hub._assets[assetId].drawnIndex;

    env e;
    require e.block.timestamp > hub._assets[assetId].lastUpdateTimestamp && e.block.timestamp <= max_uint40;
    mathint baseShareAndPremium = hub._assets[assetId].drawnShares + hub._assets[assetId].premiumShares;

    accrueInterest(e, assetId);

    assert hub._assets[assetId].drawnIndex >= before;
    // If there is debt then the drawnIndex should not increase
    assert (hub._assets[assetId].drawnRate >= mathWrapper.SECONDS_PER_YEAR()
            // Debt is not only the unpaid non interest bearing premium debt
            && baseShareAndPremium != 0) =>
            hub._assets[assetId].drawnIndex > before;
    satisfy hub._assets[assetId].drawnRate == mathWrapper.SECONDS_PER_YEAR();
}

/**
 * @title Prove premiumOffsetRay is always less than or equal to premiumShares * drawnIndex 
 * @notice This is important to avoid revert on accrue
 * @link_property accrue integrity
 */
rule premiumOffset_Integrity_accrue(uint256 assetId, address spokeId) {
    env e;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;

    // requireInvariant baseDebtIndexMin(assetId);
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= RAY;

    require hub._assets[assetId].premiumShares * hub._assets[assetId].drawnIndex >= hub._assets[assetId].premiumOffsetRay &&
            hub._spokes[assetId][spokeId].premiumShares * hub._assets[assetId].drawnIndex >= hub._spokes[assetId][spokeId].premiumOffsetRay;

    accrueInterest(e, assetId);

    assert hub._assets[assetId].premiumShares * hub._assets[assetId].drawnIndex >= hub._assets[assetId].premiumOffsetRay &&
           hub._spokes[assetId][spokeId].premiumShares * hub._assets[assetId].drawnIndex >= hub._spokes[assetId][spokeId].premiumOffsetRay;
}

/**
 * @title View functions are isomorphic to accrue, they return the same value if accrue was called or not
 * @link_property view functions integrity
 */
rule viewFunctionsIntegrity(uint256 assetId, method f) filtered { f-> f.isView &&
                                f.selector != sig:authority().selector &&
                                f.selector != sig:isConsumingScheduledOp().selector &&
                                f.selector != sig:isSpokeListed(uint256,address).selector &&
                                // returns a struct 
                                f.selector != sig:getAsset(uint256).selector &&
                                f.selector != sig:getAssetConfig(uint256).selector &&
                                f.selector != sig:getSpoke(uint256,address).selector &&
                                f.selector != sig:getSpokeConfig(uint256,address).selector &&
                                f.selector != sig:getSpokeAddress(uint256,uint256).selector &&
                                // harness functions
                                f.selector != sig:toSharesDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toSharesUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:getUnrealizedFees(uint256).selector &&
                                f.selector != sig:MAX_ALLOWED_UNDERLYING_DECIMALS().selector &&
                                f.selector != sig:MAX_ALLOWED_SPOKE_CAP().selector &&
                                f.selector != sig:MAX_RISK_PREMIUM_THRESHOLD().selector &&
                                f.selector != sig:getAssetUnderlyingAndDecimals(uint256).selector 
                                }
{
    env e;
    calldataarg args;

    // lastUpdateTimestamp cannot be in the future, prove...
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;

    // requireInvariant baseDebtIndexMin(assetId);
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= RAY;

    mathint ret_withAccrue = callViewFunction(f, e, args);

    // Accrue before calling the view function
    accrueInterest(e, assetId);

    mathint ret_withoutAccrue = callViewFunction(f, e, args);
    assert ret_withAccrue == ret_withoutAccrue;
}


/**
 * @title View functions revert under the same state if accrue is called or not called before the view function is called
 * @link_property view functions integrity
 */
rule viewFunctionsRevertIntegrity(uint256 assetId, method f) filtered { f-> f.isView &&
                                f.selector != sig:authority().selector &&
                                f.selector != sig:isConsumingScheduledOp().selector &&
                                f.selector != sig:isSpokeListed(uint256,address).selector &&
                                // returns a struct 
                                f.selector != sig:getAsset(uint256).selector &&
                                f.selector != sig:getAssetConfig(uint256).selector &&
                                f.selector != sig:getSpoke(uint256,address).selector &&
                                f.selector != sig:getSpokeConfig(uint256,address).selector &&
                                f.selector != sig:getSpokeAddress(uint256,uint256).selector &&
                                // harness functions
                                f.selector != sig:toSharesDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsDown(uint256,uint256,uint256).selector &&
                                f.selector != sig:toSharesUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:toAssetsUp(uint256,uint256,uint256).selector &&
                                f.selector != sig:getUnrealizedFees(uint256).selector &&
                                f.selector != sig:MAX_ALLOWED_UNDERLYING_DECIMALS().selector &&
                                f.selector != sig:MAX_ALLOWED_SPOKE_CAP().selector &&
                                f.selector != sig:MAX_RISK_PREMIUM_THRESHOLD().selector &&
                                f.selector != sig:getAssetUnderlyingAndDecimals(uint256).selector 
                                }
{
    env e;
    calldataarg args;

    // lastUpdateTimestamp cannot be in the future, prove...
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;

    // requireInvariant baseDebtIndexMin(assetId);
    require hub._assets[assetId].drawnIndex == 0 || hub._assets[assetId].drawnIndex >= RAY;

    f(e, args);

    // Accrue before calling the view function
    accrueInterest(e, assetId);
    f@withrevert(e, args);
    assert !lastReverted;
}


////////////////////////////////////////////////////////////////////////////
//                              HELPER FUNCTIONS                          //
////////////////////////////////////////////////////////////////////////////

/**
 * @notice Helper function for calling view functions and fetching the return value as mathint
 */
function callViewFunction(method f, env e, calldataarg args) returns mathint {
    if (f.selector == sig:getAssetCount().selector) {
        return getAssetCount(e, args);
    }
    else if (f.selector == sig:getSpokeCount(uint256).selector) {
        return getSpokeCount(e, args);
    }
    else if (f.selector == sig:previewAddByAssets(uint256,uint256).selector) {
        return previewAddByAssets(e, args);
    }
    else if (f.selector == sig:previewAddByShares(uint256,uint256).selector) {
        return previewAddByShares(e, args);
    }
    else if (f.selector == sig:previewRemoveByAssets(uint256,uint256).selector) {
        return previewRemoveByAssets(e, args);
    }
    else if (f.selector == sig:previewRemoveByShares(uint256,uint256).selector) {
        return previewRemoveByShares(e, args);
    }
    else if (f.selector == sig:previewDrawByAssets(uint256,uint256).selector) {
        return previewDrawByAssets(e, args);
    }
    else if (f.selector == sig:previewDrawByShares(uint256,uint256).selector) {
        return previewDrawByShares(e, args);
    }
    else if (f.selector == sig:previewRestoreByAssets(uint256,uint256).selector) {
        return previewRestoreByAssets(e, args);
    }
    else if (f.selector == sig:previewRestoreByShares(uint256,uint256).selector) {
        return previewRestoreByShares(e, args);
    }
    else if (f.selector == sig:getAssetDrawnIndex(uint256).selector) {
        return getAssetDrawnIndex(e, args);
    }
    else if (f.selector == sig:getAssetOwed(uint256).selector) {
        uint256 a; uint256 b; (a, b) = getAssetOwed(e, args); return a + b;
    }
    else if (f.selector == sig:getAssetTotalOwed(uint256).selector) {
        return getAssetTotalOwed(e, args);
    }
    else if (f.selector == sig:getSpokeOwed(uint256,address).selector) {
        uint256 a; uint256 b; (a, b) = getSpokeOwed(e, args); return a + b;
    }
    else if (f.selector == sig:getSpokeTotalOwed(uint256,address).selector) {
        return getSpokeTotalOwed(e, args);
    }
    else if (f.selector == sig:getAssetDrawnRate(uint256).selector) {
        return getAssetDrawnRate(e, args);
    }
    else if (f.selector == sig:getAddedAssets(uint256).selector) {
        return getAddedAssets(e, args);
    }
    else if (f.selector == sig:getAddedShares(uint256).selector) {
        return getAddedShares(e, args);
    }
    else if (f.selector == sig:getSpokeAddedAssets(uint256,address).selector) {
        return getSpokeAddedAssets(e, args);
    }
    else if (f.selector == sig:getSpokeAddedShares(uint256,address).selector) {
        return getSpokeAddedShares(e, args);
    }
    else if (f.selector == sig:getAssetDrawnShares(uint256).selector) {
        return getAssetDrawnShares(e, args);
    }
    else if (f.selector == sig:getAssetPremiumData(uint256).selector) {
        uint256 a; int256 b; 
        (a, b) = getAssetPremiumData(e, args); 
        return a + to_mathint(b);
    }
    else if (f.selector == sig:getSpokePremiumData(uint256,address).selector) {
        uint256 a; int256 b; 
        (a, b) = getSpokePremiumData(e, args); 
        return a + to_mathint(b);
    }
    else if (f.selector == sig:getAssetPremiumRay(uint256).selector) {
        return getAssetPremiumRay(e, args);
    }
    else if (f.selector == sig:getSpokePremiumRay(uint256,address).selector) {
        return getSpokePremiumRay(e, args);
    }
    else if (f.selector == sig:getSpokeDrawnShares(uint256,address).selector) {
        return getSpokeDrawnShares(e, args);
    }
    else if (f.selector == sig:MIN_ALLOWED_UNDERLYING_DECIMALS().selector) {
        return MIN_ALLOWED_UNDERLYING_DECIMALS(e, args);
    }
    else if (f.selector == sig:getAssetDeficitRay(uint256).selector) {
        return getAssetDeficitRay(e, args);     
    }
    else if (f.selector == sig:getAssetLiquidity(uint256).selector) {
        return getAssetLiquidity@withrevert(e, args); 
    
    }
    else if (f.selector == sig:getAssetSwept(uint256).selector) {
        return getAssetSwept(e, args);  
    }
    else if (f.selector == sig:getSpokeDeficitRay(uint256,address).selector) {
        return getSpokeDeficitRay(e, args);
    }
    else if (f.selector == sig:getAssetAccruedFees(uint256).selector) {
        return getAssetAccruedFees(e, args);
    }
    else if (f.selector == sig:isUnderlyingListed(address).selector) {
        return isUnderlyingListed(e, args) ? 1 : 0;
    }
    else if (f.selector == sig:getAssetId(address).selector) {
        return getAssetId(e, args);
    }
    else
    {
        assert false, "unknown view function";
        return 0;
    }

}
