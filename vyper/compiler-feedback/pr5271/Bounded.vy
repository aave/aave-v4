# pragma version 0.5.0b2
@external
def forward(target: address, data: Bytes[INF]) -> Bytes[32768]:
    return raw_call(target, data, max_outsize=32768)
