// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library PairArray {
    uint256 constant VALUE_BITS = 224;
    uint256 constant VALUE_MASK = (1 << VALUE_BITS) - 1;
    uint256 constant SMALL_LENGTH_LIMIT = 13;

    struct Array {
        uint256[] items;
        uint256 maxKey;
    }

    function init(uint256 size) internal pure returns (Array memory) {
        return Array({items: new uint256[](size), maxKey: 0});
    }

    function set(Array memory self, uint256 index, uint256 key, uint256 value) internal pure {
        self.items[index] = pack(key, value);
        if (key > self.maxKey) {
            self.maxKey = key;
        }
    }

    function get(Array memory self, uint256 index) internal pure returns (uint256, uint256) {
        return (getKey(self, index), getValue(self, index));
    }

    function length(Array memory self) internal pure returns (uint256) {
        return self.items.length;
    }

    function sortByKey(Array memory self) internal pure {
        if (self.items.length < SMALL_LENGTH_LIMIT) {
            bubbleSortByKey(self);
        } else {
            radixSortByKey(self);
        }
    }

    function bubbleSortByKey(Array memory self) internal pure {
        uint256 length = self.items.length;
        for (uint256 i = 0; i < length; ) {
            for (uint256 j = i + 1; j < length;) {
                if (self.items[i] > self.items[j]) {
                    unchecked {
                        self.items[i] += self.items[j];
                        self.items[j] = self.items[i] - self.items[j];
                        self.items[i] -= self.items[j];
                    }
                }
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    function radixSortByKey(Array memory self) internal pure {
        uint256 maxKey = self.maxKey;
        for (uint256 exp = 1; exp <= maxKey;) {
            countSortByKey(self, exp);
            unchecked {
                exp *= 10;
            }
        }
    }

    function countSortByKey(Array memory self, uint256 exp) internal pure {
        uint256 length = self.items.length;
        uint256[] memory output = new uint256[](length);
        uint256[] memory count = new uint256[](10);
        for (uint256 i = 0; i < length; i++) {
            count[(getKey(self, i) / exp) % 10] += 1;
        }

        for (uint256 i = 1; i < 10; i++) {
            count[i] += count[i - 1];
        }

        uint256 i = length;
        while (i > 0) {
            unchecked {
                i -= 1;
            }
            uint256 digit = (getKey(self, i) / exp) % 10;
            output[count[digit] - 1] = self.items[i];
            count[digit] -= 1;
        }

        for (uint256 i = 0; i < length; i++) {
            self.items[i] = output[i];
        }
    }

    function getKey(Array memory self, uint256 i) internal pure returns (uint256) {
        return self.items[i] >> VALUE_BITS;
    }

    function getValue(Array memory self, uint256 i) internal pure returns (uint256) {
        return self.items[i] & VALUE_MASK;
    }

    function pack(uint256 key, uint256 value) internal pure returns (uint256) {
        return (key << VALUE_BITS) | value;
    }
}