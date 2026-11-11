// Exact OpenZeppelin Math.mulDiv: floor(x * y / denominator), rounded up when `up`.
// The Solidity reverts on a zero denominator or an overflowing quotient; those paths are pruned.
function exactMulDiv(mathint x, mathint y, mathint denominator, bool up) returns uint256 {
    require denominator != 0, "Math.mulDiv reverts on a zero denominator";
    mathint result = up ? (x * y + denominator - 1) / denominator : x * y / denominator;
    require result <= max_uint256, "Math.mulDiv reverts on an overflowing quotient";
    return require_uint256(result);
}
