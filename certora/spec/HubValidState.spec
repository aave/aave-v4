
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./HubBase.spec";
//import "./HubAdvanceSummary.spec";


using Hub as hub;

/***

Verify Hub - valid state properties 

***/

methods {


    // assume that borrow rate was already updated.
    //rules concerning updateBorrowRate are in ...
  function AssetLogic.updateDrawnRate(
    DataTypes.Asset storage asset,
    uint256 assetId
  ) internal => NONDET;

    function AssetLogic.getFeeShares(
        DataTypes.Asset storage asset,
        uint256 indexDelta
    ) internal returns (uint256) => ALWAYS(0);

    function AssetLogic.getDrawnIndex(DataTypes.Asset storage   asset) internal returns (uint256) => cachedIndex;

  function AssetLogic.accrue(DataTypes.Asset storage asset, uint256 assetId, DataTypes.SpokeData storage feeReceiver) internal => accrueCalled();

  function MathUtils.calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal returns (uint256) => ghostLinearInterest(rate, lastUpdateTimestamp);

}

/************ Ghost Variables ************/

ghost uint256 cachedIndex;

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

/**** Valid State Rules *******/
/** 
@title up to 1 wei difference getTotalAddedAssets(e,assetId) == getAssetAddedAmount(e,assetId) +- 1
@note implemented as a rule for optimization -reduandant 
**/
rule getTotalAddedAssetsVsGetAssetAddedAmount(uint256 assetId, env e, method f) {
    requireAllInvariants(assetId, e);
    // optimize (reuse) the calls to getAssetAddedAmount() and getTotalAddedShares()
     // addedAssetsBefore = getAssetAddedAmount(e,assetId);
     uint256 totalAmountBefore = getTotalAddedAssets(e,assetId);
     require totalAmountBefore == addedAssetsBefore;
     calldataarg args; 
     f(e,args);

     uint256 supplyAmountAfter = getAssetAddedAmount(e,assetId);
     uint256 totalAmountAfter = getTotalAddedAssets(e,assetId);
     //todo - check what if we start with one diff
     assert totalAmountAfter >= supplyAmountAfter - 1 &&
             totalAmountAfter <= supplyAmountAfter + 1 ;

}


invariant totalAssetsVsShares(uint256 assetId, env e) 
    getTotalAddedAssets(e,assetId) >=  getTotalAddedShares(e,assetId) {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }

invariant totalAssetsAndSharesZero(uint256 assetId, env e) 
    getTotalAddedAssets(e,assetId) == 0 <=> getTotalAddedShares(e,assetId) == 0 {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }


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



/**
 * @title liquidityFee upper bound: config.liquidityFee must not exceed PercentageMathExtended.PERCENTAGE_FACTOR
 */
invariant liquidityFee_upper_bound(uint256 assetId) 
    hub._assets[assetId].liquidityFee <= wadRayMath.PERCENTAGE_FACTOR();



invariant premiumOffset_Integrity(uint256 assetId, address spokeId, env e) 
    hub._assets[assetId].premiumOffset <= previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares)
    {
        preserved  with (env e1) {
            requireAllInvariants(assetId, e1);
            //require e.msg.sender == spokeId;
        }

    }

rule check_premiumOffset_Integrity(uint256 assetId, address spokeId) {
         env e;
    mathint calcBefore = previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares);
    mathint diffBefore = calcBefore- hub._assets[assetId].premiumOffset;
    require diffBefore >= 0;

    requireAllInvariants(assetId, e);
    require e.msg.sender == spokeId;
    DataTypes.PremiumDelta premiumDelta;
    refreshPremium(e,assetId,premiumDelta); 
    mathint calc = previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares);
    //assert hub._spokes[assetId][spokeId].premiumOffset <= hub._spokes[assetId][spokeId].premiumShares * hub._assets[assetId].drawnIndex / wadRayMath.RAY();
    mathint diff = calc- hub._assets[assetId].premiumOffset;
    assert diff >= 0;
}

