
/**

Verify Spoke.sol

Spoke internal properties using a symbolic representation of the Hub.

To run this spec, run:
certoraRun certora/conf/Spoke.conf

**/
import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

/* Assumption: userGhost is the user who is interacting with the Spoke contract.
It is used to track the user who is interacting with the Spoke contract.
In SpokeUserIntegrity.spec, we prove that only one user's account is updated and used at a time.
*/
// Hooks to track userGhost 
hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    require userGhost == user;
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares {
    require userGhost == user;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    require userGhost == user;
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].drawnShares {
    require userGhost == user;
}

/**
Verify functions that increase collateral or reduce debt and therefore do not need to perform a health check
**/
rule increaseCollateralOrReduceDebtFunctions(method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView && increaseCollateralOrReduceDebtFunctions(f)}  {
    uint256 reserveId; uint256 slot;
    address user;
    env e;
    setup();
    requireInvariant validReserveId_single(reserveId);
    require userGhost == user;

    //user state before the operation
    bool beforePositionStatus_borrowing = isBorrowing[user][reserveId];
    bool beforePositionStatus_usingAsCollateral = isUsingAsCollateral[user][reserveId];
    uint120 beforeUserPosition_drawnShares = spoke._userPositions[user][reserveId].drawnShares;
    uint120 beforeUserPosition_premiumShares = spoke._userPositions[user][reserveId].premiumShares;
    int200 beforeUserPosition_premiumOffsetRay = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint120 beforeUserPosition_suppliedShares = spoke._userPositions[user][reserveId].suppliedShares;
    uint32 beforeUserPosition_dynamicConfigKey = spoke._userPositions[user][reserveId].dynamicConfigKey;


    mathint premiumDebtBefore = (spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e))- spoke._userPositions[user][reserveId].premiumOffsetRay;

    // Execute the operation 
    calldataarg args;
    f(e, args);
    
    // user state after the operation
    bool afterPositionStatus_borrowing = isBorrowing[user][reserveId];
    bool afterPositionStatus_usingAsCollateral = isUsingAsCollateral[user][reserveId];
    uint120 afterUserPosition_drawnShares = spoke._userPositions[user][reserveId].drawnShares;
    uint120 afterUserPosition_premiumShares = spoke._userPositions[user][reserveId].premiumShares;
    int200 afterUserPosition_premiumOffsetRay = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint120 afterUserPosition_suppliedShares = spoke._userPositions[user][reserveId].suppliedShares;
    uint32 afterUserPosition_dynamicConfigKey = spoke._userPositions[user][reserveId].dynamicConfigKey;

    mathint premiumDebtAfter = (spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e)) - spoke._userPositions[user][reserveId].premiumOffsetRay;
    
    assert beforePositionStatus_borrowing == afterPositionStatus_borrowing || 
    (beforePositionStatus_borrowing && !afterPositionStatus_borrowing && afterUserPosition_drawnShares == 0 && afterUserPosition_premiumShares == 0 && afterUserPosition_premiumOffsetRay == 0);

    assert beforePositionStatus_usingAsCollateral == afterPositionStatus_usingAsCollateral;
    assert beforeUserPosition_drawnShares >= afterUserPosition_drawnShares;
    /* repay is proved in SpokeHubIntegrity.spec that it reduces the premium debt and drawn shares */
    if (f.selector != sig:repay(uint256, uint256, address).selector) {
        assert premiumDebtBefore >= premiumDebtAfter;
    } 
    assert beforeUserPosition_suppliedShares <= afterUserPosition_suppliedShares;
    assert beforeUserPosition_dynamicConfigKey == afterUserPosition_dynamicConfigKey;
}

/**
Verify that borrowing flag is set if and only if there are drawn shares
**/
invariant isBorrowingIFFdrawnShares()  
forall uint256 reserveId. forall address user.
    spoke._userPositions[user][reserveId].drawnShares > 0   <=>  isBorrowing[user][reserveId]
