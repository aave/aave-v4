/**
 * @title Premium Library Specification
 * @notice Formal verification of the Premium calculation logic.
 * @dev This spec verifies functional equivalence between the Solidity implementation of calculatePremiumRay and its CVL representation.
 * 
 * Verification Scope:
 * - Functional equivalence: Ensuring calculatePremiumRay matches calculatePremiumRayCVL.
 * - Precision and types: Verifying correct handling of signed offsets and unsigned indices.
 */

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function calculatePremiumRay(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) external returns (uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                               DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

/**
 * @title CVL Implementation of calculatePremiumRay
 * @notice Symbolic representation of the premium calculation used for summarization.
 */
function calculatePremiumRayCVL(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) returns uint256 {
    return require_uint256((premiumShares * drawnIndex) - premiumOffsetRay);
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title calculatePremiumRay Equivalence
 * @notice Verifies that the Solidity implementation of calculatePremiumRay matches the symbolic CVL implementation.
 * @dev Solidity: ((premiumShares * drawnIndex).toInt256() - premiumOffsetRay).toUint256()
 * @link_property Premium library integrity
 */
rule calculatePremiumRay_equivalence(uint256 premiumShares, int256 premiumOffsetRay, uint256 drawnIndex) {
    uint256 solidityResult = calculatePremiumRay(premiumShares, premiumOffsetRay, drawnIndex);
    uint256 cvlResult = calculatePremiumRayCVL(premiumShares, premiumOffsetRay, drawnIndex);
    
    assert solidityResult == cvlResult, "Functional equivalence mismatch";
}
