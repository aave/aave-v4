
import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./HubBase.spec";


using Hub as hub;

/***

Verify Hub - valid state properties 
Where we assume a given single drawnIndex and that accrue was called on the asset

***/

methods {


    // assume that drawn rate was already updated.
    //rules concerning updateDrawnRate are in HubAccrueIntegrity.spec
    function AssetLogic.updateDrawnRate(
        IHub.Asset storage asset,
        uint256 assetId
    ) internal => NONDET;

    //rules concerning getFeeShares are in HubAccrueIntegrity.spec
    function AssetLogic.getFeeShares(
        IHub.Asset storage asset,
        uint256 indexDelta
    ) internal returns (uint256) => ALWAYS(0);

    //assume a given single drawnIndex
    //rules concerning getDrawnIndex are in HubAccrueIntegrity.spec
    function AssetLogic.getDrawnIndex(IHub.Asset storage   asset) internal returns (uint256) => cachedIndex;

    //rules concerning accrue are in HubAccrueIntegrity.spec
    function AssetLogic.accrue(IHub.Asset storage asset, mapping(uint256 => mapping(address => IHub.SpokeData)) storage spokes, uint256 assetId) internal => accrueCalled();

}

/************ Ghost Variables ************/

// assume a given single drawnIndex
ghost uint256 cachedIndex;

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

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeDeficitPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeDeficitPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeDeficitPerAssetMirror[X][a]) == 0; 
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
    sumLiquidity[hub._assets[assetId].underlying] = sumLiquidity[hub._assets[assetId].underlying] + new_value - old_value;
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

hook Sstore hub._spokes[KEY uint256 assetId][KEY address spoke].deficit uint128 new_value (uint128 old_value) {
    spokeDeficitPerAssetMirror[assetId][spoke] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint128 value hub._spokes[KEY uint256 assetId][KEY address spoke].deficit {
    require spokeDeficitPerAssetMirror[assetId][spoke] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
/**** Valid State Rules *******/

invariant totalAssetsVsShares(uint256 assetId, env e) 
    getAddedAssets(e,assetId) >=  getAddedShares(e,assetId) {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }


definition emptyAsset(uint256 assetId) returns bool =
    hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].liquidity == 0 &&
        hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].deficit == 0 &&
        hub._assets[assetId].swept == 0 &&
        hub._assets[assetId].premiumShares == 0 &&
        hub._assets[assetId].premiumOffset == 0 &&
        hub._assets[assetId].realizedPremium == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].drawnIndex == 0 &&
        hub._assets[assetId].drawnRate == 0 &&
        hub._assets[assetId].lastUpdateTimestamp == 0 &&
        hub._assets[assetId].underlying == 0 &&
        ( forall address spoke. 
            hub._spokes[assetId][spoke].addedShares == 0 &&
            hub._spokes[assetId][spoke].drawnShares == 0 &&
            hub._spokes[assetId][spoke].premiumShares == 0  &&
            hub._spokes[assetId][spoke].premiumOffset == 0 &&
            hub._spokes[assetId][spoke].realizedPremium == 0 &&
            !hub._spokes[assetId][spoke].active &&
            ghostIndexes[assetId][to_bytes32(spoke)] == 0
        );
        


/** @title integrity of a validAsset 
**/
invariant validAssetId(uint256 assetId)  
    assetId >= hub._assetCount => emptyAsset(assetId) {
        preserved {
            requireInvariant assetToSpokesIntegrity(assetId);
        }
    }




