
import "./ERC20s_CVL.spec";
import "./Math_CVL.spec";

using LiquidityHubHarness as liquidityHub;
using WadRayMathWrapper as wadRayMath;

/***

Verify LiquidityHub.accrueInterest given a summarization of Spoke
Spoke must obey the given specification 

***/


rule runningTwiceIsEquivalentToOne() { 
    env e;
    uint256 assetId;
    accrueInterest(e,assetId);
    storage afterOne = lastStorage;
    accrueInterest(e,assetId);
    assert lastStorage == afterOne;
}



rule towStepVsOneStep() { 
    env e;
    env eNext;
    require eNext.block.timestamp > e.block.timestamp;
    uint256 assetId;

    storage init = lastStorage;
    accrueInterest(e,assetId);
    accrueInterest(eNext,assetId);
    storage afterTwoSteps = lastStorage;
    accrueInterest(eNext,assetId) at init;
    assert afterTwoSteps == lastStorage;
}


/* what does accrue impact
prove that accrue interest update the following only 
any use of this fields should be only after accrue intreset is called 


for view function - calling accrue does not impact value */ 

/* calling accure before sload to relevant slots  */