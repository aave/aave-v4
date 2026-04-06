/**
@title Prove that only one user's account is updated and used at a time

This allows us to assume that the user is the same throughout the operation in the Spoke.spec rules
*/

using SpokeInstance as spoke;

methods {
    // Note: _calculateLiquidationAmounts returns a struct, cannot use NONDET with struct return types
    // Summary removed - function will be inlined or handled by default summary 

    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator) internal  returns (uint256) => NONDET ALL;
    function Math.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal returns (uint256) => NONDET ALL;

    function LibBit.fls(uint256 x) internal returns (uint256) => NONDET ALL;
    function LibBit.popCount(uint256 x) internal returns (uint256) => NONDET ALL;


    function WadRayMath.rayMulDown(uint256 a, uint256 b) internal returns (uint256) => 
        NONDET ALL;
  
    function WadRayMath.rayMulUp(uint256 a, uint256 b) internal returns (uint256) => 
        NONDET ALL;
    
    function WadRayMath.rayDivDown(uint256 a, uint256 b) internal returns (uint256) => 
        NONDET ALL;

    function WadRayMath.rayDivUp(uint256 a, uint256 b) internal returns (uint256) => 
        NONDET ALL;
    
    function PercentageMath.percentMulDown(uint256 percentage, uint256 value) internal returns (uint256) => NONDET ALL;
    
    function PercentageMath.percentMulUp(uint256 percentage, uint256 value) internal returns (uint256) => NONDET ALL;

    function WadRayMath.wadDivUp(uint256 a, uint256 b) internal returns (uint256) => NONDET ALL;


    function _.sortByKey(KeyValueList.List memory array) internal
        => NONDET ALL;

    function _._hashTypedData(bytes32 structHash) internal => NONDET;
}

persistent ghost address assumeUser; 
persistent ghost bool detectedMisuse; 

function checkAndSetUser(address user) {
    if (assumeUser != user && assumeUser != 0) {
        detectedMisuse = true;
    }
    assumeUser = user;
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    checkAndSetUser(user);
}   

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].drawnShares {
    checkAndSetUser(user);
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    checkAndSetUser(user);
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares {
    checkAndSetUser(user);
}               

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumShares uint120 newValue (uint120 oldValue) {
    checkAndSetUser(user);
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].premiumShares {
    checkAndSetUser(user);
}   

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay int200 newValue (int200 oldValue) {
    checkAndSetUser(user);
}

hook Sload int200 value _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay {
    checkAndSetUser(user);
}

hook Sload uint256 value _positionStatus[KEY address user].map[KEY uint256 slot] {
    checkAndSetUser(user);
}

hook Sstore  _positionStatus[KEY address user].map[KEY uint256 slot] uint256 value {
    checkAndSetUser(user);
}

rule userIntegrity(method f) filtered {f -> f.selector != sig:liquidationCall(uint256, uint256, address, uint256, bool).selector  } 
{
    env e;
    calldataarg args;

    assumeUser = 0 ;
    detectedMisuse = false;
    
    f(e, args);
    
    assert !detectedMisuse;
}

