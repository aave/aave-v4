/**
Spoke verification integrity rules that verify that change is consistent.

To run this spec file:
 certoraRun certora/conf/SpokeIntegrity.conf 
**/

import "./SpokeBase.spec";
import "./symbolicRepresentation/SymbolicPositionStatus.spec";
import "./symbolicRepresentation/SymbolicHub.spec";


definition premiumDebtCVL(address user, uint256 reserveId, env e) returns mathint =
(spoke._userPositions[user][reserveId].premiumShares * getAssetDrawnIndexCVL(spoke._reserves[reserveId].assetId, e)) - spoke._userPositions[user][reserveId].premiumOffsetRay;

/**
 * @title Supply operation increases user's supplied shares and transfers tokens from user
 * @link_property Spoke integrity
 */
rule nothingForZero_supply(uint256 reserveId, uint256 amount, address onBehalfOf) {
    env e;
    setup();
    address underlying = spoke._reserves[reserveId].underlying;
    //same underlying as in hub
    require underlying == assetUnderlying[spoke._reserves[reserveId].assetId];
    
    uint256 suppliedSharesBefore = spoke._userPositions[onBehalfOf][reserveId].suppliedShares;
    uint256 userBalanceBefore = tokenBalanceOf(underlying, e.msg.sender);

    supply(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[onBehalfOf][reserveId].suppliedShares > suppliedSharesBefore;
    assert e.msg.sender != spoke._reserves[reserveId].hub => tokenBalanceOf(underlying, e.msg.sender) < userBalanceBefore;
}

/**
 * @title Withdraw operation decreases user's supplied shares and transfers tokens to user
 * @link_property Spoke integrity
 */
rule nothingForZero_withdraw(uint256 reserveId, uint256 amount, address onBehalfOf) {
    env e;
    setup();
    address underlying = spoke._reserves[reserveId].underlying;
    //same underlying as in hub
    require underlying == assetUnderlying[spoke._reserves[reserveId].assetId];

    uint256 suppliedSharesBefore = spoke._userPositions[onBehalfOf][reserveId].suppliedShares;
    uint256 userBalanceBefore = tokenBalanceOf(underlying, e.msg.sender);

    withdraw(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[onBehalfOf][reserveId].suppliedShares < suppliedSharesBefore;
    assert e.msg.sender != spoke._reserves[reserveId].hub => tokenBalanceOf(underlying, e.msg.sender) > userBalanceBefore;
}

/**
 * @title Borrow operation increases user's drawn shares and transfers tokens to user
 * @link_property Spoke integrity
 */
rule nothingForZero_borrow(uint256 reserveId, uint256 amount, address onBehalfOf) {
    env e;
    setup();
    address underlying = spoke._reserves[reserveId].underlying;
    //same underlying as in hub
    require underlying == assetUnderlying[spoke._reserves[reserveId].assetId];

    uint256 drawnSharesBefore = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    uint256 userBalanceBefore = tokenBalanceOf(underlying, e.msg.sender);

    borrow(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[onBehalfOf][reserveId].drawnShares > drawnSharesBefore;
    assert e.msg.sender != spoke._reserves[reserveId].hub => tokenBalanceOf(underlying, e.msg.sender) > userBalanceBefore;
}

/**
 * @title Repay operation decreases user's drawn shares and transfers tokens from user
 * @link_property Spoke integrity
 */
rule nothingForZero_repay(uint256 reserveId, uint256 amount, address onBehalfOf) {
    env e;
    setup();
    address underlying = spoke._reserves[reserveId].underlying;
    require e.msg.sender != spoke._reserves[reserveId].hub;
    // Same underlying as in hub
    require underlying == assetUnderlying[spoke._reserves[reserveId].assetId];
    uint256 drawnSharesBefore = spoke._userPositions[onBehalfOf][reserveId].drawnShares;
    uint256 userBalanceBefore = tokenBalanceOf(underlying, e.msg.sender);
    mathint premiumDebtBefore = premiumDebtCVL(onBehalfOf, reserveId, e);

    repay(e, reserveId, amount, onBehalfOf);

    mathint premiumDebtAfter = premiumDebtCVL(onBehalfOf, reserveId, e);
    // change in debt then must have  change in underlying assets
    assert ((spoke._userPositions[onBehalfOf][reserveId].drawnShares < drawnSharesBefore || premiumDebtAfter < premiumDebtBefore) =>
            (tokenBalanceOf(underlying, e.msg.sender) < userBalanceBefore));
    // no change in underlying then no debt covered
    assert (tokenBalanceOf(underlying, e.msg.sender) == userBalanceBefore) => (premiumDebtAfter == premiumDebtBefore && spoke._userPositions[onBehalfOf][reserveId].drawnShares == drawnSharesBefore)
           ;
}

/**
 * @title Supply integrity - only suppliedShares changes for the user
 * @link_property Spoke integrity
 */
rule supply_noChangeToOther(uint256 reserveId, uint256 amount, address onBehalfOf, address user) {
    env e;
    setup();
    
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    supply(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[user][reserveId].suppliedShares != suppliedSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].drawnShares == drawnSharesBefore;
    assert spoke._userPositions[user][reserveId].premiumShares == premiumSharesBefore;
    assert spoke._userPositions[user][reserveId].premiumOffsetRay == premiumOffsetRayBefore;
}

/**
 * @title Withdraw integrity - only suppliedShares changes for the user
 * @link_property Spoke integrity
 */
rule withdraw_noChangeToOther(uint256 reserveId, uint256 amount, address onBehalfOf, address user) {
    env e;
    setup();
    
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    withdraw(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[user][reserveId].suppliedShares != suppliedSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].drawnShares == drawnSharesBefore;
    assert spoke._userPositions[user][reserveId].premiumShares != premiumSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].premiumOffsetRay != premiumOffsetRayBefore => user == onBehalfOf;
}

/**
 * @title Borrow integrity - drawnShares increases, premiumShares may change
 * @link_property Spoke integrity
 */
rule borrow_noChangeToOther(uint256 reserveId, uint256 amount, address onBehalfOf, address user) {
    env e;
    setup();
    
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    borrow(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[user][reserveId].drawnShares != drawnSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].premiumShares != premiumSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].premiumOffsetRay != premiumOffsetRayBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].suppliedShares == suppliedSharesBefore;
}

