/**
 * @title Common Method Summaries
 * @notice Common method summaries used in both Hub and Spoke spec files
 * @assumption Asset deciamls is between 6 and 18
 */

import "./symbolicRepresentation/Math_CVL.spec";

methods {
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256) =>
        mulDivCVL(x, y, denominator, rounding);
        
    function _.divUp(uint256 a, uint256 b) internal => divUpCVL(a, b) expect uint256;

    function _.mulDivDown(uint256 a, uint256 b, uint256 c) internal =>
        mulDivDownCVL(a, b, c) expect uint256;

    function _.mulDivUp(uint256 a, uint256 b, uint256 c) internal =>
        mulDivUpCVL(a, b, c) expect uint256;

    function _.rayMulDown(uint256 a, uint256 b) internal =>
        mulDivRayDownCVL(a, b) expect uint256;

    function _.rayMulUp(uint256 a, uint256 b) internal =>
        mulDivRayUpCVL(a, b) expect uint256;

    function _.rayDivDown(uint256 a, uint256 b) internal =>
        mulDivDownCVL(a, RAY, b) expect uint256;

    function _.fromRayUp(uint256 a) internal =>
        divRayUpCVL(a) expect uint256;

    function _.toRay(uint256 a) internal =>
        mulRayCVL(a) expect uint256;

    function _.wadDivUp(uint256 a, uint256 b) internal =>
        mulDivUpCVL(a, WAD, b) expect uint256;

    function _.wadDivDown(uint256 a, uint256 b) internal =>
        mulDivDownCVL(a, WAD, b) expect uint256;

    function PercentageMath.percentMulDown(uint256 percentage, uint256 value) internal returns (uint256) =>
        mulDivDownCVL(value, percentage, PERCENTAGE_FACTOR);

    function PercentageMath.percentMulUp(uint256 percentage, uint256 value) internal returns (uint256) =>
        mulDivUpCVL(value, percentage, PERCENTAGE_FACTOR);

    function _._checkCanCall(address caller, bytes calldata data) internal =>
        checkCanCallCVL(caller) expect bool;

    // assume check-effect-interaction. this will not callback to the hub
    function _.setInterestRateData(uint256 assetId, bytes data) external => NONDET;

    function _.extSload(bytes32 slot) external => NONDET DELETE;
    function _.extSloads(bytes32[] slots) external => NONDET DELETE;
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

persistent ghost address checkedCanCallGhost;

ghost mapping(uint256 /*decimals*/ => uint256 /*value*/) expCVL {
    axiom expCVL[0] == 1;
    axiom expCVL[1] == 10;
    axiom expCVL[2] == 100;
    axiom expCVL[3] == 1000;
    axiom expCVL[4] == 10000;
    axiom expCVL[5] == 100000;
    axiom expCVL[6] == 1000000;
    axiom expCVL[7] == 10000000;
    axiom expCVL[8] == 100000000;
    axiom expCVL[9] == 1000000000;
    axiom expCVL[10] == 10000000000;
    axiom expCVL[11] == 100000000000;
    axiom expCVL[12] == 1000000000000;
    axiom expCVL[13] == 10000000000000;
    axiom expCVL[14] == 100000000000000;
    axiom expCVL[15] == 1000000000000000;
    axiom expCVL[16] == 10000000000000000;
    axiom expCVL[17] == 100000000000000000;
    axiom expCVL[18] == 1000000000000000000;
}


function toValueCVL(uint256 amount, uint256 decimals, uint256 price) returns (uint256) {
    require decimals >= 0 && decimals <= 18, "limiting exp, used as decimals only";
    // 10 ** (18 - decimals)
    uint256 toWAd = expCVL[require_uint256(18 - decimals)];
    return require_uint256(amount * toWAd * price);
}

function checkCanCallCVL(address caller) returns (bool) {
    checkedCanCallGhost = caller;
    return true;
}


function limitedExp(uint256 a, uint256 b) returns (uint256) {
    // assumes that b is always the decimals of an asset
    // computes 10^b
    assert a == 10;
    require b >= 6 && b <= 18, "assuming assets' decimals are between 6 and 18";
    return require_uint256(expCVL[b]);
}