/**
 * @title Hub Integrity Specification
 * @notice Hub verification integrity rules that verify that change is consistent
 * @dev Accrue is assumed to be called already
 *
 * To run this spec file:
 * certoraRun certora/conf/HubIntegrity.conf
 */

import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./HubValidState.spec";

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Add operation increases external balances and increases internal accounting while decreasing from balance
 * @link_property Hub integrity
 */
rule nothingForZero_add(uint256 assetId, uint256 amount, address from) {
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 internalBalanceBefore = hub._assets[assetId].liquidity;
    uint256 spokeSharesBefore = hub._spokes[assetId][spoke].addedShares;

    uint256 sharesAdded = add(e, assetId, amount);

    assert hub._assets[assetId].liquidity > internalBalanceBefore && hub._spokes[assetId][spoke].addedShares == spokeSharesBefore + sharesAdded;
    assert amount > 0;
}

/**
 * @title Remove operation decreases external balances and decreases internal accounting while increasing to balance
 * @link_property Hub integrity
 */
rule nothingForZero_remove(uint256 assetId, uint256 amount, address to) {
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 externalBalanceBefore = balanceByToken[asset][hub];
    uint256 toBalanceBefore = balanceByToken[asset][to];
    uint256 spokeSharesBefore = hub._spokes[assetId][spoke].addedShares;

    remove(e, assetId, amount, to);

    assert balanceByToken[asset][hub] < externalBalanceBefore && hub._spokes[assetId][spoke].addedShares < spokeSharesBefore && toBalanceBefore < balanceByToken[asset][to];
    // no fee and no asset lost
    assert balanceByToken[asset][hub] + balanceByToken[asset][to] == externalBalanceBefore + toBalanceBefore;
    assert amount > 0;
}

/**
 * @title Draw operation increases debt shares and transfers assets to recipient
 * @link_property Hub integrity
 */
rule nothingForZero_draw(uint256 assetId, uint256 amount, address to) {
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 externalBalanceBefore = balanceByToken[asset][hub];
    uint256 toBalanceBefore = balanceByToken[asset][to];
    uint256 liquidityBefore = hub._assets[assetId].liquidity;

    draw(e, assetId, amount, to);

    assert hub._spokes[assetId][spoke].drawnShares > drawnSharesBefore &&
           balanceByToken[asset][hub] < externalBalanceBefore &&
           balanceByToken[asset][to] > toBalanceBefore &&
           hub._assets[assetId].liquidity < liquidityBefore &&
           amount > 0;
}

/**
 * @title Report deficit operation decreases debt shares and increases liquidity
 * @link_property Hub integrity
 */
rule nothingForZero_eliminateDeficit(uint256 assetId, uint256 amount, address spoke) {
    env e;
    requireAllInvariants(assetId, e);

    uint256 senderAddedSharesBefore = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;

    eliminateDeficit(e, assetId, amount, spoke);

    uint256 deficitRayAfter = hub._spokes[assetId][spoke].deficitRay;
    assert (senderAddedSharesBefore > hub._spokes[assetId][e.msg.sender].addedShares &&
            deficitRayBefore > deficitRayAfter);
}

/**
 * @title Sweep operation increases liquidity and decreases swept
 * @link_property Hub integrity
 */
rule nothing_for_zero_sweep(uint256 assetId, uint256 amount) {
    env e;
    requireAllInvariants(assetId, e);
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 sweptBefore = hub._assets[assetId].swept;
    sweep(e, assetId, amount);
    assert amount > 0;
    assert liquidityBefore == hub._assets[assetId].liquidity + amount;
    assert sweptBefore == hub._assets[assetId].swept - amount;
}

/**
 * @title Reclaim operation increases liquidity and decreases swept
 * @link_property Hub integrity
 */
rule nothing_for_zero_reclaim(uint256 assetId, uint256 amount) {
    env e;
    requireAllInvariants(assetId, e);
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 sweptBefore = hub._assets[assetId].swept;
    reclaim(e, assetId, amount);
    assert amount > 0;
    assert liquidityBefore == hub._assets[assetId].liquidity - amount;
    assert sweptBefore == hub._assets[assetId].swept + amount;
}

/**
 * @title Add operation increases liquidity and decreases spoke added shares
 * @link_property Hub integrity
 */