/**
 * @title Repay integrity - drawnShares decreases, suppliedShares unchanged
 * @link_property Spoke integrity
 */
rule repay_noChangeToOther(uint256 reserveId, uint256 amount, address onBehalfOf, address user) {
    env e;
    setup();
    
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;

    repay(e, reserveId, amount, onBehalfOf);

    assert spoke._userPositions[user][reserveId].drawnShares != drawnSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].premiumShares != premiumSharesBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].premiumOffsetRay != premiumOffsetRayBefore => user == onBehalfOf;
    assert spoke._userPositions[user][reserveId].suppliedShares == suppliedSharesBefore;
}

/**
 * @title Only position manager can change the user's position, or that the caller was verified via the checkCanCall function
 * @link_property Spoke integrity
 */
rule onlyPositionManagerCanChange(method f, address user, uint256 reserveId) filtered { f -> !outOfScopeFunctions(f)  } {
    env e;
    calldataarg args;
    setup();
    uint256 drawnSharesBefore = spoke._userPositions[user][reserveId].drawnShares;
    uint256 premiumSharesBefore = spoke._userPositions[user][reserveId].premiumShares;
    int256 premiumOffsetRayBefore = spoke._userPositions[user][reserveId].premiumOffsetRay;
    uint256 suppliedSharesBefore = spoke._userPositions[user][reserveId].suppliedShares;
    bool isPositionManager = isPositionManager(user, e.msg.sender);
    f(e, args);
    assert spoke._userPositions[user][reserveId].drawnShares != drawnSharesBefore => isPositionManager;
    assert spoke._userPositions[user][reserveId].premiumShares != premiumSharesBefore => (isPositionManager || checkedCanCallGhost == e.msg.sender);
    assert spoke._userPositions[user][reserveId].premiumOffsetRay != premiumOffsetRayBefore => (isPositionManager || checkedCanCallGhost == e.msg.sender);
    assert spoke._userPositions[user][reserveId].suppliedShares != suppliedSharesBefore => isPositionManager;
    
}
