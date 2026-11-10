/**
 * @title Spoke Hub Integrity Specification
 * @notice Verify the integrity of the Spoke contract related to Hub
 * @dev Assumption: the Hub is the specific implementation in Hub.sol
 *
 * To run this spec:
 * certoraRun certora/conf/SpokeWithHub.conf
 */

import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicPositionStatus.spec";
import "./HubValidState.spec";

// Note: 'spoke' alias is declared in SpokeBase.spec
// Note: 'hub' alias is declared in HubValidState.spec



////////////////////////////////////////////////////////////////////////////
//                              GHOST VARIABLES                           //
////////////////////////////////////////////////////////////////////////////

/// Sum of all user supplied shares per reserveId
ghost mapping(uint256 /*reserveId*/ => mathint /*source*/) sumUserSuppliedSharesPerReserveId {
    init_state axiom forall uint256 reserveId. sumUserSuppliedSharesPerReserveId[reserveId] == 0;
}

/// Sum of all user drawn shares per reserveId
ghost mapping(uint256 /*reserveId*/ => mathint /*source*/) sumUserDrawnSharesPerReserveId {
    init_state axiom forall uint256 reserveId. sumUserDrawnSharesPerReserveId[reserveId] == 0;
}

/// Sum of all user premium shares per reserveId
ghost mapping(uint256 /*reserveId*/ => mathint /*source*/) sumUserPremiumSharesPerReserveId {
    init_state axiom forall uint256 reserveId. sumUserPremiumSharesPerReserveId[reserveId] == 0;
}

/// Sum of all user premium offset per reserveId
ghost mapping(uint256 /*reserveId*/ => mathint /*source*/) sumUserPremiumOffsetPerReserveId {
    init_state axiom forall uint256 reserveId. sumUserPremiumOffsetPerReserveId[reserveId] == 0;
}

////////////////////////////////////////////////////////////////////////////
//                                  HOOKS                                 //
////////////////////////////////////////////////////////////////////////////

