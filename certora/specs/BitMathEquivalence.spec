import "./helpers/BitMath.spec";

// Intentionally no summary for LibBit.fls: this checks the original implementation.
methods {
    function getFls(uint256) external returns (uint256) envfree;
}

rule exactHighestBit(uint256 word) {
    assert getFls(word) == exactFls(word);
}
