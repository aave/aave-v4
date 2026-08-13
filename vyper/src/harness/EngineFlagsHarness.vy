# pragma version 0.5.0a3


@external
@pure
def toBool(flag: uint256) -> bool:
    if flag > 1:
        raw_revert(concat(method_id("InvalidBoolValue(uint256)"), convert(flag, bytes32)))
    return flag == 1


@external
@pure
def fromBool(flag: bool) -> uint256:
    return convert(flag, uint256)
