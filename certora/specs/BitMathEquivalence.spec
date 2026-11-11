import "./helpers/BitMath.spec";

// getFls calls the original LibBit.fls without a summary.
methods {
    function getFls(uint256) external returns (uint256) envfree;
}

// Zero returns 256; nonzero words return the zero-based index of their highest set bit.
rule exactHighestBit(uint256 word) {
    // The Solidity bit search returns the same result as the CVL model.
    assert getFls(word) == exactFls(word);
}
