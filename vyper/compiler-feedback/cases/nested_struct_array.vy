# pragma version 0.5.0b2
struct Batch:
    owner: address
    values: DynArray[uint256, INF]
@external
@pure
def count(batch: Batch) -> uint256:
    return len(batch.values)
