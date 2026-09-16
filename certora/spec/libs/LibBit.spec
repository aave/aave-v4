/**
 * @title LibBit Library Specification
 * @description Formal verification of Solady's LibBit utility library.
 * This library is used to represent position statuses, such as whether a reserveID it is active, inactive, liquidated, etc.
 * Based on this verification we can prove the integrity of the position statuses.
 * @dev This spec verifies bitwise operations popCount (count the number of set bits) and fls (find the last set bit).
 * 
 * Verification Scope:
 * - popCount: Correctness of bit counting logic.
 * - fls: Correctness of finding the most significant set bit.
 * - Revert safety: Ensuring bitwise operations never revert.
 */

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function popCount(uint256 x) external returns (uint256) envfree;
    function fls(uint256 x) external returns (uint256) envfree;
    function isBitTrue(uint256 x, uint16 pos) external returns (bool) envfree;
    function changeOneBit(uint256 x, uint16 pos) external returns (uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title popCount Integrity
 * @notice Verifies that popCount(x) correctly counts the number of set bits by flipping bits and checking the delta.
 * @link_property LibBit library integrity
 */
rule popCount_integrity(uint256 x, uint16 pos) {
    // Base cases
    assert popCount(0) == 0, "popCount(0) should be 0";
    assert popCount(max_uint256) == 256, "popCount(max_uint256) should be 256";
    
    // Position must be within uint256 range
    require pos <= 255; 
    
    uint256 x_count = popCount(x);
    // Flip bit at position 'pos'
    uint256 x_prime = changeOneBit(x, pos);
    uint256 x_prime_count = popCount(x_prime);
    
    // popCount must change by exactly one when a single bit is flipped
    assert x_prime_count - 1 == x_count || x_count == x_prime_count + 1, "popCount delta should be 1";
    
    // If the bit was true, count should decrease after flip; otherwise it should increase
    assert isBitTrue(x, pos) <=> x_count == x_prime_count + 1, "popCount direction mismatch";
}

/**
 * @title popCount No Revert
 * @notice Ensures that popCount never reverts for any input.
 * @link_property LibBit library integrity
 */
rule popCount_noRevert(uint256 x) {
    popCount@withrevert(x);
    assert !lastReverted, "popCount should never revert"; 
}

/**
 * @title fls Integrity
 * @notice Verifies that fls(x) correctly identifies the position of the most significant set bit.
 * @link_property LibBit library integrity
 */
rule fls_integrity(uint256 x, uint16 pos) {
    // Base cases
    assert x == 0 <=> fls(x) == 256, "fls(0) should be 256";
    assert x == 1 <=> fls(x) == 0, "fls(1) should be 0";
    
    uint256 r = fls(x);
    assert r <= 256, "fls result out of bounds";
    
    // Any bit above the fls result must be zero
    assert (pos > r && pos < 256) => !isBitTrue(x, pos), "Bit above fls should not be set";
    
    // The bit at the fls result must be set (if x is not 0)
    assert r != 256 => isBitTrue(x, assert_uint16(r)), "Bit at fls position should be set";
    
    // Shifting right by fls result should leave exactly 1
    assert (x != 0) => (x >> r == 1), "Shift right by fls mismatch";
}

/**
 * @title fls No Revert
 * @notice Ensures that fls never reverts for any input.
 * @link_property LibBit library integrity
 */
rule fls_noRevert(uint256 x) {
    fls@withrevert(x);
    assert !lastReverted, "fls should never revert"; 
}

/**
 * @title isBitTrue No Revert
 * @notice Ensures that isBitTrue never reverts for any position.
 * @link_property LibBit library integrity
 */
rule isBitTrueNeverRevert(uint256 x, uint16 pos) {
    isBitTrue@withrevert(x, pos);
    assert !lastReverted, "isBitTrue should never revert"; 
}
