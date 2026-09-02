# pragma version 0.5.0b1

error MaxDataSizeExceeded:
    pass

MAX_LIST: constant(uint256) = 1024
MAX_KEY: constant(uint256) = 2**32 - 1
MAX_VALUE: constant(uint256) = 2**224 - 1
KEY_SHIFT: constant(uint256) = 224

struct List:
    inner: DynArray[uint256, MAX_LIST]


@internal
@pure
def _pack(key: uint256, packed_value: uint256) -> uint256:
    return (unsafe_sub(MAX_KEY, key) * 2**KEY_SHIFT) | packed_value


@internal
@pure
def _unpack(data: uint256) -> (uint256, uint256):
    if data == 0:
        return 0, 0
    return unsafe_sub(MAX_KEY, data >> KEY_SHIFT), data & MAX_VALUE


@external
@pure
def add(list: List, idx: uint256, key: uint256, packed_value: uint256) -> List:
    if key >= MAX_KEY or packed_value >= MAX_VALUE:
        raise MaxDataSizeExceeded()
    result: List = list
    result.inner[idx] = self._pack(key, packed_value)
    return result


@external
@pure
def get(list: List, idx: uint256) -> (uint256, uint256):
    return self._unpack(list.inner[idx])


@external
@pure
def uncheckedAt(list: List, idx: uint256) -> (uint256, uint256):
    return self._unpack(list.inner[idx])


@external
@pure
def sortByKey(list: List) -> List:
    # Descending insertion sort on packed values produces ascending unpacked
    # keys, descending values on collisions, and moves zero cells to the end.
    result: List = list
    for i: uint256 in range(MAX_LIST):
        if i >= len(result.inner):
            break
        current: uint256 = result.inner[i]
        cursor: uint256 = i
        for _iteration: uint256 in range(MAX_LIST):
            if cursor == 0 or result.inner[cursor - 1] >= current:
                break
            result.inner[cursor] = result.inner[cursor - 1]
            cursor -= 1
        result.inner[cursor] = current
    return result


@external
@pure
def length(list: List) -> uint256:
    return len(list.inner)


@external
@pure
def pack(key: uint256, packed_value: uint256) -> uint256:
    return self._pack(key, packed_value)


@external
@pure
def unpack(data: uint256) -> (uint256, uint256):
    return self._unpack(data)


@external
@pure
def unpackKey(data: uint256) -> uint256:
    return unsafe_sub(MAX_KEY, data >> KEY_SHIFT)


@external
@pure
def unpackValue(data: uint256) -> uint256:
    return data & MAX_VALUE
