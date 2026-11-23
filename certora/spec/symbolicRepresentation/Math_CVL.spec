
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
Return ceil(x / y)
Reverts when y==0 or x overflows
*/
function divUpCVL(uint256 x, uint256 y) returns uint256 { 
    if (y == 0) {
        revert();
    }
    mathint res = (x + y - 1) / y;
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


/* 
 returns ceil(x / RAY).
*/

function divRayUpCVL(uint256 x) returns uint256 {
    mathint res = ((x + (10 ^ 27) - 1) / (10 ^ 27));
    if (res > max_uint256)
        revert();
    return require_uint256(res); 
}

/* 
 returns x * RAY.
*/
function mulRayCVL(uint256 x) returns uint256 {
    mathint res = x * (10 ^ 27);
    if (res > max_uint256)
        revert();
    return require_uint256(res);
}

function mulDivCVL(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) returns uint256 {
    if (denominator == 0) {
        revert();
    }
    mathint product = x * y;
    if (rounding == Math.Rounding.Ceil) {
        return require_uint256((product + denominator - 1) / denominator);
    } else { // Math.Rounding.Floor
        return require_uint256(product / denominator);
    }
}
