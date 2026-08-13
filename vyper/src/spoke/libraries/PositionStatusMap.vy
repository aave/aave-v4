# pragma version 0.5.0a3

NOT_FOUND: public(constant(uint256)) = max_value(uint256)
BORROWING_MASK: public(constant(uint256)) = 38597363079105398474523661669562635951089994888546854679819194669304376546645
COLLATERAL_MASK: public(constant(uint256)) = 77194726158210796949047323339125271902179989777093709359638389338608753093290
TWO_BIT_MASK: constant(uint256) = max_value(uint256) // 5
FOUR_BIT_MASK: constant(uint256) = max_value(uint256) // 17
BYTE_MASK: constant(uint256) = max_value(uint256) // 257
TWO_BYTE_MASK: constant(uint256) = max_value(uint256) // 65537
FOUR_BYTE_MASK: constant(uint256) = max_value(uint256) // (2**32 + 1)
EIGHT_BYTE_MASK: constant(uint256) = max_value(uint256) // (2**64 + 1)
LOW_128_MASK: constant(uint256) = 2**128 - 1


@pure
def bucket_id(reserve_id: uint256) -> uint256:
    return reserve_id >> 7


@pure
def from_bit_id(bit_id: uint256, bucket: uint256) -> uint256:
    return (bit_id >> 1) + (bucket << 7)


@pure
def isolate_borrowing(word: uint256) -> uint256:
    return word & BORROWING_MASK


@pure
def isolate_collateral(word: uint256) -> uint256:
    return word & COLLATERAL_MASK


@pure
def isolate_until(word: uint256, reserve_count: uint256) -> uint256:
    bits: uint256 = (reserve_count % 128) << 1
    if bits == 0:
        return 0
    return word & (max_value(uint256) >> (256 - bits))


@pure
def isolate_borrowing_until(word: uint256, reserve_count: uint256) -> uint256:
    return self.isolate_until(word, reserve_count) & BORROWING_MASK


@pure
def isolate_collateral_until(word: uint256, reserve_count: uint256) -> uint256:
    return self.isolate_until(word, reserve_count) & COLLATERAL_MASK


@pure
def pop_count(word: uint256) -> uint256:
    # Parallel Hamming weight: fold 256 one-bit counters down to one 9-bit
    # counter. This is constant time instead of scanning up to 256 bits.
    value: uint256 = word
    value = unsafe_sub(value, (value >> 1) & BORROWING_MASK)
    value = unsafe_add(value & TWO_BIT_MASK, (value >> 2) & TWO_BIT_MASK)
    value = unsafe_add(value, value >> 4) & FOUR_BIT_MASK
    value = unsafe_add(value & BYTE_MASK, (value >> 8) & BYTE_MASK)
    value = unsafe_add(value & TWO_BYTE_MASK, (value >> 16) & TWO_BYTE_MASK)
    value = unsafe_add(value & FOUR_BYTE_MASK, (value >> 32) & FOUR_BYTE_MASK)
    value = unsafe_add(value & EIGHT_BYTE_MASK, (value >> 64) & EIGHT_BYTE_MASK)
    return unsafe_add(value & LOW_128_MASK, value >> 128)


@pure
def fls(word: uint256) -> uint256:
    if word == 0:
        return 256
    value: uint256 = word
    bit_id: uint256 = 0
    if value >> 128 != 0:
        value >>= 128
        bit_id = 128
    if value >> 64 != 0:
        value >>= 64
        bit_id += 64
    if value >> 32 != 0:
        value >>= 32
        bit_id += 32
    if value >> 16 != 0:
        value >>= 16
        bit_id += 16
    if value >> 8 != 0:
        value >>= 8
        bit_id += 8
    if value >> 4 != 0:
        value >>= 4
        bit_id += 4
    if value >> 2 != 0:
        value >>= 2
        bit_id += 2
    if value >> 1 != 0:
        bit_id += 1
    return bit_id
