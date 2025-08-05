

methods {
    function popCount(uint256 x) external  returns (uint256) envfree;
    function popCount_mutate(uint256 x) external  returns (uint256) envfree;
    function isBitTrue(uint256 x, uint16 pos) external  returns (bool) envfree;
    function changeOneBit(uint256 x, uint16 pos) external returns (uint256 ) envfree;
}

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

rule mutation(uint256 x) {
    assert popCount(x) == popCount_mutate(x);
}


rule popCount_integrity_mutate(uint256 x, uint16 pos) {
    
    // base check 
    assert popCount_mutate(0) == 0;
    assert popCount_mutate(max_uint256) == 256;
    
    // pos is from 0 to 255
    require pos <= 255; 
    uint256 x_count = popCount_mutate(x);
    // flip bit pos 
    uint256 x_prime = changeOneBit(x,pos);
    // count again 
    uint256 x_prime_count = popCount_mutate(x_prime);
    // must change by one
    assert  x_prime_count - 1 == x_count || x_count ==  x_prime_count + 1;
    // if changed from on to off then bit count should increase by one,
    // this also implies that if changed from off to on then count must decrease by one  
    assert isBitTrue(x, pos) <=>  x_count ==  x_prime_count + 1;
}

rule noRevert(uint256 x) {
    popCount@withrevert(x);
    assert !lastReverted; 
}