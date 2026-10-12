import "./helpers/MulDiv.spec";

methods {
    function mulDiv(uint256,uint256,uint256) external returns (uint256) envfree;
    function mulDivUp(uint256,uint256,uint256) external returns (uint256) envfree;
}

// exactMulDiv matches Math.mulDiv, including its reverts, whenever x * y fits in 256 bits.
// Neither prover mode can check larger products: integer mode over-approximates the 512-bit
// bitwise code, and precise_bitwise_ops bounds mathint near 2^256. That branch relies on
// OpenZeppelin's correctness.
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
    assert reverted <=> (denominator == 0 || quotient > max_uint256), "Revert condition differs";
    assert !reverted => result == quotient, "Result differs";
}
