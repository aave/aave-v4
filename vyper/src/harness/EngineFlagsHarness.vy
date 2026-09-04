# pragma version 0.5.0b2


error InvalidBoolValue:
    arg0: uint256

@external
@pure
def toBool(flag: uint256) -> bool:
    if flag > 1:
        raise InvalidBoolValue(flag)
    return flag == 1


@external
@pure
def fromBool(flag: bool) -> uint256:
    return convert(flag, uint256)