rule add_integrity(uint256 assetId, uint256 amount) {
    env e;
    requireAllInvariants(assetId, e);
    address spoke = e.msg.sender;

    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesBefore = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayBefore = hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 spokeAddedShares_ = hub._spokes[assetId][spoke].addedShares;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 sharesAddedByPreview = previewAddByAssets(e, assetId, amount);
    uint256 sharesAdded = add(e, assetId, amount);
    
    assert sharesAddedByPreview == sharesAdded;
    assert liquidityBefore == hub._assets[assetId].liquidity - amount;
    assert spokeAddedShares_ < hub._spokes[assetId][spoke].addedShares;
    assert premiumSharesBefore == hub._spokes[assetId][spoke].premiumShares;
    assert premiumOffsetRayBefore == hub._spokes[assetId][spoke].premiumOffsetRay;
    assert deficitRayBefore == hub._spokes[assetId][spoke].deficitRay;
    assert drawnSharesBefore == hub._spokes[assetId][spoke].drawnShares;
}

/**
 * @title Remove operation decreases drawn shares, premium shares, premium offset, deficit ray, spoke added shares, liquidity, external balance, and to balance
 * @link_property Hub integrity
 */
rule remove_integrity(uint256 assetId, uint256 amount, address to) {
    env e;
    requireAllInvariants(assetId, e);
    address spoke = e.msg.sender;
    address asset = hub._assets[assetId].underlying;
    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 premiumSharesBefore = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRayBefore = hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 spokeAddedShares_ = hub._spokes[assetId][spoke].addedShares;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 externalBalanceBefore = balanceByToken[asset][hub];
    uint256 toBalanceBefore = balanceByToken[asset][to];

    uint256 sharesRemovedByPreview = previewRemoveByAssets(e, assetId, amount);
    uint256 sharesRemoved = remove(e, assetId, amount, to);
    
    assert sharesRemovedByPreview == sharesRemoved;
    assert drawnSharesBefore == hub._spokes[assetId][spoke].drawnShares;
    assert premiumSharesBefore == hub._spokes[assetId][spoke].premiumShares;
    assert premiumOffsetRayBefore == hub._spokes[assetId][spoke].premiumOffsetRay;
    assert deficitRayBefore == hub._spokes[assetId][spoke].deficitRay;
    assert spokeAddedShares_ > hub._spokes[assetId][spoke].addedShares;
    assert liquidityBefore == hub._assets[assetId].liquidity + amount;
    assert to != hub => externalBalanceBefore == balanceByToken[asset][hub] + amount;
    assert to != hub => toBalanceBefore == balanceByToken[asset][to] - amount;
}

/**
 * @title Draw operation decreases drawn shares, premium ray, spoke added shares, deficit ray, liquidity, external balance, and to balance
 * @link_property Hub integrity
 */
rule draw_integrity(uint256 assetId, uint256 amount, address to) {
    env e;
    requireAllInvariants(assetId, e);
    address spoke = e.msg.sender;
    address asset = hub._assets[assetId].underlying;
    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    mathint premiumRayBefore = hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 spokeAddedShares_ = hub._spokes[assetId][spoke].addedShares;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 externalBalanceBefore = balanceByToken[asset][hub];
    uint256 toBalanceBefore = balanceByToken[asset][to];

    draw(e, assetId, amount, to);

    assert drawnSharesBefore < hub._spokes[assetId][spoke].drawnShares;
    assert premiumRayBefore == hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    assert spokeAddedShares_ == hub._spokes[assetId][spoke].addedShares;
    assert deficitRayBefore == hub._spokes[assetId][spoke].deficitRay;
    assert liquidityBefore == hub._assets[assetId].liquidity + amount;
    assert to != hub => externalBalanceBefore == balanceByToken[asset][hub] + amount;
    assert to != hub => toBalanceBefore == balanceByToken[asset][to] - amount;
}

/**
 * @title Restore operation decreases debt shares, premium ray, deficit ray, spoke added shares, liquidity
 * @link_property Hub integrity
 */
rule restore_integrity(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta) {
    env e;
    requireAllInvariants(assetId, e);
    address spoke = e.msg.sender;
    uint256 beforeDebt = getSpokeTotalOwed(e, assetId, spoke);
    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    mathint premiumRayBefore = hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 spokeAddedShares_ = hub._spokes[assetId][spoke].addedShares;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;

    restore(e, assetId, drawnAmount, premiumDelta);

    uint256 afterDebt = getSpokeTotalOwed(e, assetId, spoke);
    assert beforeDebt >= afterDebt;
    assert drawnSharesBefore >= hub._spokes[assetId][spoke].drawnShares;
    assert premiumRayBefore >= hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    assert deficitRayBefore == hub._spokes[assetId][spoke].deficitRay;
    assert spokeAddedShares_ == hub._spokes[assetId][spoke].addedShares;
    // liquidity can increase by more than the drawn amount due to Premium
    assert liquidityBefore <= hub._assets[assetId].liquidity - drawnAmount;
}

