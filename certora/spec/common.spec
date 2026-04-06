/***
Common method summaries used in both Hub and Spoke spec files
***/

methods {

    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal => 
        mulDivDownCVL(a,b,c) expect uint256;
    
    function _.mulDivUp(uint256 a, uint256 b, uint256 c) internal => 
        mulDivUpCVL(a,b,c) expect uint256;

    function _.rayMulDown(uint256 a, uint256 b) internal  => 
        mulDivRayDownCVL(a,b) expect uint256;

    function _.rayMulUp(uint256 a, uint256 b) internal  => 
        mulDivRayUpCVL(a,b) expect uint256;
    
    function _.rayDivDown(uint256 a, uint256 b) internal  => 
        mulDivDownCVL(a,RAY,b) expect uint256;
    
    function _.fromRayUp(uint256 a) internal => 
        divRayUpCVL(a) expect uint256;

    function _.toRay(uint256 a) internal => 
        mulRayCVL(a) expect uint256;

    function _.wadDivUp(uint256 a, uint256 b) internal => 
        mulDivUpCVL(a,WAD,b) expect uint256;

    function _.wadDivDown(uint256 a, uint256 b) internal => 
        mulDivDownCVL(a,WAD,b) expect uint256;
    

    function PercentageMath.percentMulDown(uint256 percentage, uint256 value) internal returns (uint256) =>  
        mulDivDownCVL(value,percentage,PERCENTAGE_FACTOR);
    
    function PercentageMath.percentMulUp(uint256 percentage, uint256 value) internal returns (uint256) =>  
        mulDivUpCVL(value,percentage,PERCENTAGE_FACTOR);

    function _._checkCanCall(address caller, bytes calldata data) internal => NONDET; 
    
    function _.setInterestRateData(uint256 assetId, bytes data) external => NONDET; 
}


persistent ghost uint256 RAY {
    axiom RAY == 10^27;
    }

persistent ghost uint256 WAD {
    axiom WAD == 10^18;
    }

persistent ghost uint256 PERCENTAGE_FACTOR {
    axiom PERCENTAGE_FACTOR == 10000;
    }