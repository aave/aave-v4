
/* 
 Returns floor(x * y / z)
  Reverts when z==0 or x*y overflows
*/
function mulDivDownCVL(uint256 x, uint256 y, uint256 z) returns uint256 {
    mathint mul  = x * y;
    if (z == 0 ||  mul > max_uint256) {
        revert();
    }
    mathint res = (mul / z);
    return require_uint256(res); 
}

/* 
 Returns ceil(x * y / z)
 Reverts when z==0 or x*y  or (x*y + z-1) overflows
*/

function mulDivUpCVL(uint256 x, uint256 y, uint256 z) returns uint256 {
    mathint mul  = x * y;
    if (z == 0 || mul > max_uint256) {
        revert();
    }
    mathint res = ((mul + z - 1) / z);
    if (res > max_uint256)
        revert();
    return require_uint256(res); 
}


/* 
 Returns floor(x * y / z)
  Reverts when z==0 or x*y overflows
*/
function mulDivRayDownCVL(uint256 x, uint256 y) returns uint256 {
    mathint mul  = x * y;
    if ( mul > max_uint256) {
        revert();
    }
    mathint res = (mul / (10 ^ 27));
    return require_uint256(res); 
}

/* 
 Returns ceil(x * y / z)
 Reverts when z==0 or x*y  or (x*y + z-1) overflows
*/

function mulDivRayUpCVL(uint256 x, uint256 y) returns uint256 {
    mathint mul  = x * y;
    if ( mul > max_uint256) {
        revert();
    }
    mathint res = ((mul + (10 ^ 27) - 1) / (10 ^ 27));
    if (res > max_uint256)
        revert();
    return require_uint256(res); 
}


ghost mulDivHalResult(uint256, uint256, uint256 ) returns uint256; 
/*
 Returns x*y/z rounding half up
 "Computes" floor( (z * y + z/2) / z)
 Reverts when z == 0 or (z * y + z/2 overflows) 
 Uses ghost to store the solution for deterministic behavior 
*/
function mulDivHalf(uint256 x, uint256 y, uint256 z) returns uint256 {
    uint256 result = mulDivHalResult(x,y,z);
    mathint mul  = x * y;
    if (z==0 || mul + z/2 > max_uint256) {
        revert();
    }  
    require (result * z <=  mul + z/2);
    require (result * z > mul - z/2);
    return result; 
}