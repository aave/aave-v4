/**
 * @title Hub Valid State Specification
 * @notice Verify Hub valid state properties
 * @dev Assumes a given single drawnIndex and that accrue was called on the asset
 *
 * To run this spec file:
 * certoraRun certora/conf/HubValidState.conf
 */

import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./HubBase.spec";

using HubInstance as hub;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {

    // assume that drawn rate was already updated.
    //rules concerning updateDrawnRate are in HubAccrueIntegrity.spec
    function AssetLogic.updateDrawnRate(
        IHub.Asset storage asset,
        uint256 assetId
    ) internal => NONDET;

    // Assume a given single drawnIndex
    // Rules concerning getDrawnIndex are in HubAccrueIntegrity.spec
    function AssetLogic.getDrawnIndex(IHub.Asset storage asset) internal returns (uint256) => cachedIndex;

    // Rules concerning accrue are in HubAccrueIntegrity.spec
    // In this spec we assume that the asset is not being accrued for fees, so getUnrealizedFees returns 0
    function AssetLogic.accrue(IHub.Asset storage asset) internal => accrueCalled();
    function AssetLogic.getUnrealizedFees(
        IHub.Asset storage asset,
        uint256 drawnIndex
    ) internal returns (uint256) => 0;
}

////////////////////////////////////////////////////////////////////////////
//                              GHOST VARIABLES                           //
////////////////////////////////////////////////////////////////////////////

// Assume a given single drawnIndex
ghost uint256 cachedIndex;

ghost mapping(uint256 /*assetId*/ => mapping(address /*spokeId*/ => uint256)) spokeAddedSharesMirror {
    init_state axiom forall uint256 X. forall address Y. spokeAddedSharesMirror[X][Y] == 0;
    init_state axiom forall uint256 X. (usum address a. spokeAddedSharesMirror[X][a]) == 0;
}

ghost mapping(uint256 /*assetId*/ => mapping(address /*spokeId*/ => uint256)) spokePremiumSharesMirror {
    init_state axiom forall uint256 X. forall address Y. spokePremiumSharesMirror[X][Y] == 0;
    init_state axiom forall uint256 X. (usum address a. spokePremiumSharesMirror[X][a]) == 0;
}

ghost mapping(uint256 /*assetId*/ => mapping(address /*spokeId*/ => uint256)) spokeDrawnSharesMirror {
    init_state axiom forall uint256 X. forall address Y. spokeDrawnSharesMirror[X][Y] == 0;
    init_state axiom forall uint256 X. (usum address a. spokeDrawnSharesMirror[X][a]) == 0;
}

ghost mapping(uint256 /*assetId*/ => mapping(address /*spokeId*/ => int200)) spokePremiumOffsetMirror {
    init_state axiom forall uint256 X. forall address Y. spokePremiumOffsetMirror[X][Y] == 0;
    init_state axiom forall uint256 X. (sum address a. spokePremiumOffsetMirror[X][a]) == 0;
}

ghost mapping(uint256 /*assetId*/ => mapping(address /*spokeId*/ => uint256)) spokeDeficitMirror {
    init_state axiom forall uint256 X. forall address Y. spokeDeficitMirror[X][Y] == 0;
    init_state axiom forall uint256 X. (usum address a. spokeDeficitMirror[X][a]) == 0;
}

ghost bool accrueCalledOnAsset;
// Record accessed to debt fields before accrue
ghost bool unsafeAccessBeforeAccrue;

// Ghosts for _assetToSpokes EnumerableSet to keep track of the spokes for an asset
// Part of proving validAssetId invariant
// For every storage variable we add a ghost field that is kept synchronized by hooks.
// The ghost fields can be accessed by the spec, even inside quantifiers.

// Ghost field for the _values array
ghost mapping(uint256 => mapping(mathint => bytes32)) assetToSpokeValues {
    init_state axiom forall uint256 assetId. forall mathint x. assetToSpokeValues[assetId][x] == to_bytes32(0);
}

// Ghost field for the _positions map
ghost mapping(uint256 => mapping(bytes32 => uint256)) assetToSpokeIndexes {
    init_state axiom forall uint256 assetId. forall bytes32 x. assetToSpokeIndexes[assetId][x] == 0;
}

// Ghost field for the length of the values array (stored in offset 0)
ghost mapping(uint256 => uint256) assetToSpokeLength {
    init_state axiom forall uint256 assetId. assetToSpokeLength[assetId] == 0;
    // Assumption: it's infeasible to grow the list to these many elements.
    axiom forall uint256 assetId. assetToSpokeLength[assetId] < max_uint256;
}

