
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./HubValidState.spec";

/**
Accrue is assumed to be called already 
**/

rule nothingForZero_add(uint256 assetId, uint256 amount, address from) {

    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 fromBalanceBefore = balanceByToken[asset][from];
    uint256 spokeSharesBefore = hub._spokes[assetId][spoke].addedShares;

    add(e, assetId, amount, from);

    assert balanceByToken[asset][hub] > externalBalanceBefore && hub._spokes[assetId][spoke].addedShares > spokeSharesBefore && fromBalanceBefore > balanceByToken[asset][from];
    // no fee and no asset lost
    assert balanceByToken[asset][hub] + balanceByToken[asset][from] == externalBalanceBefore + fromBalanceBefore; 
}


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
}

rule nothingForZero_draw(uint256 assetId, uint256 amount, address to) {
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 spokeDrawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 toBalanceBefore = balanceByToken[asset][to];
    uint256 liquidityBefore = hub._assets[assetId].liquidity;

    draw(e,assetId,amount,to);

    assert hub._spokes[assetId][spoke].drawnShares > spokeDrawnSharesBefore &&
            balanceByToken[asset][hub] < externalBalanceBefore &&
            balanceByToken[asset][to] > toBalanceBefore &&
            hub._assets[assetId].liquidity < liquidityBefore;
}

rule nothingForZero_restore(uint256 assetId, uint256 drawnAmount, uint256 premiumAmount, DataTypes.PremiumDelta premiumDelta, address from) {
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 spokeDrawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 fromBalanceBefore = balanceByToken[asset][from];
    uint256 liquidityBefore = hub._assets[assetId].liquidity;


    restore(e,assetId,drawnAmount,premiumAmount,premiumDelta,from);

    assert hub._spokes[assetId][spoke].drawnShares < spokeDrawnSharesBefore &&  
            balanceByToken[asset][hub] > externalBalanceBefore &&
            balanceByToken[asset][from] < fromBalanceBefore &&
            hub._assets[assetId].liquidity > liquidityBefore;
}

rule nothingForZero_reportDeficit(uint256 assetId, uint256 drawnAmount, uint256 premiumAmount, DataTypes.PremiumDelta premiumDelta) {       
    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 spokeDrawnSharesBefore = hub._spokes[assetId][spoke].drawnShares;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 deficitBefore = hub._assets[assetId].deficit;

    reportDeficit(e,assetId,drawnAmount,premiumAmount,premiumDelta);       

    assert hub._spokes[assetId][spoke].drawnShares < spokeDrawnSharesBefore &&  
            balanceByToken[asset][hub] == externalBalanceBefore &&
            hub._assets[assetId].deficit > deficitBefore;
}

rule nothingForZero_eliminateDeficit(uint256 assetId, uint256 amount) {

    env e;
    address asset = hub._assets[assetId].underlying;
    address spoke = e.msg.sender;
    uint256 spokeAddedSharesBefore = hub._spokes[assetId][spoke].addedShares;
    uint256 externalBalanceBefore = balanceByToken[asset][hub]; 
    uint256 deficitBefore = hub._assets[assetId].deficit;

    eliminateDeficit(e,assetId,amount);

    assert hub._spokes[assetId][spoke].addedShares < spokeAddedSharesBefore &&  
            balanceByToken[asset][hub] == externalBalanceBefore &&
            hub._assets[assetId].deficit < deficitBefore;
}