/**
 * @title Report deficit operation decreases drawn shares, premium ray, deficit ray, spoke added shares, liquidity
 * @link_property Hub integrity
 */
rule reportDeficit_integrity(uint256 assetId, uint256 drawnAmount, IHubBase.PremiumDelta premiumDelta) {
    env e;
    requireAllInvariants(assetId, e);
    address spoke = e.msg.sender;
    uint256 drawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    mathint premiumRayBefore = hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 spokeAddedShares_ = hub._spokes[assetId][spoke].addedShares;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;

    reportDeficit(e, assetId, drawnAmount, premiumDelta);

    assert drawnSharesBefore >= hub._spokes[assetId][spoke].drawnShares;
    assert premiumRayBefore >= hub._spokes[assetId][spoke].premiumShares * hub._assets[assetId].drawnIndex - hub._spokes[assetId][spoke].premiumOffsetRay;
    assert deficitRayBefore <= hub._spokes[assetId][spoke].deficitRay;
    assert spokeAddedShares_ == hub._spokes[assetId][spoke].addedShares;
    assert liquidityBefore == hub._assets[assetId].liquidity;
}

/**
 * @title Eliminate deficit operation increases spoke added shares, liquidity, drawn shares, premium shares, premium offset, and deficit ray
 * @link_property Hub integrity
 */
rule eliminateDeficit_integrity(uint256 assetId, uint256 amount, address spoke) {
    env e;
    requireAllInvariants(assetId, e);
    uint256 spokeAddedShares_ = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 drawnSharesBefore = hub._spokes[assetId][e.msg.sender].drawnShares;
    uint256 premiumSharesBefore = hub._spokes[assetId][e.msg.sender].premiumShares;
    int200 premiumOffsetRayBefore = hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][spoke].deficitRay;
    uint256 senderDeficitRayBefore = hub._spokes[assetId][e.msg.sender].deficitRay;

    eliminateDeficit(e, assetId, amount, spoke);

    assert spokeAddedShares_ >= hub._spokes[assetId][e.msg.sender].addedShares;
    assert liquidityBefore == hub._assets[assetId].liquidity;
    assert drawnSharesBefore == hub._spokes[assetId][e.msg.sender].drawnShares;
    assert premiumSharesBefore == hub._spokes[assetId][e.msg.sender].premiumShares;
    assert premiumOffsetRayBefore == hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    assert deficitRayBefore > hub._spokes[assetId][spoke].deficitRay;
    assert e.msg.sender != spoke => senderDeficitRayBefore == hub._spokes[assetId][e.msg.sender].deficitRay;
}

/**
 * @title Sweep operation increases liquidity, external balance, to balance, swept, spoke added shares, drawn shares, premium shares, premium offset, and deficit ray
 * @link_property Hub integrity
 */
rule sweep_integrity(uint256 assetId, uint256 amount) {
    env e;
    requireAllInvariants(assetId, e);
    address asset = hub._assets[assetId].underlying;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 externalBalanceBefore = balanceByToken[asset][hub];
    uint256 toBalanceBefore = balanceByToken[asset][e.msg.sender];
    uint256 sweptBefore = hub._assets[assetId].swept;
    uint256 spokeAddedShares_ = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 drawnSharesBefore = hub._spokes[assetId][e.msg.sender].drawnShares;
    uint256 premiumSharesBefore = hub._spokes[assetId][e.msg.sender].premiumShares;
    int200 premiumOffsetRayBefore = hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][e.msg.sender].deficitRay;

    sweep(e, assetId, amount);

    assert liquidityBefore == hub._assets[assetId].liquidity + amount;
    assert e.msg.sender != hub => externalBalanceBefore == balanceByToken[asset][hub] + amount;
    assert e.msg.sender != hub => toBalanceBefore == balanceByToken[asset][e.msg.sender] - amount;
    assert sweptBefore == hub._assets[assetId].swept - amount;
    assert spokeAddedShares_ == hub._spokes[assetId][e.msg.sender].addedShares;
    assert drawnSharesBefore == hub._spokes[assetId][e.msg.sender].drawnShares;
    assert premiumSharesBefore == hub._spokes[assetId][e.msg.sender].premiumShares;
    assert premiumOffsetRayBefore == hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    assert deficitRayBefore == hub._spokes[assetId][e.msg.sender].deficitRay;
    assert e.msg.sender == hub._assets[assetId].reinvestmentController;
}

/**
 * @title Reclaim operation decreases liquidity, swept, spoke added shares, drawn shares, premium shares, premium offset, and deficit ray
 * @link_property Hub integrity
 */
