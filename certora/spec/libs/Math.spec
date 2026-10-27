/**
 * @title Math Library Specification
 * @notice Formal verification of mathematical utility libraries, ensuring CVL summaries match Solidity implementations.
 * @dev This spec verifies MathUtils, WadRayMath, and PercentageMath by comparing them against their symbolic CVL representations.
 * 
 * Verification Scope:
 * - Functional equivalence between Solidity and CVL implementations.
 * - Revert condition parity (ensuring both fail under the same circumstances).
 * - Mathematical properties like associativity for percentage calculations.
 */

import "../symbolicRepresentation/Math_CVL.spec";

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // envfree functions
    function RAY() external returns (uint256) envfree;
    function WAD() external returns (uint256) envfree;
    function PERCENTAGE_FACTOR() external returns (uint256) envfree;
    function rayMulDown(uint256 a, uint256 b) external returns (uint256) envfree;
    function rayMulUp(uint256 a, uint256 b) external returns (uint256) envfree;
    function rayDivDown(uint256 a, uint256 b) external returns (uint256) envfree;
    function rayDivUp(uint256 a, uint256 b) external returns (uint256) envfree;
    function wadDivDown(uint256 a, uint256 b) external returns (uint256) envfree;
    function wadDivUp(uint256 a, uint256 b) external returns (uint256) envfree;
    function percentMulDown(uint256 percentage, uint256 value) external returns (uint256) envfree;
    function percentMulUp(uint256 percentage, uint256 value) external returns (uint256) envfree;
    function mulDivDown(uint256 x, uint256 y, uint256 denominator) external returns (uint256) envfree;
    function mulDivUp(uint256 x, uint256 y, uint256 denominator) external returns (uint256) envfree;
    function divUp(uint256 a, uint256 b) external returns (uint256) envfree;
    function fromRayUp(uint256 a) external returns (uint256) envfree;
    function toRay(uint256 a) external returns (uint256) envfree;
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) external returns (uint256) envfree;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

