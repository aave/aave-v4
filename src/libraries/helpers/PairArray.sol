// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PairArray {
    uint256 constant VALUE_BITS = 111;
    uint256 constant VALUE_MASK = (1 << VALUE_BITS) - 1;
    uint256 constant KEY_BITS = 17;
    uint256 constant KEY_MASK = ((1 << KEY_BITS) - 1) << VALUE_BITS;

    struct Array {
        uint256[] items;
    }

    function init(uint256 size) internal pure returns (Array memory) {
        return Array({items: new uint256[](size)});
    }

    function set(Array memory self, uint256 index, uint256 key, uint256 value) internal pure {
        self.items[index] = pack(key, value);
    }

    function get(Array memory self, uint256 index) internal pure returns (uint256, uint256) {
        return (getKey(self, index), getValue(self, index));
    }

    function length(Array memory self) internal pure returns (uint256) {
        return self.items.length;
    }

    function sortByKey(Array memory self) internal pure {
        uint256 len = length(self);

        uint8[5] memory shifts = [4, 0, 8, 12, 16];
        for (uint256 shiftIndex = 0; shiftIndex < shifts.length; shiftIndex++) {
            uint256 shift = shifts[shiftIndex];

            uint256 i;
            uint256 countMap = 0;
            for (i = 0; i < len; i++) {
                countMap = inc(countMap, (getKey(self, i) >> shift) & 0xF, 1);
            }

            for (i = 1; i < 16; i++) {
                countMap = inc(countMap, i, getCount(countMap, i - 1));
            }

            i = len;
            while (i > 0) {
                unchecked {
                    i -= 1;
                }
                uint256 digit = (getKey(self, i) >> shift) & 0xF;
                self.items[getCount(countMap, digit) - 1] |= (self.items[i] << (KEY_BITS + VALUE_BITS));
                countMap = dec(countMap, digit, 1);
            }

            bool sorted = true;
            for (i = 0; i < len; i++) {
                self.items[i] >>= (KEY_BITS + VALUE_BITS);
                if (i > 0 && self.items[i-1] > self.items[i]) {
                    sorted = false;
                }
            }

            if (sorted) {
                break;
            }
        }
    }

    function getKey(Array memory self, uint256 i) internal pure returns (uint256) {
        return (self.items[i] & KEY_MASK) >> VALUE_BITS;
    }

    function getValue(Array memory self, uint256 i) internal pure returns (uint256) {
        return self.items[i] & VALUE_MASK;
    }

    function pack(uint256 key, uint256 value) internal pure returns (uint256) {
        return (key << VALUE_BITS) | value;
    }

    function inc(uint256 countMap, uint256 digit, uint256 delta) internal pure returns (uint256) {
        return countMap + (delta << (digit << 4));
    }

    function dec(uint256 countMap, uint256 digit, uint256 delta) internal pure returns (uint256) {
        return countMap - (delta << (digit << 4));
    }

    function getCount(uint256 countMap, uint256 digit) internal pure returns (uint256) {
        return (countMap >> (digit << 4)) & 0xF;
    }
}