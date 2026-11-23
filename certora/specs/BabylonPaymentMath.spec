import "./helpers/MulDiv.spec";

methods {
    function mulDiv(uint256,uint256,uint256) external returns (uint256) envfree;
    function mulDivUp(uint256,uint256,uint256) external returns (uint256) envfree;
}

// Check Math.mulDiv's result and revert condition against the floor/ceil formula for x * y <= max_uint256.
// Larger products are excluded. The formula is repeated here; exactMulDiv itself is not called.
rule exactMulDivMatchesSolidity(uint256 x, uint256 y, uint256 denominator, bool up) {
    require x * y <= max_uint256, "512-bit products are outside what the prover can check";
    uint256 result;
    if (up) {
        result = mulDivUp@withrevert(x, y, denominator);
    } else {
        result = mulDiv@withrevert(x, y, denominator);
    }
    bool reverted = lastReverted;
    mathint quotient = denominator == 0 ? 0 : (up ? (x * y + denominator - 1) / denominator : x * y / denominator);
    // The call reverts exactly when the denominator is zero or the rounded quotient exceeds uint256.
    assert reverted <=> (denominator == 0 || quotient > max_uint256), "Revert condition differs";
    // A successful call returns the expected rounded quotient.
    assert !reverted => result == quotient, "Result differs";
}
