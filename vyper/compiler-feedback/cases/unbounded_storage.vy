# pragma version 0.5.0b2
values: DynArray[uint256, INF]
@external
def append(item: uint256):
    self.values.append(item)