rule check_premiumOffset_Integrity_RD(uint256 assetId, address spokeId) {
    env e;
    mathint calcBefore =  hub._assets[assetId].premiumShares * hub._assets[assetId].drawnIndex / wadRayMath.RAY();
    mathint diffBefore = calcBefore- hub._spokes[assetId][spokeId].premiumOffset;
    require diffBefore >= 0;

    requireAllInvariants(assetId, e);
    require e.msg.sender == spokeId;
    DataTypes.PremiumDelta premiumDelta;
    refreshPremium(e,assetId,premiumDelta); 
    mathint calc = hub._assets[assetId].premiumShares * hub._assets[assetId].drawnIndex / wadRayMath.RAY();
    mathint diff = calc- hub._assets[assetId].premiumOffset;
    assert diff >= 0;
}



rule check_diffs(uint256 assetId, address spokeId1, address spokeId2) {
    env e;
    require spokeId1 != spokeId2;

    mathint hubBefore =  previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares) -  hub._assets[assetId].premiumOffset;
    mathint spoke1 =  previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId1].premiumShares) -  hub._spokes[assetId][spokeId1].premiumOffset;
    mathint spoke2 =  previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId2].premiumShares) -  hub._spokes[assetId][spokeId2].premiumOffset;
    require hubBefore >= 0;
    require spoke1 >= 0;
    require spoke2 >= 0;    
    require hubBefore >= spoke1 + spoke2;
    uint256 spoke2sharesBefore = hub._spokes[assetId][spokeId2].premiumShares;

    requireAllInvariants(assetId, e);
    require e.msg.sender == spokeId2;
    DataTypes.PremiumDelta premiumDelta;
    refreshPremium(e,assetId,premiumDelta); 
    require spoke2sharesBefore == hub._spokes[assetId][spokeId2].premiumShares;

    mathint hubAfter =  previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares) -  hub._assets[assetId].premiumOffset;
    mathint spokeAfter =  previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId1].premiumShares) -  hub._spokes[assetId][spokeId1].premiumOffset;
    
    assert hubAfter >= spokeAfter;
}
/**
@title External balance is at least as internal accounting 
**/
strong invariant solvency_external(address asset )
    balanceByToken[asset][hub] >=  sumLiquidity[asset] 
    {
        preserved reclaim(uint256 assetId, uint256 amount) with (env e)
        {
            require hub._assets[assetId].reinvestmentStrategy != hub;
        }
}

// optimize the calls to certain function and save in ghost (global) variable) 
ghost uint256 addedAssetsBefore; 
ghost uint256 supplyShareBefore;

function requireAllInvariants(uint256 assetId, env e)  {
    // optimize (reuse) the calls to getTotalAddedAssets() and getTotalAddedShares()
    addedAssetsBefore = getTotalAddedAssets(e,assetId);
    supplyShareBefore = getTotalAddedShares(e,assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require addedAssetsBefore >= supplyShareBefore, "optimization";
    
    // requireInvariant totalAssetsAndSharesZero(assetId,e);
    // this does not hold 
    //require addedAssetsBefore == 0 <=> supplyShareBefore == 0, "optimization";

    requireInvariant solvency_external(hub._assets[assetId].underlying);
    requireInvariant sumOfSpokeDrawnShares(assetId);
    requireInvariant sumOfSpokeSupplyShares(assetId);
    requireInvariant sumOfSpokePremiumDrawnShares(assetId);
    requireInvariant sumOfSpokePremiumOffset(assetId);
    requireInvariant sumOfSpokeRealizedPremium(assetId);
    requireInvariant drawnIndexMin(assetId);
    requireInvariant validAssetId(assetId);
    requireInvariant drawnIndexMin(assetId); 
    requireInvariant liquidityFee_upper_bound(assetId);
    requireInvariant premiumOffset_Integrity(assetId, e.msg.sender,e);
    
    require cachedIndex == hub._assets[assetId].drawnIndex;
    // need to add:
    // getTotalAddedAssetsVsGetAssetAddedAmount 

}   

function assumeRestoreArguments(uint256 assetId, address spoke, uint256 drawnAmount,
                    uint256 premiumAmount, DataTypes.PremiumDelta  premiumDelta) {
            require (premiumAmount < hub._spokes[assetId][spoke].premiumShares  &&  hub._spokes[assetId][spoke].premiumShares > 0 ) => drawnAmount == 0;
            require (premiumDelta.realizedDelta < hub._spokes[assetId][spoke].realizedPremium  &&  hub._spokes[assetId][spoke].realizedPremium > 0 ) => (drawnAmount == 0 && premiumAmount == 0);

        } 