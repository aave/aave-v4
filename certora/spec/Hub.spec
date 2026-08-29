
/**
 * @title Hub Contract Specification
 * @notice State change rules in which the validate functions are ignored
 * @dev Assumes accrue has been called on the current block timestamp
 * @assumptions ERC20s are standard tokens, specifically, no fees on transfer and no callbacks
 */

import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./HubValidState.spec";

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function Hub._validateAdd(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 amount
    ) internal => NONDET;

    function Hub._validateRemove(
        IHub.SpokeData storage spoke,
        uint256 amount,
        address to
    ) internal => NONDET;

    function Hub._validateDraw(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 amount,
        address to
    ) internal => NONDET;

    function Hub._validateRestore(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 drawnAmount,
        uint256 premiumAmountRay
    ) internal => NONDET;

    function Hub._validateReportDeficit(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 drawnAmount,
        uint256 premiumAmountRay
    ) internal => NONDET;

    function Hub._validateEliminateDeficit(
        IHub.SpokeData storage spoke,
        uint256 amount
    ) internal => NONDET;

    function Hub._validatePayFeeShares(
        IHub.SpokeData storage senderSpoke,
        uint256 feeShares
    ) internal => NONDET;

    function Hub._validateTransferShares(
        IHub.Asset storage asset,
        IHub.SpokeData storage sender,
        IHub.SpokeData storage receiver,
        uint256 shares
    ) internal => NONDET;

    function Hub._validateSweep(
        IHub.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;

    function Hub._validateReclaim(
        IHub.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Supply rate is never decreasing
 * @notice When not accruing interest, every function should never decrease supply exchange rate
 * @safe_assumptions accrue has been called on the current block timestamp
 * supply exchange rate is monotonic increasing on accrue: proved in HubAccrueSupplyRate.spec 
 * @safe_assumption accrue is called before updating shares or debt: proved in rule accrueWasCalled
 * @link_property share rate integrity

 */
rule supplyExchangeRateIsMonotonic(env e, method f, calldataarg args)
filtered {
    f -> !f.isView && f.selector != sig:eliminateDeficit(uint256,uint256,address).selector
}
{
    uint256 assetId;
    uint256 OneM = 1000000;

    requireAllInvariants(assetId, e);
    // use ghost to avoid repeating complex computation
    mathint assetsBefore = addedAssetsBefore;
    mathint sharesBefore = addedSharesBefore;

    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 

    f(e, args);

    mathint assetsAfter = getAddedAssets(e,assetId);
    mathint sharesAfter = getAddedShares(e,assetId);
    require assetsAfter >= sharesAfter, "based on rule totalAssetsVsShares(assetId,e) and to help the prover";
    assert (assetsAfter + OneM) * (sharesBefore + OneM) >= (assetsBefore + OneM) * (sharesAfter + OneM);
}

// looking only at the deficit ray of the asset as other assets parts are assumed to be unchanged
rule supplyExchangeRateIsMonotonic_eliminateDeficit_simplified(uint256 assetId, env e) {
    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 
    requireAllInvariants(assetId, e);
    address spokeId;
    uint256 OneM = 1000000;
    mathint assetsBefore = addedAssetsBefore;
    mathint deficitBefore = divRayUpCVL(hub._assets[assetId].deficitRay);
    require assetsBefore == deficitBefore;
    mathint sharesBefore = addedSharesBefore;

    
    uint256 amount;
    require amount * RAY == hub._spokes[assetId][spokeId].deficitRay; 
    eliminateDeficit(e, assetId, amount, spokeId);
    mathint deficitAfter = divRayUpCVL(hub._assets[assetId].deficitRay);
    mathint sharesAfter = getAddedShares(e,assetId);
    assert (deficitAfter + OneM) * (sharesBefore + OneM) >= (deficitBefore + OneM) * (sharesAfter + OneM);
}

/**
 * @title Can only increase a spoke's asset or decrease debt
 * @notice Assumes accrue has been called
 * @safe_assumption accrue does not change any values beside asset level : noChangeToOtherFields_accrue 
 * @link_property valid state changes 
 */
rule noChangeToOtherSpoke(address spoke, uint256 assetId, address otherSpoke, method f) 
    filtered { f -> !f.isView }
    {
    env e;
    
    require otherSpoke != spoke && e.msg.sender == spoke; 
    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 
    requireAllInvariants(assetId, e);
    
    
    uint256 shares_ = getSpokeAddedShares(e, assetId, otherSpoke);
    uint256 deficit_ = getSpokeDeficitRay(e, assetId, otherSpoke);
    uint256 drawnShares_  = getSpokeDrawnShares(e, assetId, otherSpoke);
    uint256 premiumShares_; int256 premiumOffset_;
    premiumShares_, premiumOffset_ = getSpokePremiumData(e, assetId, otherSpoke);


    calldataarg args; 
    f(e,args);
    
    // shares can increase on feeReceiver or transferShares function 
    assert shares_ <= getSpokeAddedShares(e, assetId, otherSpoke);
    // deficit can decrease on eliminateDeficit function
    assert deficit_ >= getSpokeDeficitRay(e, assetId, otherSpoke);
    // drawn shares can not change
    assert drawnShares_ == getSpokeDrawnShares(e, assetId, otherSpoke);
    // premium shares and offset can not change
    uint256 premiumSharesAfter; int256 premiumOffsetAfter;
    premiumSharesAfter, premiumOffsetAfter = getSpokePremiumData(e, assetId, otherSpoke);
    assert premiumShares_ == premiumSharesAfter;
    assert premiumOffset_ == premiumOffsetAfter;
}

/**
 * @title Accrue must be called before updating shares or debt
 * @notice Transferring shares is safe without accrue, as it stays the same behavior.
 * Also adding an asset is safe without accrue, as there is nothing to update.
 * @link_property accrue integrity 
 */
rule accrueWasCalled(uint256 assetId, method f) filtered { f-> !f.isView && 
            f.selector != sig:addAsset(address,uint8,address,address,bytes).selector &&
            f.selector != sig:transferShares(uint256,uint256,address).selector}  
{
    require !unsafeAccessBeforeAccrue; 
    
    env e;
    calldataarg args;
    f(e,args);

    assert !unsafeAccessBeforeAccrue; 

}

/**
 * @title lastUpdateTimestamp is never updated if accrue was called already
 * @link_property lastUpdateTimestamp state change
 */
rule lastUpdateTimestamp_notChanged(uint256 assetId, method f) filtered { f-> !f.isView} {
    env e;
    uint before = hub._assets[assetId].lastUpdateTimestamp;
    
    calldataarg args;
    f(e,args);

    assert hub._assets[assetId].lastUpdateTimestamp == before || ( hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp && f.selector == sig:addAsset(address,uint8,address,address,bytes).selector);


}

/**
 * @title Total assets is equal to the supplied amount when taking into account the virtual assets and shares
 * @link_property preview functions integrity 
 */
rule totalAssetsCompareToSuppliedAmount_virtual(uint256 assetId, env e){
    requireAllInvariants(assetId, e); 
    uint256 oneM = 1000000;
    
    mathint addedAssets = getAddedAssets(e,assetId) + oneM;
    mathint addedShares = getAddedShares(e,assetId) + oneM;

    // rounding down
    assert addedAssets == previewRemoveByShares(e, assetId, require_uint256(addedShares));
    // rounding up
    assert addedAssets == previewAddByShares(e, assetId, require_uint256(addedShares));
}

/**
 * @title Total assets is equal to or greater than the supplied amount without taking into account the virtual assets and shares
 * @link_property preview functions integrity 
 */
rule totalAssetsCompareToSuppliedAmount_noVirtual(uint256 assetId, env e){
    requireAllInvariants(assetId, e); 
    mathint addedAssets = getAddedAssets(e,assetId);
    mathint addedShares = getAddedShares(e,assetId);

    assert addedAssets >= previewRemoveByShares(e, assetId, require_uint256(addedShares));
    satisfy addedAssets > previewRemoveByShares(e, assetId, require_uint256(addedShares));
    assert addedAssets >= previewAddByShares(e, assetId, require_uint256(addedShares));
    satisfy addedAssets > previewAddByShares(e, assetId, require_uint256(addedShares));
}