function divUpCVL(uint256 x, uint256 y) returns uint256 {
    if (y == 0) {
        revert();
    }return require_uint256((x + y - 1) / y);
}

function mulDivDownCVL(uint256 x, uint256 y, uint256 z) returns uint256 {
    if (z == 0) {
        revert();
    }return require_uint256(x * y / z);
}

function mulDivUpCVL(uint256 x, uint256 y, uint256 z) returns uint256 {
    if (z == 0) {
        revert();
    }return require_uint256((x * y + z - 1) / z);
}

function mulDivDownCVL_no_div(uint256 x, uint256 y, uint256 z) returns uint256 {
    uint256 res;
    if (z == 0) {
        revert();
    }
    mathint xy = x * y;
    mathint fz = res * z;

    require xy >= fz;
    require fz + z > xy;
    return res; 
} 

ghost mulDivHalResult(uint256, uint256, uint256 ) returns uint256; 

function mulDivHalf(uint256 x, uint256 y, uint256 z) returns uint256 {
    uint256 result = mulDivHalResult(x,y,z);
    if (y==0) {
        revert();
    }  
    require (result * z <=  x * y + z/2);
    require (result * z >= x * y - z/2);
    return result; 
}