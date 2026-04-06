/**
@title Prove the summarization of Premium.calculatePremiumRay

Verify that the CVL representation (calculatePremiumRayCVL) matches the Solidity implementation.

To run this spec file:
 certoraRun certora/conf/libs/Premium.conf 

**/

methods {
    function calculatePremiumRay(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) external returns (uint256) envfree;
}


/**
@title CVL implementation of calculatePremiumRay
This is the summarization used in HubBase.spec
*/
function calculatePremiumRayCVL(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) returns uint256 {
    return require_uint256((premiumShares * drawnIndex) - premiumOffsetRay);
}


/**
@title Prove that calculatePremiumRayCVL matches the Solidity implementation

The Solidity implementation:
  return ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256();

The CVL implementation:
  return require_uint256((premiumShares * drawnIndex) - premiumOffsetRay);
*/
rule calculatePremiumRay_equivalence(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) {
    uint256 solidityResult = calculatePremiumRay(premiumShares, premiumOffsetRay, drawnIndex);

    uint256 cvlResult = calculatePremiumRayCVL(premiumShares, premiumOffsetRay, drawnIndex);
    assert  solidityResult == cvlResult, "Results must be equal when not reverting";
}