persistent ghost uint256 PERCENTAGE_FACTOR {
    axiom PERCENTAGE_FACTOR == 10000;
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title MathUtils.mulDivDown Equivalence
 * @notice Verifies that MathUtils.mulDivDown matches the symbolic mulDivDownCVL implementation.
 * @link_property Math library integrity
 */
rule MathUtils_mulDivDown(uint256 x, uint256 y, uint256 denominator) {
    uint256 cvlResult = mulDivDownCVL@withrevert(x, y, denominator);
    bool cvlReverted = lastReverted;
    uint256 solResult = mulDivDown@withrevert(x, y, denominator);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title MathUtils.mulDivUp Equivalence
 * @notice Verifies that MathUtils.mulDivUp matches the symbolic mulDivUpCVL implementation.
 * @link_property Math library integrity
 */
rule MathUtils_mulDivUp(uint256 x, uint256 y, uint256 denominator) {
    uint256 cvlResult = mulDivUpCVL@withrevert(x, y, denominator);
    bool cvlReverted = lastReverted;
    uint256 solResult = mulDivUp@withrevert(x, y, denominator);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title MathUtils.divUp Equivalence
 * @notice Verifies that MathUtils.divUp matches the symbolic divUpCVL implementation.
 * @link_property Math library integrity
 */
rule MathUtils_divUp(uint256 a, uint256 b) {
    uint256 cvlResult = divUpCVL@withrevert(a, b);
    bool cvlReverted = lastReverted;
    uint256 solResult = divUp@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.rayMulDown Equivalence
 * @notice Verifies that WadRayMath.rayMulDown matches the symbolic mulDivDownCVL(a, b, RAY) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_rayMulDown(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivDownCVL@withrevert(a, b, RAY());
    bool cvlReverted = lastReverted;
    uint256 solResult = rayMulDown@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.rayMulUp Equivalence
 * @notice Verifies that WadRayMath.rayMulUp matches the symbolic mulDivUpCVL(a, b, RAY) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_rayMulUp(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivUpCVL@withrevert(a, b, RAY());
    bool cvlReverted = lastReverted;
    uint256 solResult = rayMulUp@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.rayDivDown Equivalence
 * @notice Verifies that WadRayMath.rayDivDown matches the symbolic mulDivDownCVL(a, RAY, b) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_rayDivDown(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivDownCVL@withrevert(a, RAY(), b);
    bool cvlReverted = lastReverted;
    uint256 solResult = rayDivDown@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.rayDivUp Equivalence
 * @notice Verifies that WadRayMath.rayDivUp matches the symbolic mulDivUpCVL(a, RAY, b) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_rayDivUp(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivUpCVL@withrevert(a, RAY(), b);
    bool cvlReverted = lastReverted;
    uint256 solResult = rayDivUp@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.wadDivDown Equivalence
 * @notice Verifies that WadRayMath.wadDivDown matches the symbolic mulDivDownCVL(a, WAD, b) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_wadDivDown(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivDownCVL@withrevert(a, WAD(), b);
    bool cvlReverted = lastReverted;
    uint256 solResult = wadDivDown@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.wadDivUp Equivalence
 * @notice Verifies that WadRayMath.wadDivUp matches the symbolic mulDivUpCVL(a, WAD, b) implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_wadDivUp(uint256 a, uint256 b) {
    uint256 cvlResult = mulDivUpCVL@withrevert(a, WAD(), b);
    bool cvlReverted = lastReverted;
    uint256 solResult = wadDivUp@withrevert(a, b);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.fromRayUp Equivalence
 * @notice Verifies that WadRayMath.fromRayUp matches the symbolic divRayUpCVL implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_fromRayUp(uint256 a) {
    uint256 cvlResult = divRayUpCVL@withrevert(a);
    bool cvlReverted = lastReverted;
    uint256 solResult = fromRayUp@withrevert(a);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title WadRayMath.toRay Equivalence
 * @notice Verifies that WadRayMath.toRay matches the symbolic mulRayCVL implementation.
 * @link_property Math library integrity
 */
rule WadRayMathExtended_toRay(uint256 a) {
    uint256 cvlResult = mulRayCVL@withrevert(a);
    bool cvlReverted = lastReverted;
    uint256 solResult = toRay@withrevert(a);
    bool solReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title PercentageMath.percentMulDown Equivalence
 * @notice Verifies that PercentageMath.percentMulDown matches the symbolic mulDivDownCVL implementation.
 * @link_property Math library integrity
 */
rule percentMulDown_integrity(uint256 percentage, uint256 value) {
    uint256 solResult = percentMulDown@withrevert(value, percentage);
    bool solReverted = lastReverted;
    uint256 cvlResult = mulDivDownCVL@withrevert(value, percentage, PERCENTAGE_FACTOR);
    bool cvlReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title PercentageMath.percentMulDown Associativity
 * @notice Proves that the order of arguments (value vs percentage) does not change the result for percentMulDown.
 * @link_property Math library integrity
*/
rule percentMulDown_associativity(uint256 percentage, uint256 value) {
    uint256 result1 = percentMulDown@withrevert(percentage, value);
    bool result1Reverted = lastReverted;
    uint256 result2 = percentMulDown@withrevert(value, percentage);
    bool result2Reverted = lastReverted;
    assert result1Reverted == result2Reverted, "Revert condition mismatch";
    assert !result1Reverted => result1 == result2, "Result value mismatch";
    satisfy value == 0 && !result1Reverted;
    satisfy percentage == 0 && !result1Reverted;
}

/**
 * @title PercentageMath.percentMulUp Equivalence
 * @notice Verifies that PercentageMath.percentMulUp matches the symbolic mulDivUpCVL implementation.
 * @link_property Math library integrity
 */
rule percentMulUp_integrity(uint256 percentage, uint256 value) {
    uint256 solResult = percentMulUp@withrevert(value, percentage);
    bool solReverted = lastReverted;
    uint256 cvlResult = mulDivUpCVL@withrevert(value, percentage, PERCENTAGE_FACTOR);
    bool cvlReverted = lastReverted;
    assert cvlReverted == solReverted, "Revert condition mismatch";
    assert !cvlReverted => cvlResult == solResult, "Result value mismatch";
}

/**
 * @title PercentageMath.percentMulUp Associativity
 * @notice Proves that the order of arguments (value vs percentage) does not change the result for percentMulUp.
 * @link_property Math library integrity
 */
rule percentMulUp_associativity(uint256 percentage, uint256 value) {
    uint256 result1 = percentMulUp@withrevert(percentage, value);
    bool result1Reverted = lastReverted;
    uint256 result2 = percentMulUp@withrevert(value, percentage);
    bool result2Reverted = lastReverted;
    assert result1Reverted == result2Reverted, "Revert condition mismatch";
    assert !result1Reverted => result1 == result2, "Result value mismatch";
    satisfy value == 0 && !result1Reverted;
    satisfy percentage == 0 && !result1Reverted;
}

/**
 * @title RAY Definition
 * @notice Constant check for RAY (10^27).
 * @link_property Math library integrity
 */
rule RAY_definition() {
    assert RAY() == 10^27;
}

/**
 * @title WAD Definition
 * @notice Constant check for WAD (10^18).
 * @link_property Math library integrity
 */
rule WAD_definition() {
    assert WAD() == 10^18;
}

/**
 * @title PERCENTAGE_FACTOR Definition
 * @notice Constant check for PERCENTAGE_FACTOR (10000).
 * @link_property Math library integrity
 */
rule PERCENTAGE_FACTOR_definition() {
    assert PERCENTAGE_FACTOR() == PERCENTAGE_FACTOR;
}