rule reclaim_integrity(uint256 assetId, uint256 amount) {
    env e;
    requireAllInvariants(assetId, e);
    address asset = hub._assets[assetId].underlying;
    uint256 liquidityBefore = hub._assets[assetId].liquidity;
    uint256 sweptBefore = hub._assets[assetId].swept;
    uint256 spokeAddedShares_ = hub._spokes[assetId][e.msg.sender].addedShares;
    uint256 drawnSharesBefore = hub._spokes[assetId][e.msg.sender].drawnShares;
    uint256 premiumSharesBefore = hub._spokes[assetId][e.msg.sender].premiumShares;
    int200 premiumOffsetRayBefore = hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    uint256 deficitRayBefore = hub._spokes[assetId][e.msg.sender].deficitRay;

    reclaim(e, assetId, amount);

    assert liquidityBefore == hub._assets[assetId].liquidity - amount;
    assert sweptBefore == hub._assets[assetId].swept + amount;
    assert spokeAddedShares_ == hub._spokes[assetId][e.msg.sender].addedShares;
    assert drawnSharesBefore == hub._spokes[assetId][e.msg.sender].drawnShares;
    assert premiumSharesBefore == hub._spokes[assetId][e.msg.sender].premiumShares;
    assert premiumOffsetRayBefore == hub._spokes[assetId][e.msg.sender].premiumOffsetRay;
    assert deficitRayBefore == hub._spokes[assetId][e.msg.sender].deficitRay;
    assert e.msg.sender == hub._assets[assetId].reinvestmentController;
}

/**
 * @title reportDeficit return same value as previewRestoreByAssets
 * @link_property Hub integrity
 */
rule reportDeficitSameAsPreviewRestoreByAssets(uint256 assetId, uint256 drawnAmount) {
    env e;
    address spoke = e.msg.sender;
    IHubBase.PremiumDelta premiumDelta;
    requireAllInvariants(assetId, e);
    storage init = lastStorage;
    uint256 previewedDrawnShares = previewRestoreByAssets(e, assetId, drawnAmount);
    uint256 resultDrawnShares;
    uint256 resultDeficit;
    resultDrawnShares, resultDeficit = reportDeficit(e, assetId, drawnAmount, premiumDelta);
    assert resultDrawnShares == previewedDrawnShares;
}

/**
 * @title Only valid active spoke can call the function and perform changes the spoke position (except for receiving fee shares)
 * @link_property Hub integrity
 */
rule validSpokeOnly(uint256 assetId, method f) {
    env e;
    calldataarg args;
    address spoke = e.msg.sender;
    uint256 drawnShares = hub._spokes[assetId][spoke].drawnShares;
    uint256 addedShares = hub._spokes[assetId][spoke].addedShares;
    uint256 premiumShares = hub._spokes[assetId][spoke].premiumShares;
    int200 premiumOffsetRay = hub._spokes[assetId][spoke].premiumOffsetRay;
    uint200 deficitRay = hub._spokes[assetId][spoke].deficitRay;
    bool active = hub._spokes[assetId][spoke].active;

    f(e, args);

    assert drawnShares != hub._spokes[assetId][spoke].drawnShares => active;
    assert addedShares != hub._spokes[assetId][spoke].addedShares => (active || (hub._assets[assetId].feeReceiver == spoke && f.selector == sig:payFeeShares(uint256,uint256).selector));
    assert premiumShares != hub._spokes[assetId][spoke].premiumShares => active;
    assert deficitRay != hub._spokes[assetId][spoke].deficitRay => active;
    assert premiumOffsetRay != hub._spokes[assetId][spoke].premiumOffsetRay => active;
}

/**
 * @title Order of refreshPremium of two different spoke should not change reverting cases 
 * @link_property Hub integrity
 */
rule frontRunOnRefreshPremium(uint256 assetId) {
    env e;
    env eBefore;
    calldataarg args;

    require eBefore.msg.sender != e.msg.sender;
    require eBefore.block.timestamp <= e.block.timestamp;

    requireAllInvariants(assetId, eBefore);
    requireInvariant premiumOffset_Integrity(assetId, e.msg.sender);
    calldataarg argsRefresh;
    storage init_state = lastStorage;
    refreshPremium(e, argsRefresh);
    refreshPremium(eBefore, args);
    refreshPremium(eBefore, args) at init_state;
    // just to avoid overflows
    require getAddedAssets(e, assetId) >= getAddedShares(e, assetId);
    refreshPremium@withrevert(e, argsRefresh);
    assert !lastReverted;
}
