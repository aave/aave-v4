// Exact replacement for LibBit.fls, proved by BitMathEquivalence.conf.
// No preconditions: zero maps to 256; other words map to their highest set bit.
function exactFls(uint256 word) returns uint256 {
    mathint value0 = word;
    bool high128 = value0 >= 340282366920938463463374607431768211456;
    mathint value1 = high128 ? value0 / 340282366920938463463374607431768211456 : value0;
    bool high64 = value1 >= 18446744073709551616;
    mathint value2 = high64 ? value1 / 18446744073709551616 : value1;
    bool high32 = value2 >= 4294967296;
    mathint value3 = high32 ? value2 / 4294967296 : value2;
    bool high16 = value3 >= 65536;
    mathint value4 = high16 ? value3 / 65536 : value3;
    bool high8 = value4 >= 256;
    mathint value5 = high8 ? value4 / 256 : value4;
    bool high4 = value5 >= 16;
    mathint value6 = high4 ? value5 / 16 : value5;
    bool high2 = value6 >= 4;
    mathint value7 = high2 ? value6 / 4 : value6;
    bool high1 = value7 >= 2;
    mathint value8 = high1 ? value7 / 2 : value7;
    mathint result = (high128 ? 128 : 0) + (high64 ? 64 : 0) + (high32 ? 32 : 0) + (high16 ? 16 : 0) + (high8 ? 8 : 0) + (high4 ? 4 : 0) + (high2 ? 2 : 0) + (high1 ? 1 : 0);
    return word == 0 ? 256 : assert_uint256(result);
}
