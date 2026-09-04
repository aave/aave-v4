# pragma version 0.5.0b2

from spoke.libraries import PositionStatusMap

MAX_BUCKET_SCAN: constant(uint256) = 8192

position_map: HashMap[uint256, uint256]


@external
@pure
def BORROWING_MASK() -> uint256:
    return PositionStatusMap.BORROWING_MASK


@external
@pure
def COLLATERAL_MASK() -> uint256:
    return PositionStatusMap.COLLATERAL_MASK


@external
def setBorrowing(reserveId: uint256, borrowing: bool):
    bucket: uint256 = PositionStatusMap.bucket_id(reserveId)
    bit: uint256 = 1 << ((reserveId % 128) << 1)
    if borrowing:
        self.position_map[bucket] |= bit
    else:
        self.position_map[bucket] &= max_value(uint256) ^ bit


@external
def setUsingAsCollateral(reserveId: uint256, usingAsCollateral: bool):
    bucket: uint256 = PositionStatusMap.bucket_id(reserveId)
    bit: uint256 = 1 << (((reserveId % 128) << 1) + 1)
    if usingAsCollateral:
        self.position_map[bucket] |= bit
    else:
        self.position_map[bucket] &= max_value(uint256) ^ bit


@external
@view
def isUsingAsCollateralOrBorrowing(reserveId: uint256) -> bool:
    word: uint256 = self.position_map[PositionStatusMap.bucket_id(reserveId)]
    return (word >> ((reserveId % 128) << 1)) & 3 != 0


@external
@view
def isBorrowing(reserveId: uint256) -> bool:
    word: uint256 = self.position_map[PositionStatusMap.bucket_id(reserveId)]
    return (word >> ((reserveId % 128) << 1)) & 1 != 0


@external
@view
def isUsingAsCollateral(reserveId: uint256) -> bool:
    word: uint256 = self.position_map[PositionStatusMap.bucket_id(reserveId)]
    return (word >> (((reserveId % 128) << 1) + 1)) & 1 != 0


@external
@view
def collateralCount(reserveCount: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(reserveCount)
    count: uint256 = PositionStatusMap.pop_count(
        PositionStatusMap.isolate_collateral_until(self.position_map[bucket], reserveCount)
    )
    for _i: uint256 in range(MAX_BUCKET_SCAN):
        if bucket == 0:
            break
        bucket -= 1
        count += PositionStatusMap.pop_count(
            PositionStatusMap.isolate_collateral(self.position_map[bucket])
        )
    assert bucket == 0
    return count


@external
@view
def borrowCount(reserveCount: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(reserveCount)
    count: uint256 = PositionStatusMap.pop_count(
        PositionStatusMap.isolate_borrowing_until(self.position_map[bucket], reserveCount)
    )
    for _i: uint256 in range(MAX_BUCKET_SCAN):
        if bucket == 0:
            break
        bucket -= 1
        count += PositionStatusMap.pop_count(
            PositionStatusMap.isolate_borrowing(self.position_map[bucket])
        )
    assert bucket == 0
    return count


@external
@view
def getBucketWord(reserveId: uint256) -> uint256:
    return self.position_map[PositionStatusMap.bucket_id(reserveId)]


@external
@pure
def bucketId(reserveId: uint256) -> uint256:
    return PositionStatusMap.bucket_id(reserveId)


@external
@pure
def fromBitId(bitId: uint256, bucket: uint256) -> uint256:
    return PositionStatusMap.from_bit_id(bitId, bucket)


@external
@pure
def isolateBorrowing(word: uint256) -> uint256:
    return PositionStatusMap.isolate_borrowing(word)


@external
@pure
def isolateBorrowingUntil(word: uint256, reserveCount: uint256) -> uint256:
    return PositionStatusMap.isolate_borrowing_until(word, reserveCount)


@external
@pure
def isolateUntil(word: uint256, reserveCount: uint256) -> uint256:
    return PositionStatusMap.isolate_until(word, reserveCount)


@external
@pure
def isolateCollateral(word: uint256) -> uint256:
    return PositionStatusMap.isolate_collateral(word)


@external
@pure
def isolateCollateralUntil(word: uint256, reserveCount: uint256) -> uint256:
    return PositionStatusMap.isolate_collateral_until(word, reserveCount)


@external
@view
def next(fromReserveId: uint256) -> (uint256, bool, bool):
    bucket: uint256 = PositionStatusMap.bucket_id(fromReserveId)
    word: uint256 = self.position_map[bucket]
    set_bit_id: uint256 = PositionStatusMap.fls(PositionStatusMap.isolate_until(word, fromReserveId))
    for _i: uint256 in range(MAX_BUCKET_SCAN):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        word = self.position_map[bucket]
        set_bit_id = PositionStatusMap.fls(word)
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND, False, False
    status_word: uint256 = word >> ((set_bit_id >> 1) << 1)
    return PositionStatusMap.from_bit_id(set_bit_id, bucket), status_word & 1 != 0, status_word & 2 != 0


@external
@view
def nextBorrowing(fromReserveId: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(fromReserveId)
    set_bit_id: uint256 = PositionStatusMap.fls(
        PositionStatusMap.isolate_borrowing_until(self.position_map[bucket], fromReserveId)
    )
    for _i: uint256 in range(MAX_BUCKET_SCAN):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        set_bit_id = PositionStatusMap.fls(
            PositionStatusMap.isolate_borrowing(self.position_map[bucket])
        )
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND
    return PositionStatusMap.from_bit_id(set_bit_id, bucket)


@external
@view
def nextCollateral(fromReserveId: uint256) -> uint256:
    bucket: uint256 = PositionStatusMap.bucket_id(fromReserveId)
    set_bit_id: uint256 = PositionStatusMap.fls(
        PositionStatusMap.isolate_collateral_until(self.position_map[bucket], fromReserveId)
    )
    for _i: uint256 in range(MAX_BUCKET_SCAN):
        if set_bit_id != 256 or bucket == 0:
            break
        bucket -= 1
        set_bit_id = PositionStatusMap.fls(
            PositionStatusMap.isolate_collateral(self.position_map[bucket])
        )
    if set_bit_id == 256:
        return PositionStatusMap.NOT_FOUND
    return PositionStatusMap.from_bit_id(set_bit_id, bucket)


@external
@pure
def slot() -> bytes32:
    return empty(bytes32)
