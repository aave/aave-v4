
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";
import "./LiquidityHubBase.spec";


using LiquidityHub as liquidityHub;

/***

Verify LiquidityHub 

***/

methods {


    // assume that borrow rate was already updated.
    //rules concerning updateBorrowRate are in ...
  function AssetLogic.updateBorrowRate(
    DataTypes.Asset storage asset,
    uint256,
    uint256
  ) internal => NONDET;

  function AssetLogic.accrue(DataTypes.Asset storage asset) internal => accrueCalled();

  function MathUtils.calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal returns (uint256) => ghostLinearInterest(rate, lastUpdateTimestamp);

  function LiquidityHub._validateDraw(
    DataTypes.Asset storage asset,
    uint256 amount,
    uint256 drawCap
  ) internal => NONDET;
  function LiquidityHub._validateSupply(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal => NONDET;
  function LiquidityHub._validateWithdraw(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 amount
  ) internal => NONDET;
  function LiquidityHub._validateRestore(
    DataTypes.Asset storage asset,
    DataTypes.SpokeData storage spoke,
    uint256 baseAmountRestored,
    uint256 premiumAmountRestored
  ) internal => NONDET;



}

/************ Ghost Variables ************/

ghost  ghostLinearInterest( uint256 /*rate*/, uint40 /*lastUpdateTimestamp*/) returns uint256; 

// track all assetsIds of the same asset 
/// sumAvailableLiquidity[asset] is the sum of _assets[KEY uint256 assetId].availableLiquidity  for all assetIds of asset 
ghost mapping(address /*IERC20*/ => mathint ) sumAvailableLiquidity {
    init_state axiom forall address X. sumAvailableLiquidity[X] == 0;
}

ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeSupplyPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeSupplyPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeSupplyPerAssetMirror[X][a]) == 0; 
}


ghost bool accrueCalledOnAsset;
//record accessed to debt fields before accrue
ghost bool unsafeAccessBeforeAccrue;




ghost mapping(uint256 /*assetId*/  => mapping(address /*spoke*/ => uint256 )) spokeBaseDrawnPerAssetMirror {
    init_state axiom forall uint256 X. forall address Y. spokeBaseDrawnPerAssetMirror[X][Y] == 0 ;
    init_state axiom forall uint256 X. (usum address a. spokeBaseDrawnPerAssetMirror[X][a]) == 0; 
}

/********** Function summary *****/
function accrueCalled() {
    accrueCalledOnAsset = true; 
} 

/************ Hooks  ************/
/// Update sumAvailableLiquidity[t] on update to availableLiquidity of assetId for token t
hook Sstore _assets[KEY uint256 assetId].availableLiquidity uint256 new_value (uint256 old_value) {
    sumAvailableLiquidity[currentContract.assetsList[assetId]] = sumAvailableLiquidity[currentContract.assetsList[assetId]] + new_value - old_value;
}

