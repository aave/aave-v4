# pragma version 0.5.0b2
BOUND: constant(uint256) = 32768
@external
@pure
def echo(values: DynArray[Bytes[BOUND], 64]) -> DynArray[Bytes[BOUND], 64]:
    return values

@external
@pure
def length(data: Bytes[INF]) -> uint256:
    return len(data)
