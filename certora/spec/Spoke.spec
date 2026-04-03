
/**
 * @title Spoke Contract Specification
 * @notice Verify Spoke.sol internal properties and valid state invariants using a symbolic representation of the Hub
 * @dev This spec verifies Spoke contract invariants and state properties
 *
 * To run this spec:
 * certoraRun certora/conf/Spoke.conf
 */

import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicPositionStatus.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

// Definition moved from SpokeBase.spec as it depends on getAssetDrawnIndexCVL from SymbolicHub.spec
definition premiumDebtCVL(address user, uint256 reserveId, env e) returns mathint =
    (spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e)) - spoke._userPositions[user][reserveId].premiumOffsetRay;

////////////////////////////////////////////////////////////////////////////
//                                 HOOKS                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @notice Assumption: userGhost is the user who is interacting with the Spoke contract.
 * It is used to track the user who is interacting with the Spoke contract.
 * In SpokeUserIntegrity.spec, we prove that only one user's account is updated and used in a single operation.
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

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Verify functions that increase collateral or reduce debt
 * @notice These functions do not need to perform a health check
 * @link_property Health check validity
 */
rule increaseCollateralOrReduceDebtFunctions(method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView && increaseCollateralOrReduceDebtFunctions(f)} {
    uint256 reserveId;
    uint256 slot;
    address user;
    env e;
    setup();
    requireInvariant validReserveId_single(reserveId);
    requireInvariant validReserveId_singleUser(reserveId, user);
    requireInvariant drawnSharesRiskEQPremiumShares(user, reserveId);
    require userGhost == user;

    // user state before the operation
    bool beforePositionStatus_borrowing = isBorrowing[user][reserveId];
    bool beforePositionStatus_usingAsCollateral = isUsingAsCollateral[user][reserveId];
    uint120 beforeUserPosition_drawnShares = spoke._userPositions[user][reserveId].drawnShares;
    uint120 beforeUserPosition_premiumShares = spoke._userPositions[user][reserveId].premiumShares;
    int200 beforeUserPosition_premiumOffsetRay = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint120 beforeUserPosition_suppliedShares = spoke._userPositions[user][reserveId].suppliedShares;
    uint32 beforeUserPosition_dynamicConfigKey = spoke._userPositions[user][reserveId].dynamicConfigKey;

    mathint premiumDebtBefore = premiumDebtCVL(user, reserveId, e);

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

    mathint premiumDebtAfter = premiumDebtCVL(user, reserveId, e);

    assert beforePositionStatus_borrowing == afterPositionStatus_borrowing ||
           (beforePositionStatus_borrowing && !afterPositionStatus_borrowing && afterUserPosition_drawnShares == 0 && afterUserPosition_premiumShares == 0 && afterUserPosition_premiumOffsetRay == 0);

    assert beforePositionStatus_usingAsCollateral == afterPositionStatus_usingAsCollateral;
    assert beforeUserPosition_drawnShares >= afterUserPosition_drawnShares;
    assert premiumDebtBefore >= premiumDebtAfter;
    assert beforeUserPosition_suppliedShares <= afterUserPosition_suppliedShares;
    assert beforeUserPosition_dynamicConfigKey == afterUserPosition_dynamicConfigKey;
}

/**
 * @title If paused - no change
 * @link_property Pause behavior
 */
rule paused_noChange(uint256 reserveId, address user, method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView} {
    env e;
    calldataarg args;
    setup();

    bool isPaused = pausedGhost;
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    f(e, args);

    assert isPaused => (
        spoke._userPositions[user][reserveId].drawnShares == drawnSharesBefore &&
        spoke._userPositions[user][reserveId].suppliedShares == suppliedSharesBefore);
}

/**
 * @title If frozen - functions can only reduce debt and reduce collateral
 * @link_property Frozen behavior
 */
rule frozen_onlyReduceDebtAndCollateral(uint256 reserveId, address user, method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView} {
    env e;
    calldataarg args;
    setup();
    requireInvariant drawnSharesRiskEQPremiumShares(user, reserveId);
    requireInvariant validReserveId_single(reserveId);
    requireInvariant validReserveId_singleUser(reserveId, user);
    bool isFrozen = frozenGhost;
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;
    mathint premiumDebtBefore = premiumDebtCVL(user, reserveId, e);

    f(e, args);

    mathint premiumDebtAfter = premiumDebtCVL(user, reserveId, e);
    assert isFrozen => (
        spoke._userPositions[user][reserveId].drawnShares <= drawnSharesBefore &&
        premiumDebtAfter <= premiumDebtBefore &&
        spoke._userPositions[user][reserveId].suppliedShares <= suppliedSharesBefore);
}

/**
 * @title updateUserRiskPremium preserves premium debt
 * @link_property valid state
 */
