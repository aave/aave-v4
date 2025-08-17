
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./HubAdvanceSummary.spec";
import "./Hub_validState.spec";


/***

Verify Hub 

***/


/************ Ghost Variables ************/


rule solvency_internal(uint256 assetId, env e) {
//    requireAllInvariants(assetId, e);
    assert hub._assets[assetId].liquidity >= getAssetAddedAmount(e, assetId) - getAssetTotalOwed(e, assetId);
    }


// when not accruing interest, every function should increase supply exchange rate (except liquidate which is wip)
rule supplyExchangeRateIsMonotonic(env e, method f, calldataarg args)
filtered {
    f -> !f.isView
}
{
    uint256 assetId;

    requireAllInvariants(assetId, e);
    // use ghost to avoid repeating complex computation
    mathint assetsBefore = supplyAmountBefore; 
    mathint sharesBefore = supplyShareBefore;

    // todo filter out when no time pass
    require hub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 


    f(e, args);

    mathint assetsAfter = getAssetAddedAmount(e,assetId);
    mathint sharesAfter = getTotalAddedShares(e,assetId);

    // > when only considering accrue interest
    assert assetsAfter * sharesBefore >= assetsBefore * sharesAfter;
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

    
    calldataarg args; 
    f(eOther,args);

    assert cumulativeDebt_ >= getSpokeTotalOwed(e, assetId, spoke);  
    assert spoke != feeReceiver => shares_ == getSpokeAddedShares(e, assetId, spoke);
    // asset can increase due to other's operations 
    assert assets <= getSpokeAddedAmount(e, assetId, spoke); 
} 



rule accrueWasCalled(uint256 assetId, method f) filtered { f-> !f.isView} {
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

    requireAllInvariants(assetId,eBefore);

    storage init_state = lastStorage;
    // once should still be able to remove his shares
    uint256 amount; 
    address from;
    remove(e,assetId, amount, from);
    
    f(eBefore,args) at init_state;
    remove@withrevert(e,assetId, amount, from);
    assert !lastReverted;
    // it is possible for everyone to remove and than zero shares left
    satisfy !lastReverted && supplyAmountBefore!=0 && getAssetAddedAmount(e,assetId) == 0;
}

/// one can repay his debt
rule frontRunOnRestore(uint256 assetId, method f) {
    env e;
    env eBefore; calldataarg args;
    require eBefore.msg.sender != e.msg.sender;
    uint256 totalOwedBefore = getAssetTotalOwed(eBefore, assetId);
    requireAllInvariants(assetId,e);

    storage init_state = lastStorage;
    // one should still be able to pay his debt
    uint256 drawnAmount;
    uint256 premiumAmount;
    DataTypes.PremiumDelta premiumDelta;
    address from;
    restore(e,assetId,drawnAmount,premiumAmount,premiumDelta,from);
    
    f(eBefore,args) at init_state;
    restore@withrevert(e,assetId,drawnAmount,premiumAmount,premiumDelta,from);
    assert !lastReverted;
    // it is possible for everyone to remove and than zero shares left
    satisfy !lastReverted && totalOwedBefore!=0 && getAssetTotalOwed(e,assetId) == 0;
}

rule nothingForZero_add(uint256 assetId, uint256 amount, address from) {

    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 fromBalanceBefore = balanceByToken[asset][from];
    uint256 spokeSharesBefore = hub._spokes[assetId][spoke].addedShares;

    add(e, assetId, amount, from);

    assert balanceByToken[asset][hub] > externalBalanceBefore && hub._spokes[assetId][spoke].addedShares > spokeSharesBefore && fromBalanceBefore > balanceByToken[asset][hub];
    // no fee and no asset lost
    assert balanceByToken[asset][hub] + balanceByToken[asset][from] == externalBalanceBefore + fromBalanceBefore; 
}


rule nothingForZero_remove(uint256 assetId, uint256 amount, address to) {

    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 toBalanceBefore = balanceByToken[asset][to];
    uint256 spokeSharesBefore = hub._spokes[assetId][spoke].addedShares;

    remove(e, assetId, amount, to);

    assert balanceByToken[asset][hub] < externalBalanceBefore && hub._spokes[assetId][spoke].addedShares < spokeSharesBefore && toBalanceBefore < balanceByToken[asset][hub];
    // no fee and no asset lost
    assert balanceByToken[asset][hub] + balanceByToken[asset][to] == externalBalanceBefore + toBalanceBefore; 
}