// Optimize calls to getAddedAssets, getAddedShares function and save in ghost (global) variable
ghost uint256 addedAssetsBefore;
ghost uint256 addedSharesBefore;

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
    hub._assets[assetId].underlying == 0 &&
    (forall address spokeId.
        hub._spokes[assetId][spokeId].addedShares == 0 &&
        hub._spokes[assetId][spokeId].drawnShares == 0 &&
        hub._spokes[assetId][spokeId].premiumShares == 0 &&
        hub._spokes[assetId][spokeId].premiumOffsetRay == 0 &&
        !hub._spokes[assetId][spokeId].active &&
        assetToSpokeIndexes[assetId][to_bytes32(spokeId)] == 0
    );

////////////////////////////////////////////////////////////////////////////
//                              HELPER FUNCTIONS                          //
////////////////////////////////////////////////////////////////////////////

/**
 * @notice Function summary for accrue called
 */
function accrueCalled() {
    accrueCalledOnAsset = true;
}

/**
 * @notice Require all invariants for an asset
 */
function requireAllInvariants(uint256 assetId, env e) {
    // Optimize (reuse) the calls to getAddedAssets() and getTotalAddedShares()
    addedAssetsBefore = hub.getAddedAssets(e, assetId);
    addedSharesBefore = hub.getAddedShares(e, assetId);
    // requireInvariant totalAssetsVsShares(assetId,e);
    require addedAssetsBefore >= addedSharesBefore, "optimization";

    requireInvariant solvency_external(assetId);
    requireInvariant sumOfSpokeDrawnShares(assetId);
    requireInvariant sumOfSpokeSupplyShares(assetId);
    requireInvariant sumOfSpokePremiumDrawnShares(assetId);
    requireInvariant sumOfSpokePremiumOffset(assetId);
    requireInvariant drawnIndexMin(assetId);
    requireInvariant assetToSpokesIntegrity(assetId);
    requireInvariant validAssetId(assetId);
    requireInvariant liquidityFee_upper_bound(assetId);
    require cachedIndex == hub._assets[assetId].drawnIndex;
}

////////////////////////////////////////////////////////////////////////////
//                                  HOOKS                                 //
//////////////////////////////////////////////////////////////////////////// 

// ========== Asset Hooks (in struct order) ==========