rule updateUserRiskPremium_preservesPremiumDebt(uint256 reserveId, address user) {
    env e;
    calldataarg args;
    setup();
    requireInvariant drawnSharesRiskEQPremiumShares(user, reserveId);
    requireInvariant validReserveId_single(reserveId);

    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;

    mathint premiumDebtBefore = premiumDebtCVL(user, reserveId, e);
    spoke.updateUserRiskPremium(e, user);

    mathint premiumDebtAfter = premiumDebtCVL(user, reserveId, e);

    assert spoke._userPositions[user][reserveId].drawnShares == drawnSharesBefore &&
           premiumDebtAfter == premiumDebtBefore;
}

/**
 * @title Verify that if there is no collateral, then there is no debt
 * @link_property valid state
 */
rule noCollateralNoDebt(uint256 reserveIdUsed, address user, method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView} {
    env e;
    setup();
    require userGhost == user;
    requireInvariant validReserveId_single(reserveIdUsed);
    requireInvariant validReserveId_singleUser(spoke._reserveCount, user);
    requireInvariant dynamicConfigKeyConsistency(reserveIdUsed, user);

    ISpoke.UserAccountData beforeUserAccountData = getUserAccountData(e, user);
    uint32 dynamicConfigKey = spoke._reserves[reserveIdUsed].dynamicConfigKey;
    uint16 beforeCollateralFactor = spoke._dynamicConfig[reserveIdUsed][dynamicConfigKey].collateralFactor;
    require beforeUserAccountData.totalCollateralValue == 0 => beforeUserAccountData.totalDebtValueRay == 0;

    if (f.selector == sig:addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig).selector) {
        ISpoke.DynamicReserveConfig config;
        // assume we are working on reserveIdUsed
        addDynamicReserveConfig(e, reserveIdUsed, config);
    } else {
        calldataarg args;
        f(e, args);
    }

    ISpoke.UserAccountData afterUserAccountData = getUserAccountData(e, user);
    uint32 dynamicConfigKeyAfter = spoke._reserves[reserveIdUsed].dynamicConfigKey;
    uint16 afterCollateralFactor = spoke._dynamicConfig[reserveIdUsed][dynamicConfigKeyAfter].collateralFactor;

    require beforeCollateralFactor > 0 => afterCollateralFactor > 0, "rule collateralFactorNotZero";
    assert afterUserAccountData.totalCollateralValue == 0 => afterUserAccountData.totalDebtValueRay == 0;
}

/**
 * @title Verify that the collateral factor is not zero once set to a non-zero value
 * @link_property valid state
 */
rule collateralFactorNotZero(uint256 reserveId, address user, method f) filtered {f -> !outOfScopeFunctions(f) && !f.isView} {
    env e;
    setup();
    requireInvariant dynamicConfigKeyConsistency(reserveId, user);
    requireInvariant validReserveId_single(reserveId);
    require userGhost == user;
    uint32 dynamicConfigKey;
    require dynamicConfigKey <= spoke._reserves[reserveId].dynamicConfigKey;
    require spoke._dynamicConfig[reserveId][dynamicConfigKey].collateralFactor > 0;
    calldataarg args;
    f(e, args);
    assert spoke._dynamicConfig[reserveId][dynamicConfigKey].collateralFactor > 0;
}

/**
 * @title Verify that the user debt value is deterministic
 * @link_property view functions integrity
 */
rule deterministicUserDebtValue(uint256 reserveId, address user) {
    env e;
    setup();
    require userGhost == user;
    uint256 drawnDebt;
    uint256 premiumDebt;
    (drawnDebt, premiumDebt) = spoke.getUserDebt(e, reserveId, user);
    uint256 drawnDebt2;
    uint256 premiumDebt2;
    (drawnDebt2, premiumDebt2) = spoke.getUserDebt(e, reserveId, user);
    assert drawnDebt == drawnDebt2;
    assert premiumDebt == premiumDebt2;
}

////////////////////////////////////////////////////////////////////////////
//                              INVARIANTS                                //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Verify that borrowing flag is set if and only if there are drawn shares
 * @link_property valid state
 */
invariant isBorrowingIFFdrawnShares()
    forall uint256 reserveId. forall address user.
    spoke._userPositions[user][reserveId].drawnShares > 0 <=> isBorrowing[user][reserveId]
    filtered {f -> !outOfScopeFunctions(f)}

/**
 * @title Verify that if there are no drawn shares, then there are no premium shares or offset
 * @link_property valid state
 */
invariant drawnSharesZero(address user, uint256 reserveId)
    spoke._userPositions[user][reserveId].drawnShares == 0 => (spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0)
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved with (env e) {
            setup();
        }
    }

/**
 * @title Validates reserve state for all users and reserves
 * @link_property valid state
 */
invariant validReserveId()
    validReserveId_definition()
    filtered {f -> !outOfScopeFunctions(f)}

/**
 * @title Validates reserve state for all users for a single reserveId
 * @link_property valid state
 */
