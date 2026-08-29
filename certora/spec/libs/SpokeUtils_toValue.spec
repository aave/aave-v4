/**
 * @title SpokeUtils Library Specification
 * @notice Formal verification of SpokeUtils.toValue function.
 * @dev This spec verifies functional equivalence between the Solidity implementation of toValue and its CVL representation.
 *
 * Verification Scope:
 * - Functional equivalence: Ensuring toValue matches toValueCVL for valid input ranges.
 * - Precision handling: Verifying correct conversion of asset amounts to Value units.
 */

import "../common.spec";

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    function toValue(uint256 amount, uint256 decimals, uint256 price) external returns (uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Verify that SpokeUtils.toValue matches toValueCVL
 * @link_property SpokeUtils integrity
 */
rule checkToValueEquivalence(uint256 amount, uint256 decimals, uint256 price) {
    require decimals >= 6 && decimals <= 18;

    uint256 resultSolidity = toValue(amount, decimals, price);
    uint256 resultCVL = toValueCVL(amount, decimals, price);

    assert resultSolidity == resultCVL;
}