// Hook on sstore and sload to synchronize the ghost with storage changes
hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    sumUserSuppliedSharesPerReserveId[reserveId] = sumUserSuppliedSharesPerReserveId[reserveId] + newValue - oldValue;
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares {
    require sumUserSuppliedSharesPerReserveId[reserveId] >= value;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    sumUserDrawnSharesPerReserveId[reserveId] = sumUserDrawnSharesPerReserveId[reserveId] + newValue - oldValue;
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].drawnShares {
    require sumUserDrawnSharesPerReserveId[reserveId] >= value;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumShares uint120 newValue (uint120 oldValue) {
    sumUserPremiumSharesPerReserveId[reserveId] = sumUserPremiumSharesPerReserveId[reserveId] + newValue - oldValue;
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].premiumShares {
    require sumUserPremiumSharesPerReserveId[reserveId] >= value;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay int200 newValue (int200 oldValue) {
    sumUserPremiumOffsetPerReserveId[reserveId] = sumUserPremiumOffsetPerReserveId[reserveId] + to_mathint(newValue) - to_mathint(oldValue);
}

////////////////////////////////////////////////////////////////////////////
//                              INVARIANTS                                //
////////////////////////////////////////////////////////////////////////////



/**
 * @title Verify that the sum of users' drawn shares for a reserveId are consistent with the Hub drawn Shares for the Spoke
 * @link_property Spoke Hub consistency
 */
invariant userDrawnShareConsistency(uint256 reserveId) 
    sumUserDrawnSharesPerReserveId[reserveId] == hub._spokes[spoke._reserves[reserveId].assetId][spoke].drawnShares &&
    ( reserveId >= spoke._reserveCount => 
        sumUserDrawnSharesPerReserveId[reserveId] == 0
    ) 
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved  with (env e) {
            require e.msg.sender != spoke;
            safeAssumptions();
        }
        preserved constructor() {
            require hub._spokes[spoke._reserves[reserveId].assetId][spoke].drawnShares == 0;
        }
        preserved addReserve(address hub_, uint256 assetId_arg, address priceSource, ISpoke.ReserveConfig config, ISpoke.DynamicReserveConfig  dynamicConfig) with (env e) {
            require hub_ == hub && assetId_arg == spoke._reserves[reserveId].assetId;
            safeAssumptions();
        }
        preserved repay(uint256 otherReserveId, uint256 amount, address onBehalfOf) with (env e) {
            safeAssumptions();
            //proved in spoke.spec : uniqueAssetIdPerReserveId
            require (reserveId < spoke._reserveCount && otherReserveId < spoke._reserveCount && reserveId != otherReserveId ) => (spoke._reserves[reserveId].assetId != spoke._reserves[otherReserveId].assetId );
        }
        preserved borrow(uint256 otherReserveId, uint256 amount, address onBehalfOf) with (env e) {
            safeAssumptions();
            //proved in spoke.spec : uniqueAssetIdPerReserveId
            require (reserveId < spoke._reserveCount && otherReserveId < spoke._reserveCount && reserveId != otherReserveId ) => (spoke._reserves[reserveId].assetId != spoke._reserves[otherReserveId].assetId );
        }

    }

/**
 * @title Verify that the sum of users' premium shares for a reserveId are consistent with the Hub premium shares for the Spoke
 * @link_property Spoke Hub consistency
 */
invariant userPremiumShareConsistency(uint256 reserveId) 
    sumUserPremiumSharesPerReserveId[reserveId] == hub._spokes[spoke._reserves[reserveId].assetId][spoke].premiumShares &&
    ( reserveId >= spoke._reserveCount => 
        sumUserPremiumSharesPerReserveId[reserveId] == 0
    )
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved  with (env e) {
            require e.msg.sender != spoke;
            safeAssumptions();
        }
        preserved constructor() {
            require hub._spokes[spoke._reserves[reserveId].assetId][spoke].premiumShares == 0;
        }
       preserved addReserve(address hub_, uint256 assetId_arg, address priceSource, ISpoke.ReserveConfig config, ISpoke.DynamicReserveConfig  dynamicConfig) with (env e) {
            require hub_ == hub && assetId_arg == spoke._reserves[reserveId].assetId;
            safeAssumptions();
        }
    }

/**
 * @title Verify that the sum of users' premium offset for a reserveId are consistent with the Hub premium offset for the Spoke
 * @link_property Spoke Hub consistency
 */
invariant userPremiumOffsetConsistency(uint256 reserveId) 
    sumUserPremiumOffsetPerReserveId[reserveId] == hub._spokes[spoke._reserves[reserveId].assetId][spoke].premiumOffsetRay &&
    ( reserveId >= spoke._reserveCount => 
        sumUserPremiumOffsetPerReserveId[reserveId] == 0
    ) 
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved  with (env e) {
            require e.msg.sender != spoke;
            safeAssumptions();
        }
        preserved constructor() {
            require hub._spokes[spoke._reserves[reserveId].assetId][spoke].premiumOffsetRay == 0;
        }
       preserved addReserve(address hub_, uint256 assetId_arg, address priceSource, ISpoke.ReserveConfig config, ISpoke.DynamicReserveConfig  dynamicConfig) with (env e) {
            require hub_ == hub && assetId_arg == spoke._reserves[reserveId].assetId;
            safeAssumptions();
        }
    }


/**
 * @title Verify that the sum of users' supplied shares for a reserveId are consistent with the Hub supplied shares for the Spoke
 * @link_property Spoke Hub consistency
 */