invariant validReserveId_single(uint256 reserveId)
    // exists
    (reserveId < spoke._reserveCount =>
    // has underlying and hub
    (spoke._reserves[reserveId].underlying != 0 && spoke._reserves[reserveId].hub != 0 && spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] == reserveId))
    &&
    // not exists
    (reserveId >= spoke._reserveCount => (
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0 && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 && spoke._dynamicConfig[reserveId][0].collateralFactor == 0 &&
    // no one borrowed or used as collateral, no supplied or drawn shares, no premium shares or offset
    (forall address user. (!isBorrowing[user][reserveId] && !isUsingAsCollateral[user][reserveId] &&
    spoke._userPositions[user][reserveId].suppliedShares == 0 && spoke._userPositions[user][reserveId].drawnShares == 0 &&
    spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0))))
    filtered {f -> !outOfScopeFunctions(f)}

/**
 * @title Validates reserve state for a single user and reserveId
 * @link_property valid state
 */
invariant validReserveId_singleUser(uint256 reserveId, address user)
    // exists
    (reserveId < spoke._reserveCount =>
    // has underlying and hub
    (spoke._reserves[reserveId].underlying != 0 && spoke._reserves[reserveId].hub != 0 && spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] == reserveId))
    &&
    // not exists
    (reserveId >= spoke._reserveCount => (
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0 && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 && spoke._dynamicConfig[reserveId][0].collateralFactor == 0 &&
    // no one borrowed or used as collateral, no supplied or drawn shares, no premium shares or offset
    !isBorrowing[user][reserveId] && !isUsingAsCollateral[user][reserveId] &&
    spoke._userPositions[user][reserveId].suppliedShares == 0 && spoke._userPositions[user][reserveId].drawnShares == 0 &&
    spoke._userPositions[user][reserveId].premiumShares == 0 && spoke._userPositions[user][reserveId].premiumOffsetRay == 0))
    filtered {f -> !outOfScopeFunctions(f)}

/**
 * @title Hub asset ID to reserve ID integrity
 * @link_property valid state
 */
invariant hubAssetIdToReserveIdIntegrity(address hub, uint256 assetId, uint256 reserveId)
    (spoke._hubAssetIdToReserveId[hub][assetId] == reserveId && reserveId != 0 =>
    (spoke._reserves[reserveId].hub == hub && spoke._reserves[reserveId].assetId == assetId &&
    reserveId < spoke._reserveCount) &&
    (reserveId < spoke._reserveCount => spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] == reserveId))
    filtered {f -> !outOfScopeFunctions(f)}

/**
 * @title Verify that the assetId and hub are unique to a reserveId
 * @link_property valid state
 */
invariant uniqueAssetIdPerReserveId(uint256 reserveId, uint256 otherReserveId)
    (reserveId < spoke._reserveCount && otherReserveId < spoke._reserveCount && reserveId != otherReserveId) => (spoke._reserves[reserveId].assetId != spoke._reserves[otherReserveId].assetId || spoke._reserves[reserveId].hub != spoke._reserves[otherReserveId].hub)
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved {
            requireInvariant validReserveId_single(reserveId);
            requireInvariant validReserveId_single(otherReserveId);
            requireInvariant validReserveId_single(spoke._reserveCount);
        }
    }

/**
 * @title Verify that the realized premium ray is consistent with the premium shares and drawn index
 * @link_property valid state
 */
invariant realizedPremiumRayConsistency(uint256 reserveId, address user, env e)
    spoke._userPositions[user][reserveId].premiumOffsetRay <= spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e)
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved with (env eInv) {
            require eInv.block.timestamp == e.block.timestamp;
            setup();
            requireInvariant validReserveId_single(reserveId);
            requireInvariant validReserveId_singleUser(reserveId, user);
        }
    }

/**
 * @title Verify that the drawn shares are equal to the premium shares multiplied by the risk premium
 * @link_property valid state
 */
invariant drawnSharesRiskEQPremiumShares(address user, uint256 reserveId)
    ((spoke._userPositions[user][reserveId].drawnShares * spoke._positionStatus[user].riskPremium + PERCENTAGE_FACTOR - 1) / PERCENTAGE_FACTOR == spoke._userPositions[user][reserveId].premiumShares)
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved {
            setup();
            require spoke._userPositions[user][reserveId].drawnShares > 0 <=> isBorrowing[user][reserveId];
            requireInvariant drawnSharesZero(user, reserveId);
            requireInvariant validReserveId_single(reserveId);
            // help grounding
            require nextBorrowingCVL(spoke._reserveCount) == reserveId;
        }
    }

/**
 * @title Verify that the dynamic config key is consistent with the reserve dynamic config key
 * @link_property valid state
 */
invariant dynamicConfigKeyConsistency(uint256 reserveId, address user)
    spoke._userPositions[user][reserveId].dynamicConfigKey <= spoke._reserves[reserveId].dynamicConfigKey
    filtered {f -> !outOfScopeFunctions(f)}
    {
        preserved {
            setup();
            requireInvariant validReserveId_single(reserveId);
            requireInvariant validReserveId_singleUser(spoke._reserveCount, user);
        }
    }
