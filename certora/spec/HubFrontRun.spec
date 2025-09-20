
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./HubValidState.spec";


/***

Verify Hub - frontrun properties 

***/


// @title one can remove his shares in case of frontrun 
// @dev sweep can cause a revert, as it can leave the hub with insufficient assets for the remove
rule frontRunOnRemove(uint256 assetId, method f) filtered { f -> !f.isView  && f.selector != sig:sweep(uint256,uint256).selector} {
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
    //just to avoid overflows
    require getAddedAssets(e,assetId) >= getAddedShares(e,assetId);
    remove@withrevert(e,assetId, amount, from);
    assert !lastReverted;
    // it is possible for everyone to remove and than zero shares left
    satisfy !lastReverted && addedAssetsBefore!=0 && getAddedAssets(e,assetId) == 0;
}

// @title one can repay his debt in case of frontrun 
// @dev sweep can cause a revert, as it can leave the hub with insufficient assets for the restore
rule frontRunOnRestore(uint256 assetId, method f) filtered { f -> !f.isView  && f.selector != sig:sweep(uint256,uint256).selector} {
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
    IHubBase.PremiumDelta premiumDelta;
    address from;
    f(eBefore,args);
    
    f(eBefore,args) at init_state;
    //just to avoid overflows
    require getAddedAssets(e,assetId) >= getAddedShares(e,assetId);
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
    requireInvariant premiumOffset_Integrity(assetId, e.msg.sender,e);
    calldataarg argsRefresh;
    storage init_state = lastStorage;
    refreshPremium(e,argsRefresh);
    refreshPremium(eBefore,args);
    refreshPremium(eBefore,args) at init_state;
    //just to avoid overflows
    require getAddedAssets(e,assetId) >= getAddedShares(e,assetId);
    refreshPremium@withrevert(e,argsRefresh);
    assert !lastReverted;
}