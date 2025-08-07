
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./HubAdvanceSummary.spec";


using Hub as hub;

/***

Verify Hub 

***/

methods {


    // assume that borrow rate was already updated.
    //rules concerning updateBorrowRate are in ...
  function AssetLogic.updateDrawnRate(
    DataTypes.Asset storage asset,
    uint256 assetId
  ) internal => NONDET;

  function AssetLogic.accrue(DataTypes.Asset storage asset, uint256 assetId, DataTypes.SpokeData storage feeReceiver) internal => accrueCalled();

  function MathUtils.calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal returns (uint256) => ghostLinearInterest(rate, lastUpdateTimestamp);
/*
  function _validateAdd(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address from
  ) internal => NONDET;

  function _validateRemove(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal => NONDET;

  function Hub._validateDraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount,
    address to
  ) internal => NONDET;

  function Hub._validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmountRestored,
    uint256 premiumAmountRestored,
    address from
  ) internal => NONDET;

*/

}

/************ Ghost Variables ************/

ghost  ghostLinearInterest( uint256 /*rate*/, uint40 /*lastUpdateTimestamp*/) returns uint256; 

// track all assetsIds of the same asset 
/// sumLiquidity[asset] is the sum of _assets[KEY uint256 assetId].liquidity  for all assetIds of asset 
ghost mapping(address /*IERC20*/ => mathint ) sumLiquidity {
    init_state axiom forall address X. sumLiquidity[X] == 0;
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeSupplyPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeSupplyPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeSupplyPerAssetMirror[X][a]) == 0; 
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokePremiumDrawnSharesPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokePremiumDrawnSharesPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokePremiumDrawnSharesPerAssetMirror[X][a]) == 0; 
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeBaseDrawnPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeBaseDrawnPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeBaseDrawnPerAssetMirror[X][a]) == 0; 
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokePremiumOffsetPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokePremiumOffsetPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokePremiumOffsetPerAssetMirror[X][a]) == 0; 
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeRealizedPremiumPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeRealizedPremiumPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeRealizedPremiumPerAssetMirror[X][a]) == 0; 
}

ghost bool accrueCalledOnAsset;
//record accessed to debt fields before accrue
ghost bool unsafeAccessBeforeAccrue;
/********** Function summary *****/
function accrueCalled() {
    accrueCalledOnAsset = true; 
} 

/************ Hooks  ************/
/// Update sumLiquidity[t] on update to availableLiquidity of assetId for token t
hook Sstore _assets[KEY uint256 assetId].liquidity uint128 new_value (uint128 old_value) {
    sumLiquidity[currentContract._assets[assetId].underlying] = sumLiquidity[currentContract._assets[assetId].underlying] + new_value - old_value;
}

