
import "./symbolicRepresentation/ERC20s_CVL.spec";
import "./symbolicRepresentation/Math_CVL.spec";
import "./common.spec";


/**
* @title Base definitions used in all of Hub spec files
* @notice  safe summarization that are proved in other files
@assumption calculateInterestRate is a pure deterministic function of the input parameters
***/

methods {
    
    function _.calculateInterestRate(uint256 assetId, uint256 liquidity, uint256 drawn, uint256 deficit, uint256 swept) external  => interestRateGhost(assetId, liquidity, drawn, deficit, swept) expect uint256;
    
  // summary proved in libs/Premium.spec
    function Premium.calculatePremiumRay(
    uint256 premiumShares,
    int256 premiumOffsetRay,
    uint256 drawnIndex
  ) internal  returns (uint256)=> calculatePremiumRayCVL(premiumShares, premiumOffsetRay, drawnIndex);
  
}

function calculatePremiumRayCVL(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) returns uint256 {
    return require_uint256((premiumShares * drawnIndex) - premiumOffsetRay);
}

ghost interestRateGhost(uint256, uint256, uint256, uint256, uint256) returns uint256;