
import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./HubValidState.spec";


/***

Verify Hub 

State changes rules in which the validate functions are ignored.
Assuming accrue has been called before any other function.


***/
methods {
    function _validateAdd(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 amount,
        address from
    ) internal => NONDET;

    function _validateRemove(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 amount,
        address to
    ) internal => NONDET;

    function _validateDraw(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 amount,
        address to
    ) internal => NONDET;

    function _validateRestore(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 drawnAmount,
        uint256 premiumAmount,
        address from
    ) internal => NONDET;

    function _validateReportDeficit(
        IHub.Asset storage asset,
        IHub.SpokeData storage spoke,
        uint256 drawnAmount,
        uint256 premiumAmount
    ) internal => NONDET;

    function _validateEliminateDeficit(
        IHub.SpokeData storage spoke,
        uint256 amount
    ) internal => NONDET;

    function _validatePayFeeShares(
        IHub.SpokeData storage senderSpoke,
        uint256 feeShares
    ) internal => NONDET;

    function _validateTransferShares(
        IHub.Asset storage asset,
        IHub.SpokeData storage sender,
        IHub.SpokeData storage receiver,
        uint256 shares
    ) internal => NONDET;

    function _validateSweep(
        IHub.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;

    function _validateReclaim(
        IHub.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;
}


/** @title supply rate is never decreasing
when not accruing interest, every function should never decrease supply exchange rate 
*/
rule supplyExchangeRateIsMonotonic(env e, method f, calldataarg args)
filtered {
    f -> !f.isView
}
{
    uint256 assetId;
    uint256 OneM = 1000000;

    requireAllInvariants(assetId, e);
    // use ghost to avoid repeating complex computation
    mathint assetsBefore = addedAssetsBefore;
    mathint sharesBefore = supplyShareBefore;

    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 


    f(e, args);

    mathint assetsAfter = getAddedAssets(e,assetId);
    mathint sharesAfter = getAddedShares(e,assetId);

    // > when only considering accrue interest
    assert (assetsAfter + OneM) * (sharesBefore + OneM) >= (assetsBefore + OneM )* (sharesAfter + OneM);
}



/** @title No change to a spoke's asset or debt. assume accrue has been called.  
**/
rule noChangeToOtherSpoke(address spoke, uint256 assetId, address otherSpoke, method f) 
    filtered { f -> !f.isView }
    {
    env e;
    env eOther;
    require e.block.timestamp == eOther.block.timestamp; 
    require otherSpoke != spoke && eOther.msg.sender == otherSpoke; 
    address feeReceiver = hub._assets[assetId].feeReceiver;

    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 
    requireAllInvariants(assetId, e);
    
    uint256 cumulativeDebt_  = getSpokeTotalOwed(e, assetId, spoke); 

    uint256 shares_ = getSpokeAddedShares(e, assetId, spoke);
    uint256 assets = getSpokeAddedAssets(e, assetId, spoke);

    address toOnTransfer;
    uint256 x;
    if (f.selector == sig:transferShares(uint256,uint256,address).selector) {
        transferShares(eOther, assetId, x, toOnTransfer);
    }

    else {
        calldataarg args; 
        f(eOther,args);
    }
    assert cumulativeDebt_ >= getSpokeTotalOwed(e, assetId, spoke);  
    assert (spoke != feeReceiver && spoke != toOnTransfer) => shares_ == getSpokeAddedShares(e, assetId, spoke);
    // cases where shares can increase 
    assert (spoke == feeReceiver || spoke == toOnTransfer) => shares_ <= getSpokeAddedShares(e, assetId, spoke);
    // asset can increase due to other's operations 
    assert assets <= getSpokeAddedAssets(e, assetId, spoke); 
} 


/**
@title Accrue must be called before updating shares or debt. 
Transferring shares is safe without accrue, as it stays the same behavior 
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
@title lastUpdateTimestamp is never in the future
*/
rule lastUpdateTimestamp_notInFuture(uint256 assetId, method f) filtered { f-> !f.isView} {
    env e;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;
    
    calldataarg args;
    f(e,args);

    assert hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;


}