filtered {f -> !outOfScopeFunctions(f)}


/**
Verify that if there are no drawn shares, then there are no premium shares or offset
**/
invariant drawnSharesZero(address user, uint256 reserveId) 
    spoke._userPositions[user][reserveId].drawnShares == 0 => (  spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0) 
    filtered {f -> !outOfScopeFunctions(f) && 
    // repay is proved in SpokeHubIntegrity.spec repay_zeroDebt
    f.selector != sig:repay(uint256, uint256, address).selector
    }
    {
        preserved with (env e) {
            setup();
        }
    }
    



invariant validReserveId()
forall uint256 reserveId. forall address user.
    // exists
    (reserveId < spoke._reserveCount  => 
    // has underlying, hub, and reverse map points to this reserve
    listedReserveId(reserveId)
    &&
    // not exists
    (reserveId >= spoke._reserveCount => ( 
    // no one borrowed or used as collateral
    !isBorrowing[user][reserveId] && !isUsingAsCollateral[user][reserveId]
    // no supplied or drawn shares
    && spoke._userPositions[user][reserveId].suppliedShares == 0 && spoke._userPositions[user][reserveId].drawnShares == 0 &&
    // no premium shares or offset
    spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0 &&

    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0  && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 )))

    filtered {f -> f.selector != sig:multicall(bytes[]).selector && f.selector != sig:liquidationCall(uint256, uint256, address, uint256, bool).selector}


invariant validReserveId_single(uint256 reserveId)
 
    // exists
    (reserveId < spoke._reserveCount  => 
    // has underlying, hub, and reverse map points to this reserve
    listedReserveId(reserveId))
    &&
    // not exists
    (reserveId >= spoke._reserveCount =>
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0  && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 && 
    
    (forall address user. 
    // no one borrowed or used as collateral
    !isBorrowing[user][reserveId] && !isUsingAsCollateral[user][reserveId]
    // no supplied or drawn shares
    && spoke._userPositions[user][reserveId].suppliedShares == 0 && spoke._userPositions[user][reserveId].drawnShares == 0 &&
    // no premium shares or offset
    spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0 ))

    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved {
            requireInvariant validReserveId_single(reserveId);
        }
    }

// need to help the grounding, proven in validReserveId_single
function validReserveId_singleUser(uint256 reserveId, address user)  {
    require
    (reserveId < spoke._reserveCount  => 
    // has underlying, hub, and reverse map points to this reserve
    listedReserveId(reserveId))
    &&
    // not exists
    (reserveId >= spoke._reserveCount =>
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0  && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 && 
    spoke._dynamicConfig[reserveId][0].collateralFactor == 0 &&
    // no one borrowed or used as collateral
    !isBorrowing[user][reserveId] && !isUsingAsCollateral[user][reserveId]
    // no supplied or drawn shares
    && spoke._userPositions[user][reserveId].suppliedShares == 0 && spoke._userPositions[user][reserveId].drawnShares == 0 &&
    // no premium shares or offset
    spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0 );
}


/**
Verify that the assetId and hub are unique to a reserveId
**/
invariant uniqueAssetIdPerReserveId(uint256 reserveId, uint256 otherReserveId) 
    (reserveId < spoke._reserveCount && otherReserveId < spoke._reserveCount  && reserveId != otherReserveId ) => (spoke._reserves[reserveId].assetId != spoke._reserves[otherReserveId].assetId  || spoke._reserves[reserveId].hub != spoke._reserves[otherReserveId].hub)
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved {
            requireInvariant validReserveId_single(reserveId);
            requireInvariant validReserveId_single(otherReserveId);
        }

    }

