
/**

Verification of Solady's LibBit.sol
**/

methods {
    function popCount(uint256 x) external  returns (uint256) envfree;
    function ffs(uint256 x) external  returns (uint256) envfree;
    function isBitTrue(uint256 x, uint16 pos) external  returns (bool) envfree;
    function changeOneBit(uint256 x, uint16 pos) external returns (uint256 ) envfree;
}

/** @title popCount_integrity
popCount(x) is the number of set bits in x.
Prove by proving that by flipping one bit, the popCount changes by at most one.
**/
rule popCount_integrity(uint256 x, uint16 pos) {
    
    // base check 
    assert popCount(0) == 0;
    assert popCount(max_uint256) == 256;
    
    // pos is from 0 to 255
    require pos <= 255; 
    uint256 x_count = popCount(x);
    // flip bit pos 
    uint256 x_prime = changeOneBit(x,pos);
    // count again 
    uint256 x_prime_count = popCount(x_prime);
    // must change by one
    assert  x_prime_count - 1 == x_count || x_count ==  x_prime_count + 1;
    // if changed from on to off then bit count should increase by one,
    // this also implies that if changed from off to on then count must decrease by one  
    assert isBitTrue(x, pos) <=>  x_count ==  x_prime_count + 1;
}
///@title popCount should never revert
rule popCount_noRevert(uint256 x) {
    popCount@withrevert(x);
    assert !lastReverted; 
}

/** @title ffs(x) is the position of the first set bit in x.
Verifying by checking that any bit below the ffs(x) is not set.
**/
rule ffs_integrity(uint256 x, uint16 pos) {
    // base check
    assert x == 0 <=> ffs(x) == 256;
    
    uint256 r = ffs(x);
    assert pos < r =>  !isBitTrue(x, pos);
    assert r < 256 => isBitTrue(x, assert_uint16(r));
}

/// @title ffs should never revert
rule ffs_noRevert(uint256 x) {
    ffs@withrevert(x);
    assert !lastReverted; 
}
