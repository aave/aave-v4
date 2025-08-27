
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./Hub_validState.spec";


/***

Verify Hub 

State changes rules in which the validate functions are ignored 

***/
methods {
    function _validateAdd(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 assetId,
        uint256 amount,
        address from
    ) internal => NONDET;

    function _validateRemove(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 assetId,
        uint256 amount,
        address to
    ) internal => NONDET;

    function _validateDraw(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 assetId,
        uint256 amount,
        address to
    ) internal => NONDET;

    function _validateRestore(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 assetId,
        uint256 drawnAmount,
        uint256 premiumAmount,
        address from
    ) internal => NONDET;

    function _validateReportDeficit(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 assetId,
        uint256 drawnAmount,
        uint256 premiumAmount
    ) internal => NONDET;

    function _validateEliminateDeficit(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage spoke,
        uint256 amount
    ) internal => NONDET;

    function _validatePayFee(
        DataTypes.SpokeData storage senderSpoke,
        uint256 feeShares
    ) internal => NONDET;

    function _validateTransferShares(
        DataTypes.Asset storage asset,
        DataTypes.SpokeData storage sender,
        DataTypes.SpokeData storage receiver,
        uint256 assetId,
        uint256 shares
    ) internal => NONDET;

    function _validateSweep(
        DataTypes.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;

    function _validateReclaim(
        DataTypes.Asset storage asset,
        address caller,
        uint256 amount
    ) internal => NONDET;
}

// when not accruing interest, every function should increase supply exchange rate (except liquidate which is wip)
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

    // todo filter out when no time pass
    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 


    f(e, args);

    mathint assetsAfter = getTotalAddedAssets(e,assetId);
    mathint sharesAfter = getTotalAddedShares(e,assetId);

    // > when only considering accrue interest
    assert (assetsAfter + OneM) * (sharesBefore + OneM) >= (assetsBefore + OneM )* (sharesAfter + OneM);
}



/** @title No change to a spoke's asset or debt. assume accrue has been called.  
@status breaks because:
-  spoke can be re-added thus deleting current supply and debt 
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
    uint256 assets = getSpokeAddedAmount(e, assetId, spoke);

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
    assert assets <= getSpokeAddedAmount(e, assetId, spoke); 
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

rule lastUpdateTimestamp_notInFuture(uint256 assetId, method f) filtered { f-> !f.isView} {
    env e;
    require hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;
    
    calldataarg args;
    f(e,args);

    assert hub._assets[assetId].lastUpdateTimestamp <= e.block.timestamp;


}



// one can remove his shares
rule frontRunOnRemove(uint256 assetId, method f) {
    env e;
    env eBefore; calldataarg args;
    require eBefore.msg.sender != e.msg.sender;
    require eBefore.block.timestamp <=  e.block.timestamp;

    requireAllInvariants(assetId,eBefore);

    storage init_state = lastStorage;
    // once should still be able to remove his shares
    uint256 amount; 
    address from;
    remove(e,assetId, amount, from);
    f(eBefore,args);
    f(eBefore,args) at init_state;
    remove@withrevert(e,assetId, amount, from);
    assert !lastReverted;
    // it is possible for everyone to remove and than zero shares left
    satisfy !lastReverted && addedAssetsBefore!=0 && getAssetAddedAmount(e,assetId) == 0;
}

/// one can repay his debt
rule frontRunOnRestore(uint256 assetId, method f) {
    env e;
    env eBefore; calldataarg args;
    require eBefore.msg.sender != e.msg.sender;
    require eBefore.block.timestamp <=  e.block.timestamp;

    uint256 totalOwedBefore = getAssetTotalOwed(eBefore, assetId);
    requireAllInvariants(assetId,e);

    storage init_state = lastStorage;
    // one should still be able to pay his debt
    uint256 drawnAmount;
    uint256 premiumAmount;
    DataTypes.PremiumDelta premiumDelta;
    address from;
    restore(e,assetId,drawnAmount,premiumAmount,premiumDelta,from);
    f(eBefore,args);
    
    f(eBefore,args) at init_state;
    restore@withrevert(e,assetId,drawnAmount,premiumAmount,premiumDelta,from);
    assert !lastReverted;
    // it is possible for everyone to remove and than zero shares left
    satisfy !lastReverted && totalOwedBefore!=0 && getAssetTotalOwed(e,assetId) == 0;
}

rule frontRunOnRefreshPremium(uint256 assetId) {
    env e;
    env eBefore; calldataarg args; 

    require eBefore.msg.sender != e.msg.sender;
    require eBefore.block.timestamp <=  e.block.timestamp;

    requireAllInvariants(assetId,eBefore);
    calldataarg argsRefresh;
    storage init_state = lastStorage;
    refreshPremium(e,argsRefresh);
    refreshPremium(eBefore,args);
    refreshPremium(eBefore,args) at init_state;
    refreshPremium@withrevert(e,argsRefresh);
    assert !lastReverted;
}