invariant userSuppliedShareConsistency(uint256 reserveId, uint256 assetId_) 
    sumUserSuppliedSharesPerReserveId[reserveId] <= hub._spokes[spoke._reserves[reserveId].assetId][spoke].addedShares
    && 
    ( reserveId >= spoke._reserveCount => 
        sumUserSuppliedSharesPerReserveId[reserveId] == 0
    )
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved  with (env e) {
            require e.msg.sender != spoke;
            safeAssumptions();
            require hub._assets[spoke._reserves[reserveId].assetId].feeReceiver != spoke;
            require hub._assets[assetId_].feeReceiver != spoke;
        }
        preserved addReserve(address hub_, uint256 assetId_arg, address priceSource, ISpoke.ReserveConfig config, ISpoke.DynamicReserveConfig  dynamicConfig) with (env e) {
            require hub_ == hub && assetId_arg == assetId_;
            safeAssumptions();
            require hub._assets[spoke._reserves[reserveId].assetId].feeReceiver != spoke;
            require hub._assets[assetId_].feeReceiver != spoke;
        }
    }


/**
 * @title Verify that the repay function reduces the debt of a user
 * @link_property Spoke Hub consistency
 */
rule repay_debtDecrease(uint256 reserveId, uint256 amount, address user) {
    env e;
    safeAssumptions();
    requireAllInvariants(spoke._reserves[reserveId].assetId, e);
    requireInvariant premiumOffset_Integrity(spoke._reserves[reserveId].assetId, spoke); 

    require userGhost == user;
    
    uint120 beforeUserPosition_drawnShares = spoke._userPositions[user][reserveId].drawnShares;

    mathint premiumDebtBefore = (spoke._userPositions[user][reserveId].premiumShares * cachedIndex)- spoke._userPositions[user][reserveId].premiumOffsetRay;
    spoke.repay(e, reserveId, amount, user);

    uint120 afterUserPosition_drawnShares = spoke._userPositions[user][reserveId].drawnShares;

    mathint premiumDebtAfter = (spoke._userPositions[user][reserveId].premiumShares * cachedIndex)- spoke._userPositions[user][reserveId].premiumOffsetRay;
    

    assert premiumDebtBefore >= premiumDebtAfter;
    assert beforeUserPosition_drawnShares >= afterUserPosition_drawnShares;
    
}

/**
 * @title Verify that if the user has no drawn shares, then there are no premium shares or offset. 
 * @link_property Spoke Hub consistency
 */
rule repay_zeroDebt(uint256 reserveId, uint256 amount, address user) {
    env e;
    require spoke._userPositions[user][reserveId].drawnShares == 0 => (  spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0);

    spoke.repay(e, reserveId, amount, user);

    assert spoke._userPositions[user][reserveId].drawnShares == 0 => (  spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0);
}

function safeAssumptions() {
    // rules proved in spoke.spec and assuming one hub
    require forall uint256 reserveId. forall uint256 otherReserveId. 
    (reserveId != otherReserveId ) => spoke._reserves[reserveId].assetId != spoke._reserves[otherReserveId].assetId ;

    // a reserveId that exists has underlying and hub
    require forall uint256 reserveId. (reserveId < spoke._reserveCount  => 
    // has underlying and hub
    (spoke._reserves[reserveId].underlying != 0 && spoke._reserves[reserveId].hub == hub && spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] != 0 ));

    // a reserveId that does not exist has no underlying, hub, assetId
    require forall uint256 reserveId. reserveId >= spoke._reserveCount => (
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0  && spoke._reserves[reserveId].dynamicConfigKey == 0); 

    // based on hubValidState.spec : validAssetId 
    require forall uint256 assetId. assetId >= hub._assetCount => (
        hub._assets[assetId].addedShares == 0 &&
        hub._assets[assetId].drawnShares == 0 &&
        hub._assets[assetId].premiumShares == 0 &&
        hub._assets[assetId].premiumOffsetRay == 0 &&
        hub._assets[assetId].drawnIndex == 0 &&
        hub._assets[assetId].drawnRate == 0 &&
        hub._assets[assetId].lastUpdateTimestamp == 0 &&
        hub._spokes[assetId][spoke].addedShares == 0 &&
        hub._spokes[assetId][spoke].drawnShares == 0 &&
        hub._spokes[assetId][spoke].premiumShares == 0  &&
        hub._spokes[assetId][spoke].premiumOffsetRay == 0 &&
        !hub._spokes[assetId][spoke].active
        );

}