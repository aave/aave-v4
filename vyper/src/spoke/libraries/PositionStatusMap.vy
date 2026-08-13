# pragma version 0.5.0a3

NOT_FOUND: public(constant(uint256)) = max_value(uint256)
BORROWING_MASK: public(constant(uint256)) = 38597363079105398474523661669562635951089994888546854679819194669304376546645
COLLATERAL_MASK: public(constant(uint256)) = 77194726158210796949047323339125271902179989777093709359638389338608753093290


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
    value: uint256 = word
    count: uint256 = 0
    for _i: uint256 in range(256):
        count += value & 1
        value >>= 1
        if value == 0:
            break
    return count


@pure
def fls(word: uint256) -> uint256:
    if word == 0:
        return 256
    for i: uint256 in range(256):
        bit_id: uint256 = 255 - i
        if (word >> bit_id) & 1 != 0:
            return bit_id
    return 256