hook Sstore _assets[KEY uint256 assetId].drawnIndex uint128 new_value (uint128 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value _assets[KEY uint256 assetId].drawnIndex  {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sstore _assets[KEY uint256 assetId].addedShares uint128 new_value (uint128 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value _assets[KEY uint256 assetId].addedShares  {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].drawnShares uint128 new_value (uint128 old_value) {
    spokeBaseDrawnPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].drawnShares {
    require spokeBaseDrawnPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].addedShares uint128 new_value (uint128 old_value) {
    spokeSupplyPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].addedShares {
    require spokeSupplyPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].premiumShares uint128 new_value (uint128 old_value) {
    spokePremiumDrawnSharesPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].premiumShares {
    require spokePremiumDrawnSharesPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].premiumOffset uint128 new_value (uint128 old_value) {
    spokePremiumOffsetPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].premiumOffset {
    require spokePremiumOffsetPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].realizedPremium uint128 new_value (uint128 old_value) {
    spokeRealizedPremiumPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].realizedPremium {
    require spokeRealizedPremiumPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

/**
@title External balance is at least as internal accounting 
https://prover.certora.com/output/40726/1223726233564eeabef3da5a94096d92/?anonymousKey=7a23564895baca924f339ac7720029b2aa50a758
@status, fails on 'add' and 'restore' when 'from' is hub

otherwise passes violation: https://prover.certora.com/output/40726/1c96eb0569424739acd95562ffcbd9b2/?anonymousKey=b2530ed45dc0a161001d1893849e3d2bbfe3e907
**/
strong invariant solvency_external(address asset )
    balanceByToken[asset][hub] >=  sumLiquidity[asset]  {

        /*
        preserved Hub.add(uint256 assetId, uint256 amount, address from) with (env e){
            require from != hub;
        }

        preserved Hub.restore(uint256 assetId, uint256 baseAmount, uint256 premiumAmount, address from)  with (env e) {
                require from != hub;
        }
        */
    }


/**
@title Internal accounting represents supplied minus debt
@dev the require_uint that enforces suppliedShares to be >= baseDrawnShares is checked in baseDrawnSharesVsSuppliedShares
**/ 
/* not an invariant, it's a tuatology 
invariant solvency_internal(uint256 assetId, env e)
    getAvailableLiquidity(e, assetId) >= getAssetAddedAmount(e, assetId) - getAssetOwed(e, assetId)  {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }
    */


rule solvency_internal(uint256 assetId, env e) {
//    requireAllInvariants(assetId, e);
    assert hub._assets[assetId].liquidity >= getAssetAddedAmount(e, assetId) - getAssetTotalOwed(e, assetId);
    }


invariant getTotalAddedAssetsVsGetAssetAddedAmount(uint256 assetId, env e) 
    getTotalAddedAssets(e,assetId) == getAssetAddedAmount(e,assetId)  {
        preserved with (env eInv) {
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }


invariant totalAssetsVsShares(uint256 assetId, env e) 
    getAssetAddedAmount(e,assetId) >=  getTotalAddedShares(e,assetId) {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }

invariant totalAssetsAndSharesZero(uint256 assetId, env e) 
    getAssetAddedAmount(e,assetId) == 0 <=> getTotalAddedShares(e,assetId) == 0 {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
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
/**** Valid State Rules *******/


definition emptyAsset(uint256 assetId) returns bool =
    hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].liquidity == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].premiumShares == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].premiumOffset == 0 &&
        hub._assets[assetId].realizedPremium == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].drawnIndex == 0 &&
        hub._assets[assetId].drawnRate == 0 &&
        hub._assets[assetId].lastUpdateTimestamp == 0 &&
        ( forall address spoke. 
            hub._spokes[assetId][spoke].addedShares == 0 &&
            hub._spokes[assetId][spoke].drawnShares == 0 &&
            hub._spokes[assetId][spoke].premiumShares == 0  &&
            hub._spokes[assetId][spoke].premiumOffset == 0 &&
            hub._spokes[assetId][spoke].realizedPremium == 0 
        ) && 
        hub._assets[assetId].underlying == 0;


/** @title integrity of a validAsset 
@status fails on refreshPremiumDebt  https://prover.certora.com/output/40726/dbc1d061483e4a92b20160ea03527ca4/?anonymousKey=50dc3842ecb36e1a7fc67153c11e716d5a813cf6
in the case that assetId is not listed yet 
**/

invariant validAssetId(uint256 assetId)  
    assetId >= hub._assetCount => emptyAsset(assetId);




/** @title the sum of  hub._spokes[assetId][spoke].addedShares for all spoke equals to hub._assets[assetId].addedShares
@status fails on addSpoke and addSpokes as they can re-add an existing spoke 
https://prover.certora.com/output/40726/cb1ee5d64b7f432f8769be106d6f3bc4?anonymousKey=bf86ab21b57e6979814f430901bd42d3bb540c02 
*/
invariant sumOfSpokeSupplyShares(uint256 assetId) 
    hub._assets[assetId].addedShares == (usum address spoke. spokeSupplyPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/** @title the sum of  hub._spokes[assetId][spoke].drawnShares for all spoke equals to hub._assets[assetId].drawnShares
same failures on addSpoke and addSpokes as they can re-add an existing spoke 
*/
invariant sumOfSpokeDrawnShares(uint256 assetId) 
    hub._assets[assetId].drawnShares == (usum address spoke. spokeBaseDrawnPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

invariant sumOfSpokePremiumDrawnShares(uint256 assetId) 
    hub._assets[assetId].premiumShares == (usum address spoke. spokePremiumDrawnSharesPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

invariant sumOfSpokePremiumOffset(uint256 assetId) 
    hub._assets[assetId].premiumOffset == (usum address spoke. spokePremiumOffsetPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

invariant sumOfSpokeRealizedPremium(uint256 assetId) 
    hub._assets[assetId].realizedPremium == (usum address spoke. spokeRealizedPremiumPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

invariant drawnIndexMin(uint256 assetId) 
    hub._assets[assetId].drawnIndex==0 || hub._assets[assetId].drawnIndex >= wadRayMath.RAY()
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }


// optimize the calls to certain function and save in ghost (global) variable) 
ghost uint256 supplyAmountBefore; 
ghost uint256 supplyShareBefore;

function requireAllInvariants(uint256 assetId, env e)  {
    // optimize (reuse) the calls to getAssetAddedAmount() and getTotalAddedShares()
    supplyAmountBefore = getAssetAddedAmount(e,assetId);
    supplyShareBefore = getTotalAddedShares(e,assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require supplyAmountBefore >= supplyShareBefore, "optimization";
    
    // requireInvariant totalAssetsAndSharesZero(assetId,e);
    require supplyAmountBefore == 0 <=> supplyShareBefore == 0, "optimization";

    requireInvariant solvency_external(hub._assets[assetId].underlying);
    requireInvariant sumOfSpokeDrawnShares(assetId);
    requireInvariant sumOfSpokeSupplyShares(assetId);
    requireInvariant sumOfSpokePremiumDrawnShares(assetId);
    requireInvariant sumOfSpokePremiumOffset(assetId);
    requireInvariant sumOfSpokeRealizedPremium(assetId);
    requireInvariant drawnIndexMin(assetId);
    requireInvariant validAssetId(assetId);
    requireInvariant drawnIndexMin(assetId); 
}   

/**
 * @title liquidityFee upper bound: config.liquidityFee must not exceed PercentageMathExtended.PERCENTAGE_FACTOR
 */
invariant liquidityFee_upper_bound(uint256 assetId) 
    hub._assets[assetId].liquidityFee <= wadRayMath.PERCENTAGE_FACTOR();


// once can remove his shares
rule frontRunOnRemove(uint256 assetId, method f) {
    env e;
    env eBefore; calldataarg args;
    require eBefore.msg.sender != e.msg.sender;

    requireAllInvariants(assetId,e);

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

invariant premiumOffset_Integrity(uint256 assetId) 
    hub._assets[assetId].premiumOffset <= hub._assets[assetId].premiumShares * hub._assets[assetId].drawnRate / wadRayMath.RAY()
    {
        preserved  {
            env e;
            requireAllInvariants(assetId, e);
            
        }
    }