/**
* @title the sum of  hub._spokes[assetId][spoke].addedShares for all spoke equals to hub._assets[assetId].addedShares
*/
invariant sumOfSpokeSupplyShares(uint256 assetId) 
    hub._assets[assetId].addedShares == (usum address spoke. spokeSupplyPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title the sum of  hub._spokes[assetId][spoke].drawnShares for all spoke equals to hub._assets[assetId].drawnShares
*/
invariant sumOfSpokeDrawnShares(uint256 assetId) 
    hub._assets[assetId].drawnShares == (usum address spoke. spokeBaseDrawnPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title the sum of  hub._spokes[assetId][spoke].premiumShares for all spoke equals to hub._assets[assetId].premiumShares
*/
invariant sumOfSpokePremiumDrawnShares(uint256 assetId) 
    hub._assets[assetId].premiumShares == (usum address spoke. spokePremiumDrawnSharesPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title the sum of  hub._spokes[assetId][spoke].premiumOffset for all spoke equals to hub._assets[assetId].premiumOffset
*/
invariant sumOfSpokePremiumOffset(uint256 assetId) 
    hub._assets[assetId].premiumOffset == (usum address spoke. spokePremiumOffsetPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title the sum of  hub._spokes[assetId][spoke].realizedPremium for all spoke equals to hub._assets[assetId].realizedPremium
*/
invariant sumOfSpokeRealizedPremium(uint256 assetId) 
    hub._assets[assetId].realizedPremium == (usum address spoke. spokeRealizedPremiumPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title the sum of  hub._spokes[assetId][spoke].deficit for all spoke equals to hub._assets[assetId].deficit
*/
invariant sumOfSpokeDeficit(uint256 assetId) 
    hub._assets[assetId].deficit == (usum address spoke. spokeDeficitPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
* @title drawnIndex is greater than or equal to RAY on regular assets
**/
invariant drawnIndexMin(uint256 assetId) 
    assetId < hub._assetCount => hub._assets[assetId].drawnIndex >= wadRayMath.RAY()
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


/**
 * @title premiumOffset integrity: premiumOffset must not exceed the premiumShares when converted to assets rounding up
 */
invariant premiumOffset_Integrity(uint256 assetId, address spokeId, env e) 
    previewRestoreByShares(e,assetId,hub._assets[assetId].premiumShares) >=  hub._assets[assetId].premiumOffset && 
    previewRestoreByShares(e,assetId,hub._spokes[assetId][spokeId].premiumShares) >=  hub._spokes[assetId][spokeId].premiumOffset 
    {
        preserved  with (env e1) {
            requireAllInvariants(assetId, e1);
        }

    }


/**
@title External balance is at least as internal accounting 
**/
strong invariant solvency_external(address asset )
    balanceByToken[asset][hub] >=  sumLiquidity[asset] 
    {
        preserved reclaim(uint256 assetId, uint256 amount) with (env e)
        {
            require hub._assets[assetId].reinvestmentController != hub;
        }
}


///@title ghosts for _assetToSpokes EnumerableSet to keep track of the spokes for an asset
// part of proving validAssetId invariant
// For every storage variable we add a ghost field that is kept synchronized by hooks.
// The ghost fields can be accessed by the spec, even inside quantifiers.

// ghost field for the _values array
ghost mapping(uint256 => mapping(mathint => bytes32)) ghostValues {
    init_state axiom forall uint256 assetId. forall mathint x. ghostValues[assetId][x] == to_bytes32(0);
}
// ghost field for the _positions map
ghost mapping(uint256 => mapping(bytes32 => uint256)) ghostIndexes {
    init_state axiom forall uint256 assetId. forall bytes32 x. ghostIndexes[assetId][x] == 0;
}
// ghost field for the length of the values array (stored in offset 0)
ghost mapping(uint256 => uint256) ghostLength {
    init_state axiom forall uint256 assetId. ghostLength[assetId] == 0;
    // assumption: it's infeasible to grow the list to these many elements.
    axiom forall uint256 assetId. ghostLength[assetId] < max_uint256;
}

// HOOKS
// Store hook to synchronize ghostLength with the length of the set._inner._values array.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._values.length uint256 newLength {
    ghostLength[assetId] = newLength;
}
// Store hook to synchronize ghostValues array with set._inner._values.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._values[INDEX uint256 index] bytes32 newValue {
    ghostValues[assetId][index] = newValue;
}
// Store hook to synchronize ghostIndexes array with set._inner._positions.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._positions[KEY bytes32 value] uint256 newIndex {
    ghostIndexes[assetId][value] = newIndex;
}

// The load hooks can use require to ensure that the ghost field has the same information as the storage.
// The require is sound, since the store hooks ensure the contents are always the same.  However we cannot
// prove that with invariants, since this would require the invariant to read the storage for all elements
// and neither storage access nor function calls are allowed in quantifiers.
//
// By following this simple pattern it is ensured that the ghost state and the storage are always the same
// and that the solver can use this knowledge in the proofs.

// Load hook to synchronize ghostLength with the length of the set._inner._values array.
hook Sload uint256 length hub._assetToSpokes[KEY uint256 assetId]._inner._values.length {
    require ghostLength[assetId] == length;
}
hook Sload bytes32 value hub._assetToSpokes[KEY uint256 assetId]._inner._values[INDEX uint256 index] {
    require ghostValues[assetId][index] == value;
}
hook Sload uint256 index hub._assetToSpokes[KEY uint256 assetId]._inner._positions[KEY bytes32 value] {
    require ghostIndexes[assetId][value] == index;
}

// INVARIANTS

//  This is the main invariant stating that the indexes and values always match:
//        values[indexes[v] - 1] = v for all values v in the set
//    and indexes[values[i]] = i+1 for all valid indexes i.

invariant assetToSpokesIntegrity(uint256 assetId)
    (forall uint256 index. 0 <= index && index < ghostLength[assetId] => to_mathint(ghostIndexes[assetId][ghostValues[assetId][index]]) == index + 1)
    && (forall bytes32 value. ghostIndexes[assetId][value] == 0 ||
         (ghostValues[assetId][ghostIndexes[assetId][value] - 1] == value && ghostIndexes[assetId][value] >= 1 && ghostIndexes[assetId][value] <= ghostLength[assetId]));



// optimize the calls to certain function and save in ghost (global) variable) 
ghost uint256 addedAssetsBefore; 
ghost uint256 supplyShareBefore;

function requireAllInvariants(uint256 assetId, env e)  {
    // optimize (reuse) the calls to getAddedAssets() and getTotalAddedShares()
    addedAssetsBefore = getAddedAssets(e,assetId);
    supplyShareBefore = getAddedShares(e,assetId); 
    requireInvariant totalAssetsVsShares(assetId,e);
    require addedAssetsBefore >= supplyShareBefore, "optimization";
    

    requireInvariant solvency_external(hub._assets[assetId].underlying);
    requireInvariant sumOfSpokeDrawnShares(assetId);
    requireInvariant sumOfSpokeSupplyShares(assetId);
    requireInvariant sumOfSpokePremiumDrawnShares(assetId);
    requireInvariant sumOfSpokePremiumOffset(assetId);
    requireInvariant sumOfSpokeRealizedPremium(assetId);
    requireInvariant drawnIndexMin(assetId);
    requireInvariant assetToSpokesIntegrity(assetId);
    requireInvariant validAssetId(assetId);
    requireInvariant liquidityFee_upper_bound(assetId);
    requireInvariant premiumOffset_Integrity(assetId, e.msg.sender,e);
    
    require cachedIndex == hub._assets[assetId].drawnIndex;

}   

function assumeRestoreArguments(uint256 assetId, address spoke, uint256 drawnAmount,
                    uint256 premiumAmount, IHubBase.PremiumDelta  premiumDelta) {
            require (premiumAmount < hub._spokes[assetId][spoke].premiumShares  &&  hub._spokes[assetId][spoke].premiumShares > 0 ) => drawnAmount == 0;
            require (premiumDelta.realizedDelta < hub._spokes[assetId][spoke].realizedPremium  &&  hub._spokes[assetId][spoke].realizedPremium > 0 ) => (drawnAmount == 0 && premiumAmount == 0);

        } 