hook Sstore _assets[KEY uint256 assetId].baseDebtIndex uint256 new_value (uint256 old_value) {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sload uint256 value _assets[KEY uint256 assetId].baseDebtIndex  {
    unsafeAccessBeforeAccrue = unsafeAccessBeforeAccrue || !accrueCalledOnAsset;
}

hook Sstore liquidityHub._spokes[KEY uint256 assetId][KEY address spoke].baseDrawnShares uint256 new_value (uint256 old_value) {
    spokeBaseDrawnPerAssetMirror[assetId][spoke] = new_value;

}

hook Sload uint256 value liquidityHub._spokes[KEY uint256 assetId][KEY address spoke].baseDrawnShares {
    require spokeBaseDrawnPerAssetMirror[assetId][spoke] == value;
}

hook Sstore liquidityHub._spokes[KEY uint256 assetId][KEY address spoke].suppliedShares uint256 new_value (uint256 old_value) {
    spokeSupplyPerAssetMirror[assetId][spoke] = new_value;
}

hook Sload uint256 value liquidityHub._spokes[KEY uint256 assetId][KEY address spoke].suppliedShares {
    require spokeSupplyPerAssetMirror[assetId][spoke] == value;
}
/**
@title External balance is at least as internal accounting 
https://prover.certora.com/output/40726/1223726233564eeabef3da5a94096d92/?anonymousKey=7a23564895baca924f339ac7720029b2aa50a758
@status, fails on 'add' and 'restore' when 'from' is liquidityHub

otherwise passes violation: https://prover.certora.com/output/40726/1c96eb0569424739acd95562ffcbd9b2/?anonymousKey=b2530ed45dc0a161001d1893849e3d2bbfe3e907
**/
invariant solvency_external(address asset )
    balanceByToken[asset][liquidityHub] >=  sumAvailableLiquidity[asset]  {

        /*
        preserved LiquidityHub.add(uint256 assetId, uint256 amount, address from) with (env e){
            require from != liquidityHub;
        }

        preserved LiquidityHub.restore(uint256 assetId, uint256 baseAmount, uint256 premiumAmount, address from)  with (env e) {
                require from != liquidityHub;
        }
        */
    }


/**
@title Internal accounting represents supplied minus debt
@dev the require_uint that enforces suppliedShares to be >= baseDrawnShares is checked in baseDrawnSharesVsSuppliedShares
**/ 
/* not an invariant, it's a tuatology 
invariant solvency_internal(uint256 assetId, env e)
    getAvailableLiquidity(e, assetId) >= getAssetSuppliedAmount(e, assetId) - getAssetTotalDebt(e, assetId)  {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }
    */


rule solvency_internal_tautology(uint256 assetId, env e) {
//    requireAllInvariants(assetId, e);
    assert getAvailableLiquidity(e, assetId) >= getAssetSuppliedAmount(e, assetId) - getAssetTotalDebt(e, assetId);
    }


invariant totalAssetsVsShares(uint256 assetId, env e) 
    getAssetSuppliedAmount(e,assetId) >=  getAssetSuppliedShares(e,assetId) {
        preserved with (env eInv) {
            //todo - need to prove time changing 
            require eInv.block.timestamp == e.block.timestamp;
            requireAllInvariants(assetId, e);
        }
    }

invariant totalAssetsAndSharesZero(uint256 assetId, env e) 
    getAssetSuppliedAmount(e,assetId) == 0 <=> getAssetSuppliedShares(e,assetId) == 0 {
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
    require liquidityHub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 


    f(e, args);

    mathint assetsAfter = getAssetSuppliedAmount(e,assetId);
    mathint sharesAfter = getAssetSuppliedShares(e,assetId);

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
    calldataarg args; 

    require e.block.timestamp == eOther.block.timestamp; 
    require otherSpoke != spoke && eOther.msg.sender == otherSpoke; 

    require liquidityHub._assets[assetId].lastUpdateTimestamp == e.block.timestamp; 
    requireAllInvariants(assetId, e);
    
    uint256 cumulativeDebt_  = getSpokeTotalDebt(e, assetId, spoke); 

    uint256 shares_ = getSpokeSuppliedShares(e, assetId, spoke);
    uint256 assets = getSpokeSuppliedAmount(e, assetId, spoke);

    f(eOther,args);

    assert cumulativeDebt_ >= getSpokeTotalDebt(e, assetId, spoke);  
    assert shares_ == getSpokeSuppliedShares(e, assetId, spoke);
    // asset can increase due to other's operations 
    assert assets <= getSpokeSuppliedAmount(e, assetId, spoke);
    // debt can decrease - TODO 
} 



rule accrueWasCalled(uint256 assetId, method f) filtered { f-> !f.isView} {
    env e;
    require !unsafeAccessBeforeAccrue; 
    calldataarg args;
    f(e,args);

    assert !unsafeAccessBeforeAccrue; 

}
/**** Valid State Rules *******/


definition emptyAsset(uint256 assetId) returns bool =
    liquidityHub._assets[assetId].suppliedShares == 0 &&
        liquidityHub._assets[assetId].availableLiquidity == 0 &&
        liquidityHub._assets[assetId].baseDrawnShares == 0 &&
        liquidityHub._assets[assetId].realizedPremium == 0 &&
        ( forall address spoke. 
            liquidityHub._spokes[assetId][spoke].suppliedShares == 0 &&
            liquidityHub._spokes[assetId][spoke].baseDrawnShares == 0 &&
            liquidityHub._spokes[assetId][spoke].realizedPremium == 0  
        ) && 
        liquidityHub.assetsList[assetId] == 0;


/** @title integrity of a validAsset 
@status fails on refreshPremiumDebt  https://prover.certora.com/output/40726/dbc1d061483e4a92b20160ea03527ca4/?anonymousKey=50dc3842ecb36e1a7fc67153c11e716d5a813cf6
in the case that assetId is not listed yet 
**/

invariant validAssetId(uint256 assetId)  
    assetId >= liquidityHub.assetCount => emptyAsset(assetId) && 
    liquidityHub.assetsList.length == liquidityHub.assetCount;




/** @title the sum of  liquidityHub._spokes[assetId][spoke].suppliedShares for all spoke equals to liquidityHub._assets[assetId].suppliedShares
@status fails on addSpoke and addSpokes as they can re-add an existing spoke 
https://prover.certora.com/output/40726/cb1ee5d64b7f432f8769be106d6f3bc4?anonymousKey=bf86ab21b57e6979814f430901bd42d3bb540c02 
*/
invariant sumOfSpokeSupplyShares(uint256 assetId) 
    liquidityHub._assets[assetId].suppliedShares == (usum address spoke. spokeSupplyPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

/** @title the sum of  liquidityHub._spokes[assetId][spoke].baseDrawnShares for all spoke equals to liquidityHub._assets[assetId].baseDrawnShares
same failures on addSpoke and addSpokes as they can re-add an existing spoke 
*/
invariant sumOfSpokeDrawnShares(uint256 assetId) 
    liquidityHub._assets[assetId].baseDrawnShares == (usum address spoke. spokeBaseDrawnPerAssetMirror[assetId][spoke]) 
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }

invariant baseDebtIndexMin(uint256 assetId) 
    liquidityHub._assets[assetId].baseDebtIndex==0 || liquidityHub._assets[assetId].baseDebtIndex >= wadRayMath.RAY()
    {
        preserved {
            requireInvariant validAssetId(assetId);
        }
    }


// optimize the calls to certain function and save in ghost (global) variable) 
ghost uint256 supplyAmountBefore; 
ghost uint256 supplyShareBefore;

function requireAllInvariants(uint256 assetId, env e)  {
    // optimize the calls to 
    supplyAmountBefore = getAssetSuppliedAmount(e,assetId);
    supplyShareBefore = getAssetSuppliedShares(e,assetId); 
    //requireInvariant totalAssetsVsShares(assetId,e);
    require supplyAmountBefore >= supplyShareBefore;


    requireInvariant sumOfSpokeDrawnShares(assetId);
    requireInvariant sumOfSpokeSupplyShares(assetId);
    requireInvariant baseDebtIndexMin(assetId); 
}