// 1. liquidity (uint120)
hook Sstore hub._assets[KEY uint256 assetId].liquidity uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].liquidity {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 2. realizedFees (uint120)
hook Sstore hub._assets[KEY uint256 assetId].realizedFees uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].realizedFees {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 3. decimals (uint8)
hook Sstore hub._assets[KEY uint256 assetId].decimals uint8 new_value (uint8 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint8 value hub._assets[KEY uint256 assetId].decimals {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 4. addedShares (uint120)
hook Sstore hub._assets[KEY uint256 assetId].addedShares uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].addedShares {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 5. swept (uint120)
hook Sstore hub._assets[KEY uint256 assetId].swept uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].swept {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 6. premiumOffsetRay (int200)
hook Sstore hub._assets[KEY uint256 assetId].premiumOffsetRay int200 new_value (int200 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload int200 value hub._assets[KEY uint256 assetId].premiumOffsetRay {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 7. drawnShares (uint120)
hook Sstore hub._assets[KEY uint256 assetId].drawnShares uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].drawnShares {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 8. premiumShares (uint120)
hook Sstore hub._assets[KEY uint256 assetId].premiumShares uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].premiumShares {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 9. liquidityFee (uint16)
hook Sstore hub._assets[KEY uint256 assetId].liquidityFee uint16 new_value (uint16 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint16 value hub._assets[KEY uint256 assetId].liquidityFee {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 10. drawnIndex (uint120)
hook Sstore hub._assets[KEY uint256 assetId].drawnIndex uint120 new_value (uint120 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._assets[KEY uint256 assetId].drawnIndex {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 11. drawnRate (uint96)
hook Sstore hub._assets[KEY uint256 assetId].drawnRate uint96 new_value (uint96 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint96 value hub._assets[KEY uint256 assetId].drawnRate {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 12. lastUpdateTimestamp (uint40)
hook Sstore hub._assets[KEY uint256 assetId].lastUpdateTimestamp uint40 new_value (uint40 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint40 value hub._assets[KEY uint256 assetId].lastUpdateTimestamp {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 13. underlying (address) - no need to call accrue for this
// 14. irStrategy (address) - no need to call accrue for this
// 15. reinvestmentController (address) - no need to call accrue for this
// 16. feeReceiver (address) - no need to call accrue for this

// 17. deficitRay (uint200)
hook Sstore hub._assets[KEY uint256 assetId].deficitRay uint200 new_value (uint200 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint200 value hub._assets[KEY uint256 assetId].deficitRay {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// ========== Spoke Hooks (in struct order) ==========

// 1. drawnShares (uint120)
hook Sstore hub._spokes[KEY uint256 assetId][KEY address spokeId].drawnShares uint120 new_value (uint120 old_value) {
    spokeDrawnSharesMirror[assetId][spokeId] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._spokes[KEY uint256 assetId][KEY address spokeId].drawnShares {
    require spokeDrawnSharesMirror[assetId][spokeId] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 2. premiumShares (uint120)
hook Sstore hub._spokes[KEY uint256 assetId][KEY address spokeId].premiumShares uint120 new_value (uint120 old_value) {
    spokePremiumSharesMirror[assetId][spokeId] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._spokes[KEY uint256 assetId][KEY address spokeId].premiumShares {
    require spokePremiumSharesMirror[assetId][spokeId] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 3. premiumOffsetRay (int200)
hook Sstore hub._spokes[KEY uint256 assetId][KEY address spokeId].premiumOffsetRay int200 new_value (int200 old_value) {
    spokePremiumOffsetMirror[assetId][spokeId] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload int200 value hub._spokes[KEY uint256 assetId][KEY address spokeId].premiumOffsetRay {
    require spokePremiumOffsetMirror[assetId][spokeId] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 4. addedShares (uint120)
hook Sstore hub._spokes[KEY uint256 assetId][KEY address spokeId].addedShares uint120 new_value (uint120 old_value) {
    spokeAddedSharesMirror[assetId][spokeId] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint120 value hub._spokes[KEY uint256 assetId][KEY address spokeId].addedShares {
    require spokeAddedSharesMirror[assetId][spokeId] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

// 5. addCap (uint40) - no need to call accrue for this
// 6. drawCap (uint40) - no need to call accrue for this
// 7. riskPremiumThreshold (uint24) - no need to call accrue for this
// 8. active (bool) - no need to call accrue for this
// 9. paused (bool) - no need to call accrue for this

// 10. deficitRay (uint200) 
hook Sstore hub._spokes[KEY uint256 assetId][KEY address spokeId].deficitRay uint200 new_value (uint200 old_value) {
    spokeDeficitMirror[assetId][spokeId] = new_value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
hook Sload uint200 value hub._spokes[KEY uint256 assetId][KEY address spokeId].deficitRay {
    require spokeDeficitMirror[assetId][spokeId] == value;
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}
/**** Valid State Rules *******/



/** @title Integrity of a validAsset 
* @link_property valid state
**/
invariant validAssetId(uint256 assetId)
    // Ensure that the underlying 0 is not valid
    hub._underlyingToAssetId[0] == 0 &&
    // And assetId above assetCount is empty
    (assetId >= hub._assetCount => emptyAsset(assetId)) &&
    // Existence of the asset
    (assetId < hub._assetCount =>
        // Uniqueness of underlying
        (hub._underlyingToAssetId[hub._assets[assetId].underlying] == assetId) &&
        // Each underlying has a unique assetID
        (forall address underlying. (underlying != 0 && hub._underlyingToAssetId[underlying] != 0) =>
            (hub._underlyingToAssetId[underlying] < hub._assetCount && hub._assets[hub._underlyingToAssetId[underlying]].underlying == underlying)
        &&
        (hub._underlyingToAssetId[underlying] == 0 && hub._assetCount > 0 => hub._assets[0].underlying == underlying))
        && (forall uint256 otherAssetId. (otherAssetId != assetId && otherAssetId < hub._assetCount) => hub._assets[otherAssetId].underlying != hub._assets[assetId].underlying))
    filtered {f -> f.selector != sig:hub.addAsset(address,uint8,address,address,bytes).selector}
    {
        preserved {
            requireInvariant assetToSpokesIntegrity(assetId);
            requireInvariant validAssetId(hub._assetCount);
        }
    }

/**
 * @title Integrity of a valid asset, with specific underlying to help grounding on addAsset call
 * @link_property valid state
 */
invariant validAssetId_underlying(uint256 assetId, address underlying, uint256 otherAssetId)
    // Ensure that the underlying 0 is not valid
    hub._underlyingToAssetId[0] == 0 &&
    // And assetId above assetCount is empty
    (assetId >= hub._assetCount => emptyAsset(assetId)) &&
    // Existence of the asset
    (assetId < hub._assetCount =>
        // Uniqueness of underlying
        (hub._underlyingToAssetId[hub._assets[assetId].underlying] == assetId) &&
        // Each underlying has a unique assetID
        (underlying != 0 && hub._underlyingToAssetId[underlying] != 0 =>
            (hub._underlyingToAssetId[underlying] < hub._assetCount && hub._assets[hub._underlyingToAssetId[underlying]].underlying == underlying))
        &&
        (hub._underlyingToAssetId[underlying] == 0 && hub._assetCount > 0 => hub._assets[0].underlying == underlying) &&
        (otherAssetId != assetId && otherAssetId < hub._assetCount) => hub._assets[otherAssetId].underlying != hub._assets[assetId].underlying)
    {
        preserved {
            requireInvariant assetToSpokesIntegrity(assetId);
            requireInvariant validAssetId(hub._assetCount);
        }
        preserved addAsset(address underlying_arg, uint8 decimals, address feeReceiver, address irStrategy, bytes irData) with (env e) {
            require hub._assetCount < 5;
            requireInvariant validAssetId(0);
            requireInvariant validAssetId(1);
            requireInvariant validAssetId(2);
            requireInvariant validAssetId(3);
            requireInvariant validAssetId(4);
            require underlying_arg == underlying;
        }
    }




/**
 * @title The sum of hub._spokes[assetId][spoke].addedShares for all spoke equals to hub._assets[assetId].addedShares
 * @link_property valid state of aggregated data
 */
invariant sumOfSpokeSupplyShares(uint256 assetId)
    hub._assets[assetId].addedShares == (usum address spokeId. spokeAddedSharesMirror[assetId][spokeId])
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title The sum of hub._spokes[assetId][spoke].drawnShares for all spoke equals to hub._assets[assetId].drawnShares
 * @link_property valid state of aggregated data
 */
invariant sumOfSpokeDrawnShares(uint256 assetId)
    hub._assets[assetId].drawnShares == (usum address spokeId. spokeDrawnSharesMirror[assetId][spokeId])
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title The sum of hub._spokes[assetId][spoke].premiumShares for all spoke equals to hub._assets[assetId].premiumShares
 * @link_property valid state of aggregated data
 */
invariant sumOfSpokePremiumDrawnShares(uint256 assetId)
    hub._assets[assetId].premiumShares == (usum address spokeId. spokePremiumSharesMirror[assetId][spokeId])
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title The sum of hub._spokes[assetId][spoke].premiumOffsetRay for all spoke equals to hub._assets[assetId].premiumOffsetRay
 * @link_property valid state of aggregated data
 */
invariant sumOfSpokePremiumOffset(uint256 assetId)
    hub._assets[assetId].premiumOffsetRay == (sum address spokeId. spokePremiumOffsetMirror[assetId][spokeId])
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title The sum of hub._spokes[assetId][spoke].deficitRay for all spoke equals to hub._assets[assetId].deficitRay
 * @link_property valid state of aggregated data
 */
invariant sumOfSpokeDeficit(uint256 assetId)
    hub._assets[assetId].deficitRay == (usum address spokeId. spokeDeficitMirror[assetId][spokeId])
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title DrawnIndex is greater than or equal to RAY on listed assets
 * @link_property valid state
 */
invariant drawnIndexMin(uint256 assetId)
    assetId < hub._assetCount => hub._assets[assetId].drawnIndex >= RAY
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/**
 * @title LiquidityFee upper bound: config.liquidityFee must not exceed PercentageMathExtended.PERCENTAGE_FACTOR
 * @link_property valid state
 */
invariant liquidityFee_upper_bound(uint256 assetId)
    hub._assets[assetId].liquidityFee <= PERCENTAGE_FACTOR;


/**
 * @title PremiumOffsetRay must not exceed the premiumShares on asset and spoke level
 * @link_property valid state
 */
invariant premiumOffset_Integrity(uint256 assetId, address spokeId)
    hub._assets[assetId].premiumShares * hub._assets[assetId].drawnIndex >= hub._assets[assetId].premiumOffsetRay &&
    hub._spokes[assetId][spokeId].premiumShares * hub._assets[assetId].drawnIndex >= hub._spokes[assetId][spokeId].premiumOffsetRay 
    {
        preserved  with (env e1) {
            requireAllInvariants(assetId, e1);
        }

    }


/**
 * @title External balance is at least as internal accounting
 * @link_property solvency
 */
strong invariant solvency_external(uint256 assetId)
    balanceByToken[hub._assets[assetId].underlying][hub] >= hub._assets[assetId].liquidity 
    {
        preserved  with (env e1) {
            require e1.msg.sender != hub;
            requireAllInvariants(assetId, e1);
        }
        
        preserved remove(uint256 assetId2, uint256 amount, address to) with (env e2)
        {
            requireAllInvariants(assetId2, e2);
            requireAllInvariants(assetId, e2);
        } 
        preserved draw(uint256 assetId2, uint256 amount, address to) with (env e3)
        {
            requireAllInvariants(assetId2, e3);
            requireAllInvariants(assetId, e3);
        } 

    }


/**
 * @title The sum of added assets is greater than or equal to the sum of added shares
 * @link_property share rate integrity
 */
invariant totalAssetsVsShares(uint256 assetId, env e)
    hub.getAddedAssets(e, assetId) >= hub.getAddedShares(e, assetId)
    // Specific rule below
    filtered {f -> f.selector != sig:hub.eliminateDeficit(uint256,uint256,address).selector}
    {
        preserved with (env eInv) {
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }

/**
 * @title Total assets vs shares for eliminateDeficit
 * @link_property share rate integrity
 */
rule totalAssetsVsShares_eliminateDeficit(uint256 assetId, uint256 amount, address spokeId) {
    env e;
    requireAllInvariants(assetId, e);
    requireInvariant premiumOffset_Integrity(assetId, e.msg.sender);
    eliminateDeficit(e, assetId, amount, spokeId);
    assert hub.getAddedAssets(e, assetId) >= hub.getAddedShares(e, assetId);
}
// Store hook to synchronize assetToSpokeLength with the length of the set._inner._values array.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._values.length uint256 newLength {
    assetToSpokeLength[assetId] = newLength;
}

// Store hook to synchronize assetToSpokeValues array with set._inner._values.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._values[INDEX uint256 index] bytes32 newValue {
    assetToSpokeValues[assetId][index] = newValue;
}

// Store hook to synchronize assetToSpokeIndexes array with set._inner._positions.
hook Sstore hub._assetToSpokes[KEY uint256 assetId]._inner._positions[KEY bytes32 value] uint256 newIndex {
    assetToSpokeIndexes[assetId][value] = newIndex;
}

// The load hooks can use require to ensure that the ghost field has the same information as the storage.
// The require is sound, since the store hooks ensure the contents are always the same. However we cannot
// prove that with invariants, since this would require the invariant to read the storage for all elements
// and neither storage access nor function calls are allowed in quantifiers.
//
// By following this simple pattern it is ensured that the ghost state and the storage are always the same
// and that the solver can use this knowledge in the proofs.

// Load hook to synchronize assetToSpokeLength with the length of the set._inner._values array.
hook Sload uint256 length hub._assetToSpokes[KEY uint256 assetId]._inner._values.length {
    require assetToSpokeLength[assetId] == length;
}

hook Sload bytes32 value hub._assetToSpokes[KEY uint256 assetId]._inner._values[INDEX uint256 index] {
    require assetToSpokeValues[assetId][index] == value;
}

hook Sload uint256 index hub._assetToSpokes[KEY uint256 assetId]._inner._positions[KEY bytes32 value] {
    require assetToSpokeIndexes[assetId][value] == index;
}

/**
 * @title AssetToSpokes integrity: indexes and values always match
 * @notice This is the main invariant stating that the indexes and values always match:
 *         values[indexes[v] - 1] = v for all values v in the set
 *         and indexes[values[i]] = i+1 for all valid indexes i.
 * @link_property valid state
 */
invariant assetToSpokesIntegrity(uint256 assetId)
    (forall uint256 index. 0 <= index && index < assetToSpokeLength[assetId] => to_mathint(assetToSpokeIndexes[assetId][assetToSpokeValues[assetId][index]]) == index + 1)
    && (forall bytes32 value. assetToSpokeIndexes[assetId][value] == 0 ||
        (assetToSpokeValues[assetId][assetToSpokeIndexes[assetId][value] - 1] == value && assetToSpokeIndexes[assetId][value] >= 1 && assetToSpokeIndexes[assetId][value] <= assetToSpokeLength[assetId])); 