/**
Verify that the realized premium ray is consistent with the premium shares and drawn index
**/
rule realizedPremiumRayConsistency(uint256 reserveId, address user, method f)
    filtered {f -> !outOfScopeFunctions(f) && !f.isView}
{
    env e;
    setup();
    requireInvariant validReserveId_single(reserveId);
    require userGhost == user;
    require spoke._userPositions[user][reserveId].premiumOffsetRay <= spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e);
    calldataarg args;
    f(e, args);
    assert spoke._userPositions[user][reserveId].premiumOffsetRay <= spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e);
}

/**
Verify that if there is no collateral, then there is no debt
**/
rule noCollateralNoDebt(uint256 reserveIdUsed, address user, method f) 
    filtered {f -> !outOfScopeFunctions(f) && !f.isView && increaseCollateralOrReduceDebtFunctions(f)} {
    env e;
    setup();
    requireInvariant validReserveId_single(reserveIdUsed);
    requireInvariant dynamicConfigKeyConsistency(reserveIdUsed,user);
    validReserveId_singleUser(reserveIdUsed, user);
    validReserveId_singleUser(spoke._reserveCount, user);
    require userGhost == user;
    ISpoke.UserAccountData beforeUserAccountData = getUserAccountData(e,user);
    uint32 dynamicConfigKey = spoke._reserves[reserveIdUsed].dynamicConfigKey;
    uint16 beforeCollateralFactor = spoke._dynamicConfig[reserveIdUsed][dynamicConfigKey].collateralFactor;
    require beforeUserAccountData.totalCollateralValue == 0 => beforeUserAccountData.totalDebtValueRay == 0;

    calldataarg args;
    f(e, args);

    ISpoke.UserAccountData afterUserAccountData = getUserAccountData(e,user);
    uint32 dynamicConfigKeyAfter = spoke._reserves[reserveIdUsed].dynamicConfigKey;
    uint16 afterCollateralFactor = spoke._dynamicConfig[reserveIdUsed][dynamicConfigKeyAfter].collateralFactor;
    if (f.selector == sig:addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig).selector) {
        // assume we are working on reserveIdUsed
        require dynamicConfigKeyAfter != dynamicConfigKey;
    }
    require  beforeCollateralFactor > 0 => afterCollateralFactor > 0, "rule collateralFactorNotZero";
    assert afterUserAccountData.totalCollateralValue == 0 => afterUserAccountData.totalDebtValueRay == 0;
}

/**
Verify that the collateral factor is not zero once set to a non-zero value
**/

rule collateralFactorNotZero(uint256 reserveId, address user, method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView} {
    env e;
    setup();
    requireInvariant dynamicConfigKeyConsistency(reserveId,user);
    validReserveId_singleUser(reserveId, user);
    require userGhost == user;
    uint32 dynamicConfigKey;
    require dynamicConfigKey <= spoke._reserves[reserveId].dynamicConfigKey;
    require spoke._dynamicConfig[reserveId][dynamicConfigKey].collateralFactor > 0;
    calldataarg args;
    f(e, args);
    assert spoke._dynamicConfig[reserveId][dynamicConfigKey].collateralFactor > 0;
}



/**
Verify that the user debt value is deterministic
**/
rule deterministicUserDebtValue(uint256 reserveId, address user) {
    env e;
    setup();
    require userGhost == user;
    uint256 drawnDebt; uint256 premiumDebt;
    (drawnDebt, premiumDebt) = spoke.getUserDebt(e, reserveId, user);
    uint256 drawnDebt2; uint256 premiumDebt2;
    (drawnDebt2, premiumDebt2) = spoke.getUserDebt(e, reserveId, user);
    assert drawnDebt == drawnDebt2;
    assert premiumDebt == premiumDebt2;
}

/**
Verify that the dynamic config key is consistent with the reserve dynamic config key
**/
invariant dynamicConfigKeyConsistency(uint256 reserveId, address user)
    spoke._userPositions[user][reserveId].dynamicConfigKey <= spoke._reserves[reserveId].dynamicConfigKey
    filtered {f -> !outOfScopeFunctions(f)}
{
    preserved {
        setup();
        requireInvariant validReserveId_single(reserveId);
    }
}
