# pragma version 0.5.0b2
@external
def forward(target: address, data: Bytes[INF]) -> Bytes[INF]:
    return raw_call(target, data, max_outsize=INF)
